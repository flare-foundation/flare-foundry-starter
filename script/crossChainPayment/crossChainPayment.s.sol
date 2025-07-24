// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Surl} from "surl/Surl.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base as FdcBase} from "../fdcExample/Base.s.sol";
import {Base as StringsBase} from "../../src/utils/fdcStrings/Base.sol";
import {IEVMTransaction} from "flare-periphery/src/coston2/IEVMTransaction.sol";
import {NFTMinter, TokenTransfer} from "../../src/crossChainPayment/Minter.sol";
import {CrossChainPaymentConfig} from "./Config.s.sol";

// --- Configuration ---
string constant FDC_DATA_DIR = "data/crossChainPayment/";
string constant ATTESTATION_TYPE_NAME = "EVMTransaction";

// --- Script Contracts ---

// 1. Prepares the FDC request by calling the verifier API.
contract PrepareAttestationRequest is Script {
    using Surl for *;

    // --- Request Data ---
    // This is a real Sepolia transaction hash where USDC was sent.
    string public constant TRANSACTION_HASH = "0x4e636c6590b22d8dcdade7ee3b5ae5572f42edb1878f09b3034b2f7c3362ef3c";
    string public constant SOURCE_NAME = "testETH"; // Chain ID for Sepolia
    string public constant BASE_SOURCE_NAME = "eth"; // Part of verifier URL

    function prepareRequestBody() private pure returns (string memory) {
        return string.concat(
            '{"transactionHash":"', TRANSACTION_HASH, '",',
            '"requiredConfirmations":"1",',
            '"provideInput":true,',
            '"listEvents":true,',
            '"logIndices":[]}'
        );
    }

    function run() external {
        vm.createDir(FDC_DATA_DIR, true);

        string memory attestationType = FdcBase.toUtf8HexString(ATTESTATION_TYPE_NAME);
        string memory sourceId = FdcBase.toUtf8HexString(SOURCE_NAME);
        string memory requestBody = prepareRequestBody();

        (string[] memory headers, string memory body) = FdcBase.prepareAttestationRequest(attestationType, sourceId, requestBody);

        string memory baseUrl = vm.envString("VERIFIER_URL_TESTNET");
        string memory url = string.concat(baseUrl, "verifier/", BASE_SOURCE_NAME, "/", ATTESTATION_TYPE_NAME, "/prepareRequest");
        console.log("Calling Verifier URL:", url);

        (, bytes memory data) = url.post(headers, body);
        FdcBase.AttestationResponse memory response = FdcBase.parseAttestationRequest(data);

        FdcBase.writeToFile(FDC_DATA_DIR, string.concat(ATTESTATION_TYPE_NAME, "_abiEncodedRequest"), StringsBase.toHexString(response.abiEncodedRequest), true);
        console.log("Successfully prepared attestation request and saved to file.");
    }
}


// 2. Submits the prepared request to the FDC Hub on Flare.
contract SubmitAttestationRequest is Script {
    function run() external {
        string memory requestStr = vm.readLine(string.concat(FDC_DATA_DIR, ATTESTATION_TYPE_NAME, "_abiEncodedRequest.txt"));
        bytes memory request = vm.parseBytes(requestStr);

        uint256 timestamp = FdcBase.submitAttestationRequest(request);
        uint256 votingRoundId = FdcBase.calculateRoundId(timestamp);

        FdcBase.writeToFile(FDC_DATA_DIR, string.concat(ATTESTATION_TYPE_NAME, "_votingRoundId"), Strings.toString(votingRoundId), true);
        console.log("Successfully submitted request. Voting Round ID:", votingRoundId);
    }
}


// 3. Retrieves the proof from the DA Layer after the round is finalized.
// TODO: Constant query like Hardhat until round is finanlized
contract RetrieveProof is Script {
    using Surl for *;

    function run() external {
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL");
        string memory apiKey = vm.envString("X_API_KEY");

        // We import the abiEncodedRequest and votingRoundId from the files
        string memory requestBytes = vm.readLine(string.concat(FDC_DATA_DIR, ATTESTATION_TYPE_NAME, "_abiEncodedRequest.txt"));
        string memory votingRoundId = vm.readLine(string.concat(FDC_DATA_DIR, ATTESTATION_TYPE_NAME, "_votingRoundId.txt"));
        
        console.log("votingRoundId: %s\n", votingRoundId);
        console.log("requestBytes: %s\n", requestBytes);

        // Preparing the proof request
        string[] memory headers = FdcBase.prepareHeaders(apiKey);
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
            "api/v1/fdc/proof-by-request-round-raw"
        );
        console.log("url: %s\n", url);

        (, bytes memory data) = FdcBase.postAttestationRequest(url, headers, body);

        // Decoding the response from JSON data
        bytes memory dataJson = FdcBase.parseData(data);
        FdcBase.ParsableProof memory proof = abi.decode(
            dataJson,
            (FdcBase.ParsableProof)
        );

        IEVMTransaction.Response memory proofResponse = abi.decode(
            proof.responseHex,
            (IEVMTransaction.Response)
        );

        IEVMTransaction.Proof memory finalProof = IEVMTransaction.Proof(
            proof.proofs,
            proofResponse
        );

        // Writing proof to a file
        FdcBase.writeToFile(FDC_DATA_DIR, string.concat(ATTESTATION_TYPE_NAME, "_proof"), StringsBase.toHexString(abi.encode(finalProof)), true);
        console.log("Successfully retrieved proof and saved to file.");
    }
}


// 4. Sends the final proof to the NFTMinter contract to mint the NFT.
contract MintNFT is Script {
    function run() external {
        address minterAddress = CrossChainPaymentConfig.MINTER_ADDRESS;
        require(minterAddress != address(0), "Minter address not set in Config.s.sol");

        string memory proofString = vm.readLine(string.concat(FDC_DATA_DIR, ATTESTATION_TYPE_NAME, "_proof.txt"));
        bytes memory proofBytes = vm.parseBytes(proofString);
        IEVMTransaction.Proof memory proof = abi.decode(proofBytes, (IEVMTransaction.Proof));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        NFTMinter minter = NFTMinter(payable(minterAddress));
        minter.collectAndProcessTransferEvents(proof);

        vm.stopBroadcast();
        
        console.log("Successfully sent proof to NFTMinter contract.");
        TokenTransfer[] memory transfers = minter.getTokenTransfers();
        require(transfers.length > 0, "No token transfer was recorded.");
        console.log("--- Verification ---");
        console.log("Recorded Transfer From:", transfers[0].from);
        console.log("Recorded Transfer To:", transfers[0].to);
        console.log("Recorded Transfer Value:", transfers[0].value);
    }
}