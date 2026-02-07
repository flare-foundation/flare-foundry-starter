// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable max-line-length */
import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { Surl } from "dependencies/surl-0.0.0/src/Surl.sol";
import { Strings } from "@openzeppelin-contracts/utils/Strings.sol";
import { Base as StringsBase } from "src/utils/fdcStrings/Base.sol";
import { Base } from "../fdcExample/Base.s.sol";
import { IWeb2Json } from "flare-periphery/src/coston2/IWeb2Json.sol";
import { MetalPriceVerifierCustomFeed } from "../../src/customFeeds/MetalPriceVerifierCustomFeed.sol";

// MetalPriceVerification
// FDC verification workflow for precious metal prices from Swissquote
//
// This demonstrates the complete FDC Web2Json flow for metal prices:
// 1. PrepareAttestationRequest - Prepare request to verifier
// 2. SubmitAttestationRequest - Submit to FdcHub on-chain
// 3. RetrieveDataAndProof - Get proof from DA Layer
// 4. DeployContract - Deploy MetalPriceVerifierCustomFeed
// 5. InteractWithContract - Submit proof to verify price
//
// Supported metals: XAU (Gold), XAG (Silver), XPT (Platinum), XPD (Palladium)

// Configuration constants
string constant attestationTypeName = "Web2Json";
string constant dirPath = "data/customFeeds/metal/";
string constant metalSymbol = "XAU"; // Gold

// Run with command
// forge script script/customFeeds/MetalPriceVerification.s.sol:PrepareAttestationRequest --rpc-url $COSTON2_RPC_URL --ffi

contract PrepareAttestationRequest is Script {
    using Surl for *;

    // Swissquote API configuration
    string public apiUrl = "https://forex-data-feed.swissquote.com/public-quotes/bboquotes/instrument/XAU/USD";
    string public httpMethod = "GET";
    string public headers = "";
    string public queryParams = "{}";
    string public body = "{}";
    // Process the response to extract price with 4 decimal places
    string public postProcessJq = "{price: (.[0].spreadProfilePrices[0].ask * 10000 | floor)}";
    // ABI signature for the metal price data struct
    string public abiSignature =
        // solhint-disable-next-line max-line-length
        "{\\'components\\': [{\\'internalType\\': \\'uint256\\', \\'name\\': \\'price\\', \\'type\\': \\'uint256\\'}],\\'internalType\\': \\'struct MetalPriceData\\',\\'name\\': \\'priceData\\',\\'type\\': \\'tuple\\'}";

    string public sourceName = "PublicWeb2";

    function run() external {
        // Preparing request data
        string memory attestationType = Base.toUtf8HexString(attestationTypeName);
        string memory sourceId = Base.toUtf8HexString(sourceName);
        string memory requestBody = _prepareRequestBody(
            apiUrl,
            httpMethod,
            headers,
            queryParams,
            body,
            postProcessJq,
            abiSignature
        );
        (string[] memory hdrs, string memory bdy) = Base.prepareAttestationRequest(
            attestationType,
            sourceId,
            requestBody
        );

        string memory baseUrl = vm.envString("VERIFIER_URL_TESTNET");
        string memory url = string.concat(baseUrl, "/verifier/web2/Web2Json/prepareRequest");

        // Posting the attestation request
        (, bytes memory data) = url.post(hdrs, bdy);

        Base.AttestationResponse memory response = Base.parseAttestationRequest(data);

        // Writing abiEncodedRequest to a file
        Base.writeToFile(
            dirPath,
            string.concat(attestationTypeName, "_abiEncodedRequest"),
            StringsBase.toHexString(response.abiEncodedRequest),
            true
        );
    }

    function _prepareRequestBody(
        string memory url,
        string memory method,
        string memory hdrs,
        string memory qParams,
        string memory bdy,
        string memory jq,
        string memory abi_
    ) private pure returns (string memory) {
        return
            string.concat(
                "{'url': '",
                url,
                "','httpMethod': '",
                method,
                "','headers': '",
                hdrs,
                "','queryParams': '",
                qParams,
                "','body': '",
                bdy,
                "','postProcessJq': '",
                jq,
                "','abiSignature': '",
                abi_,
                "'}"
            );
    }
}

// Run with command
// forge script script/customFeeds/MetalPriceVerification.s.sol:SubmitAttestationRequest --rpc-url $COSTON2_RPC_URL --broadcast --ffi

contract SubmitAttestationRequest is Script {
    using Surl for *;

    function run() external {
        // Reading the abiEncodedRequest from a file
        string memory fileName = string.concat(attestationTypeName, "_abiEncodedRequest", ".txt");
        string memory filePath = string.concat(dirPath, fileName);
        string memory requestStr = vm.readLine(filePath);
        bytes memory request = vm.parseBytes(requestStr);

        // Submitting the attestation request
        uint256 timestamp = Base.submitAttestationRequest(request);
        uint256 votingRoundId = Base.calculateRoundId(timestamp);

        // Writing to a file
        Base.writeToFile(
            dirPath,
            string.concat(attestationTypeName, "_votingRoundId"),
            Strings.toString(votingRoundId),
            true
        );
    }
}

// Run with command
// forge script script/customFeeds/MetalPriceVerification.s.sol:RetrieveDataAndProof --rpc-url $COSTON2_RPC_URL --broadcast --ffi

contract RetrieveDataAndProof is Script {
    using Surl for *;

    function run() external {
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL");
        string memory apiKey = vm.envString("X_API_KEY");

        // We import the abiEncodedRequest and votingRoundId from the files
        string memory requestBytes = vm.readLine(
            string.concat(dirPath, attestationTypeName, "_abiEncodedRequest", ".txt")
        );
        string memory votingRoundId = vm.readLine(
            string.concat(dirPath, attestationTypeName, "_votingRoundId", ".txt")
        );

        // Preparing the proof request
        string[] memory headers = Base.prepareHeaders(apiKey);
        string memory body = string.concat("{'votingRoundId':", votingRoundId, ",'requestBytes':'", requestBytes, "'}");

        // Posting the proof request
        string memory url = string.concat(daLayerUrl, "/api/v1/fdc/proof-by-request-round-raw");

        (, bytes memory data) = Base.postAttestationRequest(url, headers, body);

        // Decoding the response from JSON data
        bytes memory dataJson = Base.parseData(data);
        Base.ParsableProof memory proof = abi.decode(dataJson, (Base.ParsableProof));

        IWeb2Json.Response memory proofResponse = abi.decode(proof.responseHex, (IWeb2Json.Response));

        IWeb2Json.Proof memory _proof = IWeb2Json.Proof(proof.proofs, proofResponse);

        // Writing proof to a file
        Base.writeToFile(
            dirPath,
            string.concat(attestationTypeName, "_proof"),
            StringsBase.toHexString(abi.encode(_proof)),
            true
        );
    }
}

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/customFeeds/MetalPriceVerification.s.sol:DeployContract --rpc-url $COSTON2_RPC_URL --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API --ffi

contract DeployContract is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Create feed ID: 0x21 (custom feed category) + first 20 bytes of keccak256(symbol/USD)
        string memory feedIdString = string.concat(metalSymbol, "/USD");
        bytes32 feedNameHash = keccak256(abi.encodePacked(feedIdString));
        bytes21 feedId = bytes21(abi.encodePacked(bytes1(0x21), bytes20(feedNameHash)));

        vm.startBroadcast(deployerPrivateKey);

        MetalPriceVerifierCustomFeed customFeed = new MetalPriceVerifierCustomFeed(feedId, metalSymbol);
        address _address = address(customFeed);

        vm.stopBroadcast();

        Base.writeToFile(
            dirPath,
            string.concat(attestationTypeName, "_address"),
            StringsBase.toHexString(abi.encodePacked(_address)),
            true
        );
    }
}

// Run with command
// forge script script/customFeeds/MetalPriceVerification.s.sol:InteractWithContract --rpc-url $COSTON2_RPC_URL --broadcast --ffi

contract InteractWithContract is Script {
    function run() external {
        string memory addressString = vm.readLine(string.concat(dirPath, attestationTypeName, "_address", ".txt"));
        address _address = vm.parseAddress(addressString);
        string memory proofString = vm.readLine(string.concat(dirPath, attestationTypeName, "_proof", ".txt"));
        bytes memory proofBytes = vm.parseBytes(proofString);
        IWeb2Json.Proof memory proof = abi.decode(proofBytes, (IWeb2Json.Proof));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MetalPriceVerifierCustomFeed customFeed = MetalPriceVerifierCustomFeed(_address);
        customFeed.verifyPrice(proof);

        vm.stopBroadcast();
    }
}
