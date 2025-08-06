// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Surl} from "surl/Surl.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base as FdcBase} from "../script/fdcExample/Base.s.sol";
import {Base as StringsBase} from "../src/utils/fdcStrings/Base.sol";
import {IEVMTransaction} from "flare-periphery/src/coston2/IEVMTransaction.sol";
import {NFTMinter, TokenTransfer} from "../src/crossChainPayment/Minter.sol";
import {MyNFT} from "../src/crossChainPayment/NFT.sol";

// --- Base contract for shared configuration and utilities ---
contract CrossChainPaymentBase is Script {
    string constant FDC_DATA_DIR = "data/crossChainPayment/";
    string constant ATTESTATION_TYPE_NAME = "EVMTransaction";
}

// Deploys contracts and writes their addresses to individual .txt files.
//      forge script script/crossChainPayment.s.sol:DeployCrossChainPayment --rpc-url coston2 --broadcast -vvvv
contract DeployCrossChainPayment is CrossChainPaymentBase {
    function run() external returns (address nftAddr, address minterAddr) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        MyNFT nft = new MyNFT(deployerAddress, deployerAddress);
        NFTMinter minter = new NFTMinter(nft);
        
        bytes32 minterRole = nft.MINTER_ROLE();
        nft.grantRole(minterRole, address(minter));
        nft.revokeRole(minterRole, deployerAddress);

        vm.stopBroadcast();
        
        nftAddr = address(nft);
        minterAddr = address(minter);

        vm.createDir(FDC_DATA_DIR, true);
        string memory nftPath = string.concat(FDC_DATA_DIR, "nftAddress.txt");
        string memory minterPath = string.concat(FDC_DATA_DIR, "minterAddress.txt");
        
        vm.writeFile(nftPath, vm.toString(nftAddr));
        vm.writeFile(minterPath, vm.toString(minterAddr));

        console.log("MyNFT deployed to:", nftAddr);
        console.log("NFTMinter deployed to:", minterAddr);
        console.log("MINTER_ROLE configured successfully.");
        console.log("\nConfiguration saved to .txt files in:", FDC_DATA_DIR);
    }
}

// 1. Prepares the FDC request by calling the verifier API.
//      forge script script/crossChainPayment.s.sol:PrepareAttestationRequest --rpc-url coston2 --broadcast --ffi -vvvv
contract PrepareAttestationRequest is CrossChainPaymentBase {
    using Surl for *;

    string public constant TRANSACTION_HASH = "0x4e636c6590b22d8dcdade7ee3b5ae5572f42edb1878f09b3034b2f7c3362ef3c";
    string public constant SOURCE_NAME = "testETH";
    string public constant BASE_SOURCE_NAME = "eth";

    function prepareRequestBody() private pure returns (string memory) {
        return string.concat('{"transactionHash":"', TRANSACTION_HASH, '","requiredConfirmations":"1","provideInput":true,"listEvents":true,"logIndices":[]}');
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

        FdcBase.writeToFile(FDC_DATA_DIR, string.concat(ATTESTATION_TYPE_NAME, "_abiEncodedRequest.txt"), StringsBase.toHexString(response.abiEncodedRequest), true);
        console.log("Successfully prepared attestation request and saved to file.");
    }
}

// 2. Submits the prepared request to the FDC Hub on Flare.
//      forge script script/crossChainPayment.s.sol:SubmitAttestationRequest --rpc-url coston2 --broadcast -vvvv
contract SubmitAttestationRequest is CrossChainPaymentBase {
    function run() external {
        string memory requestStr = vm.readFile(string.concat(FDC_DATA_DIR, ATTESTATION_TYPE_NAME, "_abiEncodedRequest.txt"));
        bytes memory request = vm.parseBytes(requestStr);

        uint256 timestamp = FdcBase.submitAttestationRequest(request);
        uint256 votingRoundId = FdcBase.calculateRoundId(timestamp);

        FdcBase.writeToFile(FDC_DATA_DIR, string.concat(ATTESTATION_TYPE_NAME, "_votingRoundId.txt"), Strings.toString(votingRoundId), true);
        console.log("Successfully submitted request. Voting Round ID:", votingRoundId);
    }
}

// 3. Retrieves the proof from the DA Layer after the round is finalized.
//      forge script script/crossChainPayment.s.sol:RetrieveProof --rpc-url coston2 --broadcast --ffi -vvvv
contract RetrieveProof is CrossChainPaymentBase {
    uint8 constant FDC_PROTOCOL_ID = 200;

    function run() external {
        string memory requestHex = vm.readFile(string.concat(FDC_DATA_DIR, ATTESTATION_TYPE_NAME, "_abiEncodedRequest.txt"));
        string memory votingRoundIdStr = vm.readFile(string.concat(FDC_DATA_DIR, ATTESTATION_TYPE_NAME, "_votingRoundId.txt"));
        uint256 votingRoundId = FdcBase.stringToUint(votingRoundIdStr);
        
        bytes memory proofData = FdcBase.retrieveProofWithPolling(FDC_PROTOCOL_ID, requestHex, votingRoundId);

        FdcBase.ParsableProof memory proof = abi.decode(proofData, (FdcBase.ParsableProof));
        IEVMTransaction.Response memory proofResponse = abi.decode(proof.responseHex, (IEVMTransaction.Response));
        IEVMTransaction.Proof memory finalProof = IEVMTransaction.Proof(proof.proofs, proofResponse);

        FdcBase.writeToFile(FDC_DATA_DIR, string.concat(ATTESTATION_TYPE_NAME, "_proof.txt"), StringsBase.toHexString(abi.encode(finalProof)), true);
        console.log("Successfully retrieved proof and saved to file.");
    }
}

// 4. Sends the final proof to the NFTMinter contract to mint the NFT.
//      forge script script/crossChainPayment.s.sol:MintNFT --rpc-url coston2 --broadcast --ffi -vvvv
contract MintNFT is CrossChainPaymentBase {
    function run() external {
        string memory configPath = string.concat(FDC_DATA_DIR, "minterAddress.txt");
        require(vm.exists(configPath), "Config file not found. Run DeployCrossChainPayment first.");
        address minterAddress = vm.parseAddress(vm.readFile(configPath));
        require(minterAddress != address(0), "Minter address not found in config file.");

        string memory proofString = vm.readFile(string.concat(FDC_DATA_DIR, ATTESTATION_TYPE_NAME, "_proof.txt"));
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
