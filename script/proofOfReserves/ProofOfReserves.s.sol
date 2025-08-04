// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Surl} from "surl/Surl.sol";
import {Base as FdcBase} from "../fdcExample/Base.s.sol";
import {Base as StringsBase} from "../../src/utils/fdcStrings/Base.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {IWeb2Json} from "flare-periphery/src/coston2/IWeb2Json.sol";
import {IEVMTransaction} from "flare-periphery/src/coston2/IEVMTransaction.sol";
import {MyStablecoin} from "../../src/proofOfReserves/Token.sol";
import {TokenStateReader} from "../../src/proofOfReserves/TokenStateReader.sol";
import {ProofOfReserves} from "../../src/proofOfReserves/ProofOfReserves.sol";
import {ProofOfReservesConfig} from "./Config.s.sol";

string constant FDC_DATA_DIR_POR = "data/proofOfReserves/";

// Deploys contracts. Run once for Coston and once for Coston2.
// forge script script/proofOfReserves/ProofOfReserves.s.sol:Deploy --rpc-url coston --broadcast -vvvv
// forge script script/proofOfReserves/ProofOfReserves.s.sol:Deploy --rpc-url coston2 --broadcast -vvvv
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        uint256 chainId = block.chainid;

        vm.startBroadcast(deployerPrivateKey);

        MyStablecoin token = new MyStablecoin(owner, owner);
        TokenStateReader reader = new TokenStateReader();

        console.log("--- Deployment Results for Chain ID:", chainId, "---");
        console.log("MyStablecoin deployed to:", address(token));
        console.log("TokenStateReader deployed to:", address(reader));

        if (chainId == 114) { // Coston2
            ProofOfReserves por = new ProofOfReserves();
            console.log("ProofOfReserves deployed to:", address(por));
        }

        vm.stopBroadcast();
        console.log("\nACTION REQUIRED: Update script/proofOfReserves/Config.s.sol with the addresses above.");
    }
}

// Creates transactions on Coston and Coston2 to emit provable events.
// forge script script/proofOfReserves/ProofOfReserves.s.sol:ActivateReaders --rpc-url coston --broadcast -vvvv
// forge script script/proofOfReserves/ProofOfReserves.s.sol:ActivateReaders --rpc-url coston2 --broadcast -vvvv
contract ActivateReaders is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 chainId = block.chainid;

        address tokenAddress;
        address readerAddress;

        if (chainId == 16) { // Coston
            tokenAddress = ProofOfReservesConfig.TOKEN_COSTON;
            readerAddress = ProofOfReservesConfig.READER_COSTON;
        } else if (chainId == 114) { // Coston2
            tokenAddress = ProofOfReservesConfig.TOKEN_COSTON2;
            readerAddress = ProofOfReservesConfig.READER_COSTON2;
        } else {
            revert("Unsupported chain ID for this script. Run on Coston (16) or Coston2 (114).");
        }
        require(tokenAddress != address(0) && readerAddress != address(0), "Addresses not set in Config.s.sol");

        TokenStateReader reader = TokenStateReader(readerAddress);
        MyStablecoin token = MyStablecoin(tokenAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        reader.broadcastTokenSupply(token);
        vm.stopBroadcast();
        
        console.log("Reader activated for token:", address(token), "on chain:", chainId);
        console.log("\nACTION REQUIRED: Find the transaction hash for this activation on the block explorer and update TX_HASH in Config.s.sol.");
    }
}

// Step 1: Prepare all attestation requests and save them to files.
// forge script script/proofOfReserves/ProofOfReserves.s.sol:PrepareRequests --rpc-url coston2 --ffi -vvvv
contract PrepareRequests is Script {
    function run() external {
        vm.createDir(FDC_DATA_DIR_POR, true);

        // Prepare and write Web2Json request
        bytes memory web2JsonRequest = prepareWeb2JsonRequest();
        FdcBase.writeToFile(FDC_DATA_DIR_POR, "Web2Json_request.txt", StringsBase.toHexString(web2JsonRequest), true);
        console.log("Web2Json request prepared and saved.");

        // Prepare and write Coston EVM transaction request
        // Using "testSGB" as sourceId and "sgb" as urlTypeBase as per the reference script
        bytes memory evmCostonRequest = prepareEvmTxRequest("testSGB", "sgb", ProofOfReservesConfig.TX_HASH_COSTON);
        FdcBase.writeToFile(FDC_DATA_DIR_POR, "EVMTransaction_Coston_request.txt", StringsBase.toHexString(evmCostonRequest), true);
        console.log("Coston EVM Tx request prepared and saved.");

        // Prepare and write Coston2 EVM transaction request
        // Using "testFLR" as sourceId and "flr" as urlTypeBase as per the reference script
        bytes memory evmCoston2Request = prepareEvmTxRequest("testFLR", "flr", ProofOfReservesConfig.TX_HASH_COSTON2);
        FdcBase.writeToFile(FDC_DATA_DIR_POR, "EVMTransaction_Coston2_request.txt", StringsBase.toHexString(evmCoston2Request), true);
        console.log("Coston2 EVM Tx request prepared and saved.");
    }

    function prepareWeb2JsonRequest() internal returns (bytes memory) {
        string memory apiUrl = "https://api.htdigitalassets.com/alm-stablecoin-db/metrics/current_reserves_amount";
        string memory httpMethod = "GET";
        string memory headersValue = '{\\"Content-Type\\":\\"application/json\\"}';
        string memory queryParamsValue = "{}";
        string memory bodyFieldValue = "{}";
        string memory postProcessJqValue = '{\\"reserves\\": (.value | gsub(\\",\\";\\"\\") | split(\\".\\")[0] | tonumber)}';
        string memory abiSignatureValue = '{\\"components\\":[{\\"internalType\\":\\"uint256\\",\\"name\\":\\"reserves\\",\\"type\\":\\"uint256\\"}],\\"internalType\\":\\"struct DataTransportObject\\",\\"name\\":\\"dto\\",\\"type\\":\\"tuple\\"}';

        string memory requestBody = string.concat(
            '{"url":"', apiUrl, '",',
            '"httpMethod":"', httpMethod, '",',
            '"headers":"', headersValue, '",',
            '"queryParams":"', queryParamsValue, '",',
            '"body":"', bodyFieldValue, '",',
            '"postProcessJq":"', postProcessJqValue, '",',
            '"abiSignature":"', abiSignatureValue, '"}'
        );
        
        string memory url = string.concat(vm.envString("WEB2JSON_VERIFIER_URL_TESTNET"), "Web2Json/prepareRequest");
        
        // --- Debugging Log ---
        console.log("Constructed Web2Json Verifier URL:", url);

        return FdcBase.prepareFdcRequest(url, "Web2Json", "PublicWeb2", requestBody);
    }

    function prepareEvmTxRequest(string memory sourceId, string memory urlTypeBase, string memory txHash) internal returns (bytes memory) {
        string memory requestBody = string.concat('{"transactionHash":"', txHash, '","requiredConfirmations":"1","provideInput":true,"listEvents":true,"logIndices":[]}');
        
        string memory url = string.concat(vm.envString("VERIFIER_URL_TESTNET"), "verifier/", urlTypeBase, "/EVMTransaction/prepareRequest");

        // --- Debugging Log ---
        console.log("Constructed EVMTransaction Verifier URL:", url);

        return FdcBase.prepareFdcRequest(url, "EVMTransaction", sourceId, requestBody);
    }
}
// TODO: fix parsing of web2json request....
// Step 2: Submit requests and save the voting round IDs.
// forge script script/proofOfReserves/ProofOfReserves.s.sol:SubmitRequests --rpc-url coston2 --broadcast -vvvv
contract SubmitRequests is Script {
    function run() external {
        _submitRequest("Web2Json");
        _submitRequest("EVMTransaction_Coston");
        _submitRequest("EVMTransaction_Coston2");
    }

    function _submitRequest(string memory attestationType) private {
        string memory requestFile = string.concat(attestationType, "_request.txt");
        bytes memory request = vm.parseBytes(vm.readLine(string.concat(FDC_DATA_DIR_POR, requestFile)));

        uint256 timestamp = FdcBase.submitAttestationRequest(request);
        uint256 roundId = FdcBase.calculateRoundId(timestamp);

        string memory roundIdFile = string.concat(attestationType, "_roundId.txt");
        // CORRECTED: Save roundId as a plain number string for easier reading.
        FdcBase.writeToFile(FDC_DATA_DIR_POR, roundIdFile, Strings.toString(roundId), true);

        console.log(string.concat(attestationType, " Request submitted in round: "), roundId);
    }
}

// Step 3: Retrieve proofs and save them to files.
// forge script script/proofOfReserves/ProofOfReserves.s.sol:RetrieveProofs --rpc-url coston2 --ffi -vvvv
contract RetrieveProofs is Script {
    // The FDC Protocol ID is a constant on Flare networks.
    uint8 constant FDC_PROTOCOL_ID = 200;

    function run() external {
        console.log("--- Starting RetrieveProofs script ---");

        // --- Retrieve Web2Json Proof ---
        console.log("Reading Web2Json proof files...");
        // CORRECTED: Use vm.readFile for the long hex string.
        bytes memory web2JsonRequest = vm.parseBytes(vm.readFile(string.concat(FDC_DATA_DIR_POR, "Web2Json_request.txt")));
        uint256 roundIdWeb2 = FdcBase.stringToUint(vm.readLine(string.concat(FDC_DATA_DIR_POR, "Web2Json_roundId.txt")));
        console.log("Files read successfully. Retrieving proof for Web2Json...");
        IWeb2Json.Proof memory web2Proof = retrieveWeb2JsonProof(web2JsonRequest, roundIdWeb2);
        FdcBase.writeToFile(FDC_DATA_DIR_POR, "Web2Json_proof.txt", StringsBase.toHexString(abi.encode(web2Proof)), true);
        console.log("Web2Json proof retrieved and saved.");

        // --- Retrieve Coston EVM Proof ---
        console.log("\nReading Coston EVM proof files...");
        // CORRECTED: Use vm.readFile for the long hex string.
        bytes memory evmCostonRequest = vm.parseBytes(vm.readFile(string.concat(FDC_DATA_DIR_POR, "EVMTransaction_Coston_request.txt")));
        uint256 roundIdCoston = FdcBase.stringToUint(vm.readLine(string.concat(FDC_DATA_DIR_POR, "EVMTransaction_Coston_roundId.txt")));
        console.log("Files read successfully. Retrieving proof for Coston EVM transaction...");
        IEVMTransaction.Proof memory evmCostonProof = retrieveEvmProof(evmCostonRequest, roundIdCoston);
        FdcBase.writeToFile(FDC_DATA_DIR_POR, "EVMTransaction_Coston_proof.txt", StringsBase.toHexString(abi.encode(evmCostonProof)), true);
        console.log("Coston EVM proof retrieved and saved.");

        // --- Retrieve Coston2 EVM Proof ---
        console.log("\nReading Coston2 EVM proof files...");
        // CORRECTED: Use vm.readFile for the long hex string.
        bytes memory evmCoston2Request = vm.parseBytes(vm.readFile(string.concat(FDC_DATA_DIR_POR, "EVMTransaction_Coston2_request.txt")));
        uint256 roundIdCoston2 = FdcBase.stringToUint(vm.readLine(string.concat(FDC_DATA_DIR_POR, "EVMTransaction_Coston2_roundId.txt")));
        console.log("Files read successfully. Retrieving proof for Coston2 EVM transaction...");
        IEVMTransaction.Proof memory evmCoston2Proof = retrieveEvmProof(evmCoston2Request, roundIdCoston2);
        FdcBase.writeToFile(FDC_DATA_DIR_POR, "EVMTransaction_Coston2_proof.txt", StringsBase.toHexString(abi.encode(evmCoston2Proof)), true);
        console.log("Coston2 EVM proof retrieved and saved.");
        
        console.log("\n--- RetrieveProofs script finished successfully! ---");
    }

    function retrieveWeb2JsonProof(bytes memory req, uint256 roundId) internal returns (IWeb2Json.Proof memory) {
        bytes memory proofData = FdcBase.retrieveProofWithPolling(FDC_PROTOCOL_ID, StringsBase.toHexString(req), roundId);
        FdcBase.ParsableProof memory p = abi.decode(proofData, (FdcBase.ParsableProof));
        IWeb2Json.Response memory r = abi.decode(p.responseHex, (IWeb2Json.Response));
        return IWeb2Json.Proof(p.proofs, r);
    }

    function retrieveEvmProof(bytes memory req, uint256 roundId) internal returns (IEVMTransaction.Proof memory) {
        bytes memory proofData = FdcBase.retrieveProofWithPolling(FDC_PROTOCOL_ID, StringsBase.toHexString(req), roundId);
        FdcBase.ParsableProof memory p = abi.decode(proofData, (FdcBase.ParsableProof));
        IEVMTransaction.Response memory r = abi.decode(p.responseHex, (IEVMTransaction.Response));
        return IEVMTransaction.Proof(p.proofs, r);
    }
}

// Step 4: Read proofs from files and call the verification contract.
// forge script script/proofOfReserves/ProofOfReserves.s.sol:VerifyReserves --rpc-url coston2 --broadcast -vvvv
contract VerifyReserves is Script {
    function run() external {
        // Read Web2Json proof
        bytes memory web2ProofBytes = vm.parseBytes(vm.readLine(string.concat(FDC_DATA_DIR_POR, "Web2Json_proof.txt")));
        IWeb2Json.Proof memory web2Proof = abi.decode(web2ProofBytes, (IWeb2Json.Proof));

        // Read EVM proofs
        bytes memory evmCostonProofBytes = vm.parseBytes(vm.readLine(string.concat(FDC_DATA_DIR_POR, "EVMTransaction_Coston_proof.txt")));
        IEVMTransaction.Proof memory evmCostonProof = abi.decode(evmCostonProofBytes, (IEVMTransaction.Proof));

        bytes memory evmCoston2ProofBytes = vm.parseBytes(vm.readLine(string.concat(FDC_DATA_DIR_POR, "EVMTransaction_Coston2_proof.txt")));
        IEVMTransaction.Proof memory evmCoston2Proof = abi.decode(evmCoston2ProofBytes, (IEVMTransaction.Proof));

        // Assemble proofs and call contract
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        ProofOfReserves por = ProofOfReserves(payable(ProofOfReservesConfig.PROOF_OF_RESERVES_CONTRACT));

        IEVMTransaction.Proof[] memory evmProofs = new IEVMTransaction.Proof[](2);
        evmProofs[0] = evmCostonProof;
        evmProofs[1] = evmCoston2Proof;

        vm.startBroadcast(deployerPrivateKey);
        por.updateAddress(ProofOfReservesConfig.READER_COSTON, ProofOfReservesConfig.TOKEN_COSTON);
        por.updateAddress(ProofOfReservesConfig.READER_COSTON2, ProofOfReservesConfig.TOKEN_COSTON2);
        bool success = por.verifyReserves(web2Proof, evmProofs);
        vm.stopBroadcast();

        console.log("\n--- VERIFICATION COMPLETE ---");
        console.log("Sufficient Reserves Check Passed:", success);
    }
}