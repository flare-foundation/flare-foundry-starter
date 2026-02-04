// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { Surl } from "dependencies/surl-0.0.0/src/Surl.sol";
import { Strings } from "@openzeppelin-contracts/utils/Strings.sol";
import { IBalanceDecreasingTransaction } from "flare-periphery/src/coston2/IBalanceDecreasingTransaction.sol";
import { Base as StringsBase } from "src/utils/fdcStrings/Base.sol";
import { Base } from "./Base.s.sol";

// Configuration constants
string constant attestationTypeName = "BalanceDecreasingTransaction";
string constant dirPath = "data/";

// Run with command
// solhint-disable-next-line max-line-length
//      forge script script/fdcExample/BalanceDecreasingTransaction.s.sol:PrepareAttestationRequest --rpc-url $COSTON2_RPC_URL --ffi

contract PrepareAttestationRequest is Script {
    using Surl for *;

    // Setting request data
    // solhint-disable-next-line max-line-length
    string public transactionId = "682ffa976063514b0f3154f9c904703048da874d2f80a1cfae7c0ba16dfc44ce"; // Bitcoin testnet4 address
    // FIXME should be padded in the front
    string public sourceAddress = "tb1q8qjlpnqx8vhr6x3pr8uj72sacgsnt5vp4qlg7d";

    string public baseSourceName = "btc"; // Part of verifier URL
    string public sourceName = "testBTC"; // Bitcoin chain ID

    function run() external {
        // Preparing request data
        string memory attestationType = Base.toUtf8HexString(attestationTypeName);
        string memory sourceId = Base.toUtf8HexString(sourceName);
        string memory sourceAddressIndicator = StringsBase.toHexString(keccak256(bytes(sourceAddress)));
        string memory requestBody = prepareRequestBody(transactionId, sourceAddressIndicator);

        (string[] memory headers, string memory body) = Base.prepareAttestationRequest(
            attestationType,
            sourceId,
            requestBody
        );

        // TODO change key in .env
        string memory baseUrl = vm.envString("VERIFIER_URL_TESTNET");
        string memory url = string.concat(
            baseUrl,
            "/verifier/",
            baseSourceName,
            "/",
            attestationTypeName,
            "/prepareRequest"
        );

        // Posting the attestation request
        (, bytes memory data) = url.post(headers, body);

        Base.AttestationResponse memory response = Base.parseAttestationRequest(data);

        // Writing abiEncodedRequest to a file
        Base.writeToFile(
            dirPath,
            string.concat(attestationTypeName, "_abiEncodedRequest"),
            StringsBase.toHexString(response.abiEncodedRequest),
            true
        );
    }
    function prepareRequestBody(
        string memory _transactionId,
        string memory _sourceAddressIndicator
    ) private pure returns (string memory) {
        return
            string.concat(
                "{'transactionId': '",
                _transactionId,
                "','sourceAddressIndicator': '",
                _sourceAddressIndicator,
                "'}"
            );
    }
}

// Run with command
// solhint-disable-next-line max-line-length
//      forge script script/fdcExample/BalanceDecreasingTransaction.s.sol:SubmitAttestationRequest --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_RPC_API_KEY --broadcast --ffi

contract SubmitAttestationRequest is Script {
    using Surl for *;
    // TODO add to docs that testnets are connected to testnets, and mainnets are connected to mainnets

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
// solhint-disable-next-line max-line-length
//      forge script script/fdcExample/BalanceDecreasingTransaction.s.sol:RetrieveDataAndProof --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_RPC_API_KEY --broadcast --ffi

contract RetrieveDataAndProof is Script {
    using Surl for *;

    function run() external {
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL"); // XXX
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
        string memory url = string.concat(
            daLayerUrl,
            // "api/v0/fdc/get-proof-round-id-bytes"
            "api/v1/fdc/proof-by-request-round-raw"
        );

        (, bytes memory data) = Base.postAttestationRequest(url, headers, body);

        // Decoding the response from JSON data
        bytes memory dataJson = Base.parseData(data);
        Base.ParsableProof memory proof = abi.decode(dataJson, (Base.ParsableProof));

        IBalanceDecreasingTransaction.Response memory proofResponse = abi.decode(
            proof.responseHex,
            (IBalanceDecreasingTransaction.Response)
        );

        IBalanceDecreasingTransaction.Proof memory _proof = IBalanceDecreasingTransaction.Proof(
            proof.proofs,
            proofResponse
        );

        // Writing proof to a file
        Base.writeToFile(
            dirPath,
            string.concat(attestationTypeName, "_proof"),
            StringsBase.toHexString(abi.encode(_proof)),
            true
        );
    }
}

// solhint-disable-next-line max-line-length
// forge script script/fdcExample/BalanceDecreasingTransaction.s.sol:DeployContract --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_RPC_API_KEY --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API --ffi

contract DeployContract is Script {
    function run() external {}
}

// solhint-disable-next-line max-line-length
// forge script script/fdcExample/BalanceDecreasingTransaction.s.sol:InteractWithContract --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_RPC_API_KEY --broadcast --ffi

contract InteractWithContract is Script {
    function run() external {}
}
