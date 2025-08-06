// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Surl} from "surl/Surl.sol";
import {Base as FdcBase} from "../script/fdcExample/Base.s.sol";
import {Base as StringsBase} from "../src/utils/fdcStrings/Base.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {IWeb2Json} from "flare-periphery/src/coston2/IWeb2Json.sol";
import {IEVMTransaction} from "flare-periphery/src/coston2/IEVMTransaction.sol";
import {MyStablecoin} from "../src/proofOfReserves/Token.sol";
import {TokenStateReader} from "../src/proofOfReserves/TokenStateReader.sol";
import {ProofOfReserves} from "../src/proofOfReserves/ProofOfReserves.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";
import {IFdcVerification} from "flare-periphery/src/coston2/IFdcVerification.sol";
import {stdJson} from "forge-std/StdJson.sol";

// stdjson
using stdJson for string;

string constant dirPath = "data/proofOfReserves/";

// Deploys contracts and writes addresses to chain-specific .txt files.
//      forge script script/ProofOfReserves.s.sol:Deploy --rpc-url coston --broadcast
//      forge script script/ProofOfReserves.s.sol:Deploy --rpc-url coston2 --broadcast
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        uint256 chainId = block.chainid;

        vm.createDir(dirPath, true);

        vm.startBroadcast(deployerPrivateKey);

        MyStablecoin token = new MyStablecoin(owner, owner);
        TokenStateReader reader = new TokenStateReader();

        string memory tokenPath = string.concat(dirPath, "_token", Strings.toString(chainId), ".txt");
        string memory readerPath = string.concat(dirPath, "_reader", Strings.toString(chainId), ".txt");
        
        vm.writeFile(tokenPath, vm.toString(address(token)));
        vm.writeFile(readerPath, vm.toString(address(reader)));

        if (chainId == 114) { // Coston2
            ProofOfReserves proofOfReserves = new ProofOfReserves();
            string memory porPath = string.concat(dirPath, "_proofOfReserves", Strings.toString(chainId), ".txt");
            vm.writeFile(porPath, vm.toString(address(proofOfReserves)));
            console.log("ProofOfReserves deployed to:", address(proofOfReserves));
        }

        vm.stopBroadcast();
        
        console.log("--- Deployment Results for Chain ID:", chainId, "---");
        console.log("MyStablecoin deployed to:", address(token));
        console.log("TokenStateReader deployed to:", address(reader));
        console.log("Configuration saved to .txt files in:", dirPath);
    }
}

// Creates transactions and writes the txHash to a chain-specific .txt file.
//      forge script script/ProofOfReserves.s.sol:ActivateReaders --rpc-url coston --broadcast
//      forge script script/ProofOfReserves.s.sol:ActivateReaders --rpc-url coston2 --broadcast
contract ActivateReaders is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 chainId = block.chainid;
        
        // Read addresses from .txt files
        string memory tokenPath = string.concat(dirPath, "_token", Strings.toString(chainId), ".txt");
        string memory readerPath = string.concat(dirPath, "_reader", Strings.toString(chainId), ".txt");

        address tokenAddress = vm.parseAddress(vm.readFile(tokenPath));
        address readerAddress = vm.parseAddress(vm.readFile(readerPath));
        require(tokenAddress != address(0) && readerAddress != address(0), "Addresses not found in .txt config.");

        TokenStateReader reader = TokenStateReader(readerAddress);
        MyStablecoin token = MyStablecoin(tokenAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        reader.broadcastTokenSupply(token);
        vm.stopBroadcast();
        
        string memory receiptPath = string(abi.encodePacked("broadcast/ProofOfReserves.s.sol/", vm.toString(chainId), "/run-latest.json"));
        string memory receiptJson = vm.readFile(receiptPath);
        // We still need stdJson here just to parse the broadcast receipt, which is fine.
        string memory txHash = receiptJson.readString(".transactions[0].transactionHash");
        
        string memory txHashPath = string.concat(dirPath, "_txHash", Strings.toString(chainId), ".txt");
        vm.writeFile(txHashPath, txHash);

        console.log("Reader activated for token:", address(token), "on chain:", chainId);
        console.log("Transaction hash", txHash, "saved to file:", txHashPath);
    }
}

// Prepares requests by reading from chain-specific .txt files.
//      forge script script/ProofOfReserves.s.sol:PrepareRequests --rpc-url coston2 --ffi
contract PrepareRequests is Script {
    function run() external {
        vm.createDir(dirPath, true);

        // Read from both chain-specific config files
        string memory txHashCoston = vm.readFile(string.concat(dirPath, "_txHash_16.txt"));
        string memory txHashCoston2 = vm.readFile(string.concat(dirPath, "_txHash_114.txt"));
        require(bytes(txHashCoston).length > 0 && bytes(txHashCoston2).length > 0, "Transaction hashes not found in .txt configs. Run ActivateReaders on both chains first.");

        bytes memory web2JsonRequest = prepareWeb2JsonRequest();
        FdcBase.writeToFile(dirPath, "_Web2Json_request.txt", StringsBase.toHexString(web2JsonRequest), true);
        console.log("Web2Json request prepared and saved.");

        bytes memory evmCostonRequest = prepareEvmTransactionRequest("testSGB", "sgb", txHashCoston);
        FdcBase.writeToFile(dirPath, "EVMTransaction_Coston_request.txt", StringsBase.toHexString(evmCostonRequest), true);
        console.log("Coston EVM Tx request prepared and saved.");

        bytes memory evmCoston2Request = prepareEvmTransactionRequest("testFLR", "flr", txHashCoston2);
        FdcBase.writeToFile(dirPath, "EVMTransaction_Coston2_request.txt", StringsBase.toHexString(evmCoston2Request), true);
        console.log("Coston2 EVM Tx request prepared and saved.");
    }

    function prepareWeb2JsonRequest() internal returns (bytes memory) {
        string memory apiUrl = "https://api.htdigitalassets.com/alm-stablecoin-db/metrics/current_reserves_amount";
        string memory postProcessJqValue = '{\\"reserves\\": (.value | gsub(\\",\\";\\"\\") | split(\\".\\")[0] | tonumber)}';
        string memory abiSignatureValue = '{\\"components\\":[{\\"internalType\\":\\"uint256\\",\\"name\\":\\"reserves\\",\\"type\\":\\"uint256\\"}],\\"internalType\\":\\"struct DataTransportObject\\",\\"name\\":\\"dto\\",\\"type\\":\\"tuple\\"}';
        string memory requestBody = string.concat('{"url":"',apiUrl,'","httpMethod":"GET","headers":"{\\"Content-Type\\":\\"application/json\\"}","queryParams":"{}","body":"{}","postProcessJq":"',postProcessJqValue,'","abiSignature":"',abiSignatureValue,'"}');
        string memory url = string.concat(vm.envString("WEB2JSON_VERIFIER_URL_TESTNET"), "Web2Json/prepareRequest");
        return FdcBase.prepareFdcRequest(url, "Web2Json", "PublicWeb2", requestBody);
    }

    function prepareEvmTransactionRequest(string memory sourceId, string memory urlTypeBase, string memory txHash) internal returns (bytes memory) {
        string memory requestBody = string.concat('{"transactionHash":"', txHash, '","requiredConfirmations":"1","provideInput":true,"listEvents":true,"logIndices":[]}');
        string memory url = string.concat(vm.envString("VERIFIER_URL_TESTNET"), "verifier/", urlTypeBase, "/EVMTransaction/prepareRequest");
        return FdcBase.prepareFdcRequest(url, "EVMTransaction", sourceId, requestBody);
    }
}

// Step 2: Submit requests and save the voting round IDs.
//      forge script script/ProofOfReserves.s.sol:SubmitRequests --rpc-url coston2 --broadcast
contract SubmitRequests is Script {
    function run() external {
        _submitRequest("Web2Json");
        _submitRequest("EVMTransaction_Coston");
        _submitRequest("EVMTransaction_Coston2");
    }

    function _submitRequest(string memory attestationType) private {
        string memory requestFile = string.concat(attestationType, "_request.txt");
        bytes memory request = vm.parseBytes(vm.readFile(string.concat(dirPath, requestFile)));
        uint256 timestamp = FdcBase.submitAttestationRequest(request);
        uint256 roundId = FdcBase.calculateRoundId(timestamp);
        string memory roundIdFile = string.concat(attestationType, "_roundId.txt");
        FdcBase.writeToFile(dirPath, roundIdFile, Strings.toString(roundId), true);
        console.log(string.concat(attestationType, " Request submitted in round: "), roundId);
    }
}

// Step 3: Retrieve proofs and save them to files.
//      forge script script/ProofOfReserves.s.sol:RetrieveProofs --rpc-url coston2 --ffi
contract RetrieveProofs is Script {
    function run() external {
        bytes memory web2JsonRequest = vm.parseBytes(vm.readFile(string.concat(dirPath, "_Web2Json_request.txt")));
        uint256 roundIdWeb2 = FdcBase.stringToUint(vm.readFile(string.concat(dirPath, "_Web2Json_roundId.txt")));
        IWeb2Json.Proof memory web2Proof = retrieveWeb2JsonProof(web2JsonRequest, roundIdWeb2);
        FdcBase.writeToFile(dirPath, "_Web2Json_proof.txt", StringsBase.toHexString(abi.encode(web2Proof)), true);
        console.log("Web2Json proof retrieved and saved.");

        bytes memory evmCostonRequest = vm.parseBytes(vm.readFile(string.concat(dirPath, "_EVMTransaction_Coston_request.txt")));
        uint256 roundIdCoston = FdcBase.stringToUint(vm.readFile(string.concat(dirPath, "_EVMTransaction_Coston_roundId.txt")));
        IEVMTransaction.Proof memory evmCostonProof = retrieveEvmProof(evmCostonRequest, roundIdCoston);
        FdcBase.writeToFile(dirPath, "_EVMTransaction_Coston_proof.txt", StringsBase.toHexString(abi.encode(evmCostonProof)), true);
        console.log("Coston EVM proof retrieved and saved.");

        bytes memory evmCoston2Request = vm.parseBytes(vm.readFile(string.concat(dirPath, "_EVMTransaction_Coston2_request.txt")));
        uint256 roundIdCoston2 = FdcBase.stringToUint(vm.readFile(string.concat(dirPath, "_EVMTransaction_Coston2_roundId.txt")));
        IEVMTransaction.Proof memory evmCoston2Proof = retrieveEvmProof(evmCoston2Request, roundIdCoston2);
        FdcBase.writeToFile(dirPath, "_EVMTransaction_Coston2_proof.txt", StringsBase.toHexString(abi.encode(evmCoston2Proof)), true);
        console.log("Coston2 EVM proof retrieved and saved.");
    }

    function retrieveWeb2JsonProof(bytes memory req, uint256 roundId) internal returns (IWeb2Json.Proof memory) {
        IFdcVerification fdcVerification = ContractRegistry.getFdcVerification();
        uint8 protocolId = fdcVerification.fdcProtocolId();
        bytes memory proofData = FdcBase.retrieveProofWithPolling(protocolId, StringsBase.toHexString(req), roundId);
        FdcBase.ParsableProof memory p = abi.decode(proofData, (FdcBase.ParsableProof));
        IWeb2Json.Response memory r = abi.decode(p.responseHex, (IWeb2Json.Response));
        return IWeb2Json.Proof(p.proofs, r);
    }

    function retrieveEvmProof(bytes memory req, uint256 roundId) internal returns (IEVMTransaction.Proof memory) {
        IFdcVerification fdcVerification = ContractRegistry.getFdcVerification();
        uint8 protocolId = fdcVerification.fdcProtocolId();
        bytes memory proofData = FdcBase.retrieveProofWithPolling(protocolId, StringsBase.toHexString(req), roundId);
        FdcBase.ParsableProof memory p = abi.decode(proofData, (FdcBase.ParsableProof));
        IEVMTransaction.Response memory r = abi.decode(p.responseHex, (IEVMTransaction.Response));
        return IEVMTransaction.Proof(p.proofs, r);
    }
}

// Step 4: Read proofs from files and call the verification contract.
//      forge script script/ProofOfReserves.s.sol:VerifyReserves --rpc-url coston2 --broadcast
contract VerifyReserves is Script {
    function run() external {
        IWeb2Json.Proof memory web2Proof = abi.decode(vm.parseBytes(vm.readFile(string.concat(dirPath, "_Web2Json_proof.txt"))), (IWeb2Json.Proof));
        IEVMTransaction.Proof memory evmCostonProof = abi.decode(vm.parseBytes(vm.readFile(string.concat(dirPath, "_EVMTransaction_Coston_proof.txt"))), (IEVMTransaction.Proof));
        IEVMTransaction.Proof memory evmCoston2Proof = abi.decode(vm.parseBytes(vm.readFile(string.concat(dirPath, "_EVMTransaction_Coston2_proof.txt"))), (IEVMTransaction.Proof));
        
        address proofOfReservesAddress = vm.parseAddress(vm.readFile(string.concat(dirPath, "_proofOfReserves-114.txt")));
        address readerCostonAddress = vm.parseAddress(vm.readFile(string.concat(dirPath, "_reader16.txt")));
        address tokenCostonAddress = vm.parseAddress(vm.readFile(string.concat(dirPath, "_token16.txt")));
        address readerCoston2Address = vm.parseAddress(vm.readFile(string.concat(dirPath, "_reader114.txt")));
        address tokenCoston2Address = vm.parseAddress(vm.readFile(string.concat(dirPath, "_token114.txt")));
        require(proofOfReservesAddress != address(0), "ProofOfReserves address not found in config.");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        ProofOfReserves por = ProofOfReserves(payable(proofOfReservesAddress));

        IEVMTransaction.Proof[] memory evmProofs = new IEVMTransaction.Proof[](2);
        evmProofs[0] = evmCostonProof;
        evmProofs[1] = evmCoston2Proof;

        vm.startBroadcast(deployerPrivateKey);
        por.updateAddress(readerCostonAddress, tokenCostonAddress);
        por.updateAddress(readerCoston2Address, tokenCoston2Address);
        bool success = por.verifyReserves(web2Proof, evmProofs);
        vm.stopBroadcast();

        console.log("\n--- VERIFICATION COMPLETE ---");
        console.log("Sufficient Reserves Check Passed:", success);
    }
}
