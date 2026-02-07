// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable max-line-length */
import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { Surl } from "dependencies/surl-0.0.0/src/Surl.sol";
import { Strings } from "@openzeppelin-contracts/utils/Strings.sol";
import { Base as StringsBase } from "src/utils/fdcStrings/Base.sol";
import { Base } from "../fdcExample/Base.s.sol";
import { IWeb2Json } from "flare-periphery/src/coston2/IWeb2Json.sol";
import { PriceVerifierCustomFeed } from "../../src/customFeeds/PriceVerifierCustomFeed.sol";

// PriceVerification
// FDC verification workflow for historical BTC price from CoinGecko
//
// This demonstrates the complete FDC Web2Json flow:
// 1. PrepareAttestationRequest - Prepare request to verifier
// 2. SubmitAttestationRequest - Submit to FdcHub on-chain
// 3. RetrieveDataAndProof - Get proof from DA Layer
// 4. DeployContract - Deploy PriceVerifierCustomFeed
// 5. InteractWithContract - Submit proof to verify price

// Configuration constants
string constant attestationTypeName = "Web2Json";
string constant dirPath = "data/customFeeds/price/";
string constant priceSymbol = "BTC";
int8 constant priceDecimals = 2;
string constant coinGeckoId = "bitcoin";

// Run with command
// forge script script/customFeeds/PriceVerification.s.sol:PrepareAttestationRequest --rpc-url $COSTON2_RPC_URL --ffi

contract PrepareAttestationRequest is Script {
    using Surl for *;

    // CoinGecko API configuration
    string public apiUrl = "https://api.coingecko.com/api/v3/coins/bitcoin/history";
    string public httpMethod = "GET";
    string public headers = "";
    // Query params will include the date (2 days ago for finalized data)
    string public body = "{}";
    // Process the response to extract price with decimals
    string public postProcessJq = "{price: (.market_data.current_price.usd * 100 | floor)}";
    // ABI signature for the price data struct
    string public abiSignature =
        // solhint-disable-next-line max-line-length
        "{\\'components\\': [{\\'internalType\\': \\'uint256\\', \\'name\\': \\'price\\', \\'type\\': \\'uint256\\'}],\\'internalType\\': \\'struct PriceData\\',\\'name\\': \\'priceData\\',\\'type\\': \\'tuple\\'}";

    string public sourceName = "PublicWeb2";

    function run() external {
        // Calculate date 2 days ago for finalized data
        uint256 twoDaysAgo = block.timestamp - 2 days;
        (uint256 year, uint256 month, uint256 day) = _timestampToDate(twoDaysAgo);
        string memory dateString = string.concat(_padZero(day), "-", _padZero(month), "-", Strings.toString(year));
        string memory queryParams = string.concat("{'date': '", dateString, "', 'localization': 'false'}");

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

    function _timestampToDate(uint256 timestamp) internal pure returns (uint256 year, uint256 month, uint256 day) {
        uint256 z = timestamp / 86400 + 719468;
        uint256 era = z / 146097;
        uint256 doe = z - era * 146097;
        uint256 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        year = yoe + era * 400;
        uint256 doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        uint256 mp = (5 * doy + 2) / 153;
        day = doy - (153 * mp + 2) / 5 + 1;
        month = mp < 10 ? mp + 3 : mp - 9;
        if (month <= 2) year += 1;
    }

    function _padZero(uint256 n) internal pure returns (string memory) {
        if (n < 10) {
            return string.concat("0", Strings.toString(n));
        }
        return Strings.toString(n);
    }

    function _prepareRequestBody(
        string memory url,
        string memory method,
        string memory hdrs,
        string memory queryParams,
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
                queryParams,
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
// forge script script/customFeeds/PriceVerification.s.sol:SubmitAttestationRequest --rpc-url $COSTON2_RPC_URL --broadcast --ffi

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
// forge script script/customFeeds/PriceVerification.s.sol:RetrieveDataAndProof --rpc-url $COSTON2_RPC_URL --broadcast --ffi

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
// forge script script/customFeeds/PriceVerification.s.sol:DeployContract --rpc-url $COSTON2_RPC_URL --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API --ffi

contract DeployContract is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Create feed ID: 0x21 (custom feed category) + first 20 bytes of keccak256(symbol/USD-HIST)
        string memory feedIdString = string.concat(priceSymbol, "/USD-HIST");
        bytes32 feedNameHash = keccak256(abi.encodePacked(feedIdString));
        bytes21 feedId = bytes21(abi.encodePacked(bytes1(0x21), bytes20(feedNameHash)));

        vm.startBroadcast(deployerPrivateKey);

        PriceVerifierCustomFeed customFeed = new PriceVerifierCustomFeed(feedId, priceSymbol, priceDecimals);
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
// forge script script/customFeeds/PriceVerification.s.sol:InteractWithContract --rpc-url $COSTON2_RPC_URL --broadcast --ffi

contract InteractWithContract is Script {
    function run() external {
        string memory addressString = vm.readLine(string.concat(dirPath, attestationTypeName, "_address", ".txt"));
        address _address = vm.parseAddress(addressString);
        string memory proofString = vm.readLine(string.concat(dirPath, attestationTypeName, "_proof", ".txt"));
        bytes memory proofBytes = vm.parseBytes(proofString);
        IWeb2Json.Proof memory proof = abi.decode(proofBytes, (IWeb2Json.Proof));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PriceVerifierCustomFeed customFeed = PriceVerifierCustomFeed(_address);
        customFeed.verifyPrice(proof);

        vm.stopBroadcast();
    }
}
