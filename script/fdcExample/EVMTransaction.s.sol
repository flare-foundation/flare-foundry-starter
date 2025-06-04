// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {Surl} from "dependencies/surl-0.0.0/src/Surl.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base as StringsBase} from "src/utils/fdcStrings/Base.sol";
import {Base} from "./Base.s.sol";
import {IEVMTransaction} from "flare-periphery/src/coston2/IEVMTransaction.sol";
import {TransferEventListener, ITransferEventListener, TokenTransfer} from "src/fdcExample/EVMTransaction.sol";

// Configuration constants
string constant attestationTypeName = "EVMTransaction";
string constant dirPath = "data/";

// Run with command
//      forge script script/fdcExample/EVMTransaction.s.sol:PrepareAttestationRequest --rpc-url $COSTON2_RPC_URL --ffi

contract PrepareAttestationRequest is Script {
    using Surl for *;
    // Setting request data

    string public transactionHash =
        "0x4e636c6590b22d8dcdade7ee3b5ae5572f42edb1878f09b3034b2f7c3362ef3c";
    string public requiredConfirmations = "1";
    string public provideInput = "true";
    string public listEvents = "true";
    string public logIndices = "[]";
    string public sourceName = "testETH"; // Bitcoin chain ID
    string public baseSourceName = "eth"; // Part of verifier URL

    function prepareRequestBody(
        string memory transactionHash,
        string memory requiredConfirmations,
        string memory provideInput,
        string memory listEvents,
        string memory logIndices
    ) private pure returns (string memory) {
        return
            string.concat(
                '{"transactionHash": ',
                '"',
                transactionHash,
                '"',
                ', "requiredConfirmations": ',
                '"',
                requiredConfirmations,
                '"',
                ', "provideInput": ',
                provideInput,
                ', "listEvents": ',
                listEvents,
                ', "logIndices": ',
                logIndices,
                "}"
            );
    }

    function run() external {
        // Preparing request data
        string memory attestationType = Base.toUtf8HexString(
            attestationTypeName
        );
        string memory sourceId = Base.toUtf8HexString(sourceName);
        string memory requestBody = prepareRequestBody(
            transactionHash,
            requiredConfirmations,
            provideInput,
            listEvents,
            logIndices
        );

        (string[] memory headers, string memory body) = Base
            .prepareAttestationRequest(attestationType, sourceId, requestBody);

        // TODO change key in .env
        // string memory baseUrl = "https://testnet-verifier-fdc-test.aflabs.org/";
        string memory baseUrl = vm.envString("VERIFIER_URL_TESTNET");
        string memory url = string.concat(
            baseUrl,
            "verifier/",
            baseSourceName,
            "/EVMTransaction/prepareRequest"
        );
        console.log("url: %s", url);

        // Posting the attestation request
        (, bytes memory data) = url.post(headers, body);

        Base.AttestationResponse memory response = Base.parseAttestationRequest(
            data
        );

        // Writing abiEncodedRequest to a file
        Base.writeToFile(
            dirPath,
            string.concat(attestationTypeName, "_abiEncodedRequest"),
            StringsBase.toHexString(response.abiEncodedRequest),
            true
        );
    }
}

// Run with command
//      forge script script/fdcExample/EVMTransaction.s.sol:SubmitAttestationRequest --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --ffi

contract SubmitAttestationRequest is Script {
    using Surl for *;
    // TODO add to docs that testnets are connected to testnets, and mainnets are connected to mainnets

    function run() external {
        // Reading the abiEncodedRequest from a file
        string memory fileName = string.concat(
            attestationTypeName,
            "_abiEncodedRequest",
            ".txt"
        );
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
//      forge script script/fdcExample/EVMTransaction.s.sol:RetrieveDataAndProof --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --ffi

contract RetrieveDataAndProof is Script {
    using Surl for *;

    function run() external {
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL"); // XXX
        string memory apiKey = vm.envString("X_API_KEY");

        // We import the abiEncodedRequest and votingRoundId from the files
        string memory requestBytes = vm.readLine(
            string.concat(
                dirPath,
                attestationTypeName,
                "_abiEncodedRequest",
                ".txt"
            )
        );
        string memory votingRoundId = vm.readLine(
            string.concat(
                dirPath,
                attestationTypeName,
                "_votingRoundId",
                ".txt"
            )
        );

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

        IEVMTransaction.Response memory proofResponse = abi.decode(
            proof.responseHex,
            (IEVMTransaction.Response)
        );

        IEVMTransaction.Proof memory _proof = IEVMTransaction.Proof(
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

// forge script script/fdcExample/EVMTransaction.s.sol:DeployContract --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --verify --ffi

contract DeployContract is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TransferEventListener listener = new TransferEventListener();
        address _address = address(listener);

        vm.stopBroadcast();

        Base.writeToFile(
            dirPath,
            string.concat(attestationTypeName, "_address"),
            StringsBase.toHexString(abi.encodePacked(_address)),
            true
        );
    }
}

// forge script script/fdcExample/EVMTransaction.s.sol:InteractWithContract --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --ffi

contract InteractWithContract is Script {
    function run() external {
        string memory addressString = vm.readLine(
            string.concat(dirPath, attestationTypeName, "_address", ".txt")
        );
        address _address = vm.parseAddress(addressString);
        string memory proofString = vm.readLine(
            string.concat(dirPath, attestationTypeName, "_proof", ".txt")
        );
        bytes memory proofBytes = vm.parseBytes(proofString);
        IEVMTransaction.Proof memory proof = abi.decode(
            proofBytes,
            (IEVMTransaction.Proof)
        );
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ITransferEventListener listener = ITransferEventListener(_address);
        listener.collectTransferEvents(proof);
        vm.stopBroadcast();
    }
}
