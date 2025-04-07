// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {Surl} from "dependencies/surl-0.0.0/src/Surl.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {ContractRegistry} from "dependencies/flare-periphery-0.0.22/src/coston2/ContractRegistry.sol";
import {IFdcHub} from "dependencies/flare-periphery-0.0.22/src/coston2/IFdcHub.sol";
import {IFlareSystemsManager} from "dependencies/flare-periphery-0.0.22/src/coston2/IFlareSystemsManager.sol";
import {IBalanceDecreasingTransaction} from "dependencies/flare-periphery-0.0.22/src/coston2/IBalanceDecreasingTransaction.sol";
import {TransferEventListener} from "src/FdcTransferEventListener.sol";
import {Base as StringsBase} from "src/utils/fdcStrings/Base.sol";
import {FdcStrings} from "src/utils/fdcStrings/BalanceDecreasingTransaction.sol";
import {Base} from "./Base.s.sol";

// Global parameters
string constant attestationTypeName = "BalanceDecreasingTransaction";
string constant dirPath = "data/";

// Run with command
//      forge script script/fdcExample/BalanceDecreasingTransaction.s.sol:PrepareAttestationRequest --rpc-url $COSTON2_RPC_URL --ffi

contract PrepareAttestationRequest is Script {
    using Surl for *;

    // Setting request data
    string public transactionId =
        "682ffa976063514b0f3154f9c904703048da874d2f80a1cfae7c0ba16dfc44ce"; // Bitcoin testnet4 address
    // FIXME should be padded in the front
    string public sourceAddress = "tb1q8qjlpnqx8vhr6x3pr8uj72sacgsnt5vp4qlg7d";

    string public baseSourceName = "btc"; // Part of verifier URL
    string public sourceName = "testBTC"; // Bitcoin chain ID

    function prepareRequestBody(
        string memory _transactionId,
        string memory _sourceAddressIndicator
    ) private pure returns (string memory) {
        return
            string.concat(
                '{"transactionId": "',
                _transactionId,
                '","sourceAddressIndicator": "',
                _sourceAddressIndicator,
                '"}'
            );
    }

    function run() external {
        // Preparing request data
        string memory attestationType = Base.toUtf8HexString(
            attestationTypeName
        );
        string memory sourceId = Base.toUtf8HexString(sourceName);
        string memory sourceAddressIndicator = StringsBase.toHexString(
            keccak256(bytes(sourceAddress))
        );
        string memory requestBody = prepareRequestBody(
            transactionId,
            sourceAddressIndicator
        );

        (string[] memory headers, string memory body) = Base
            .prepareAttestationRequest(attestationType, sourceId, requestBody);

        // TODO change key in .env
        string memory baseUrl = "https://testnet-verifier-fdc-test.aflabs.org/";
        // string memory baseUrl = vm.envString("VERIFIER_URL_TESTNET");
        string memory url = string.concat(
            baseUrl,
            "verifier/",
            baseSourceName,
            "/",
            attestationTypeName,
            "/prepareRequest"
        );
        console.log("url: %s", url);

        // Posting the attestation request
        (, bytes memory data) = url.post(headers, body);

        Base.AttestationResponse memory response = Base.parseAttestationRequest(
            data
        );

        // Writing to a file
        Base.writeToFile(
            dirPath,
            attestationTypeName,
            StringsBase.toHexString(response.abiEncodedRequest),
            true
        );
    }
}

// Run with command
//      forge script script/fdcExample/BalanceDecreasingTransaction.s.sol:SubmitAttestationRequest --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --ffi

contract SubmitAttestationRequest is Script {
    using Surl for *;
    // TODO add to docs that testnets are connected to testnets, and mainnets are connected to mainnets

    function run() external {
        // Reading the abiEncodedRequest from a file
        string memory fileName = string.concat(attestationTypeName, ".txt");
        string memory filePath = string.concat(dirPath, fileName);
        string memory requestStr = vm.readLine(filePath);
        bytes memory request = vm.parseBytes(requestStr);

        // Submitting the attestation request
        Base.submitAttestationRequest(request);

        // Writing to a file
        uint32 votingRoundId = Base.calculateRoundId();
        string memory printString = string.concat(
            requestStr,
            "\n",
            Strings.toString(votingRoundId)
        );
        Base.writeToFile(dirPath, attestationTypeName, printString, true);
    }
}

// Run with command
//      forge script script/fdcExample/BalanceDecreasingTransaction.s.sol:RetrieveDataAndProof --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --ffi

contract RetrieveDataAndProof is Script {
    using Surl for *;

    function run() external {
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL"); // XXX
        string memory apiKey = vm.envString("X_API_KEY");
        string memory fileName = string.concat(attestationTypeName, ".txt");
        string memory filePath = string.concat(dirPath, fileName);

        // We import the roundId and abiEncodedRequest from the first file
        string memory requestBytes = vm.readLine(filePath);
        string memory votingRoundId = vm.readLine(filePath);

        console.log("votingRoundId: %s\n", votingRoundId);
        console.log("requestBytes: %s\n", requestBytes);

        // Preparing the proof request
        string[] memory headers = Base.prepareHeaders(apiKey);
        string memory body = string.concat(
            '{"votingRoundId":',
            votingRoundId,
            ',"requestBytes":"',
            requestBytes,
            '"}'
        );
        console.log("body: %s\n", body);
        console.log(
            "headers: %s",
            string.concat("{", headers[0], ", ", headers[1]),
            "}\n"
        );

        // Posting the proof request
        string memory url = string.concat(
            daLayerUrl,
            // "api/v0/fdc/get-proof-round-id-bytes"
            "api/v1/fdc/proof-by-request-round-raw"
        );
        console.log("url: %s\n", url);

        (, bytes memory data) = Base.postAttestationRequest(url, headers, body);

        // Decoding the response from JSON data
        bytes memory dataJson = Base.parseData(data);
        Base.ParsableProof memory proof = abi.decode(
            dataJson,
            (Base.ParsableProof)
        );

        IBalanceDecreasingTransaction.Response memory proofResponse = abi
            .decode(
                proof.responseHex,
                (IBalanceDecreasingTransaction.Response)
            );

        // Verifying the proof
        IBalanceDecreasingTransaction.Proof
            memory _proof = IBalanceDecreasingTransaction.Proof(
                proof.proofs,
                proofResponse
            );
        verifyProof(_proof);
    }

    function verifyProof(
        IBalanceDecreasingTransaction.Proof memory proof
    ) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bool isValid = ContractRegistry
            .getFdcVerification()
            .verifyBalanceDecreasingTransaction(proof);
        console.log("proof is valid: %s\n", StringsBase.toString(isValid));

        vm.stopBroadcast();
    }
}

// forge script script/fdcExample/BalanceDecreasingTransaction.s.sol:Deploy --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --ffi

contract Deploy is Script {
    function run() external {}
}
