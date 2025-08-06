// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Surl} from "surl/Surl.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base as FdcBase} from "../script/fdcExample/Base.s.sol";
import {Base as StringsBase} from "../src/utils/fdcStrings/Base.sol";
import {IWeb2Json} from "flare-periphery/src/coston2/IWeb2Json.sol";
import {IRelay} from "flare-periphery/src/coston2/IRelay.sol";
import {IFdcVerification} from "flare-periphery/src/coston2/IFdcVerification.sol";
import {StarWarsCharacterListV3, IStarWarsCharacterListV3, StarWarsCharacter} from "../src/crossChainFdc/Web2Json.sol";
import {AddressUpdater} from "../src/crossChainFdc/AddressUpdater.sol";
import {FdcVerification} from "../src/crossChainFdc/FdcVerification.sol";
import {IIAddressUpdatable} from "../src/crossChainFdc/IIAddressUpdatable.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";

// --- Configuration ---
string constant attestationTypeName = "Web2Json";
string constant dirPath = "data/crossChainFdc/";

using stdJson for string;

// Deploys all persistent contracts for the example and saves their addresses to individual .txt files.
// Run this script once to set up the on-chain infrastructure.
//      forge script script/CrossChainFdc.s.sol:DeployInfrastructure --rpc-url $COSTON2_RPC_URL --broadcast
contract DeployInfrastructure is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address governance = vm.addr(deployerPrivateKey);

        address relayAddress = address(ContractRegistry.getRelay());
        console.log("Dynamically retrieved Relay address:", relayAddress);
        require(relayAddress != address(0), "Error: Could not retrieve Relay address from ContractRegistry.");

        vm.startBroadcast(deployerPrivateKey);

        AddressUpdater addressUpdater = new AddressUpdater(governance);
        FdcVerification fdcVerification = new FdcVerification(address(addressUpdater), 200);
        
        string[] memory names = new string[](2);
        address[] memory addresses = new address[](2);

        names[0] = "Relay";
        addresses[0] = relayAddress;

        names[1] = "AddressUpdater";
        addresses[1] = address(addressUpdater);
        
        addressUpdater.addOrUpdateContractNamesAndAddresses(names, addresses);
        
        IIAddressUpdatable[] memory contractsToUpdate = new IIAddressUpdatable[](1);
        contractsToUpdate[0] = fdcVerification;
        addressUpdater.updateContractAddresses(contractsToUpdate);

        StarWarsCharacterListV3 characterList = new StarWarsCharacterListV3(address(fdcVerification));

        vm.stopBroadcast();

        vm.createDir(dirPath, true);
        vm.writeFile(string.concat(dirPath, "_addressUpdater.txt"), vm.toString(address(addressUpdater)));
        vm.writeFile(string.concat(dirPath, "_fdcVerification.txt"), vm.toString(address(fdcVerification)));
        vm.writeFile(string.concat(dirPath, "_starWarsCharacterList.txt"), vm.toString(address(characterList)));
        vm.writeFile(string.concat(dirPath, "_relayAddress.txt"), vm.toString(relayAddress));

        console.log("\n--- Infrastructure Deployment Complete ---");
        console.log("Configuration saved to .txt files in:", dirPath);
        console.log("\n--- Contract Addresses ---");
        console.log("AddressUpdater:        ", address(addressUpdater));
        console.log("FdcVerification:       ", address(fdcVerification));
        console.log("StarWarsCharacterList: ", address(characterList));
        console.log("Relay (dynamic):       ", relayAddress);
    }
}

// STEP 1: Prepares the FDC request by calling the verifier API.
//    *** RUN THIS SCRIPT ON A FLARE NETWORK (e.g., Coston2) ***
//      forge script script/CrossChainFdc.s.sol:PrepareRequest --rpc-url $COSTON2_RPC_URL --broadcast --ffi
contract PrepareRequest is Script {
    using Surl for *;
    string public constant SOURCE_NAME = "PublicWeb2";

    function run() external {
        console.log("--- Step 1: Preparing FDC request ---");
        vm.createDir(dirPath, true);

        string memory attestationType = FdcBase.toUtf8HexString(attestationTypeName);
        string memory sourceId = FdcBase.toUtf8HexString(SOURCE_NAME);

        string memory apiUrl = "https://swapi.info/api/people/3"; // C-3PO
        string memory postProcessJq = '{name: .name, height: .height, mass: .mass, numberOfMovies: .films | length, apiUid: (.url | split(\\"/\\") | .[-1] | tonumber)}';
        string memory abiSignature = '{\\"components\\":[{\\"internalType\\":\\"string\\",\\"name\\":\\"name\\",\\"type\\":\\"string\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"height\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"mass\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"numberOfMovies\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"apiUid\\",\\"type\\":\\"uint256\\"}],\\"name\\":\\"dto\\",\\"type\\":\\"tuple\\"}';
        string memory requestBody = string.concat('{"url":"',apiUrl,'","httpMethod":"GET","headers":"{}","queryParams":"{}","body":"{}","postProcessJq":"',postProcessJq,'","abiSignature":"',abiSignature,'"}');

        (string[] memory headers, string memory body) = FdcBase.prepareAttestationRequest(attestationType, sourceId, requestBody);

        string memory baseUrl = vm.envString("WEB2JSON_VERIFIER_URL_TESTNET");
        string memory url = string.concat(baseUrl, attestationTypeName, "/prepareRequest");
        
        (, bytes memory data) = url.post(headers, body);
        FdcBase.AttestationResponse memory response = FdcBase.parseAttestationRequest(data);
        
        FdcBase.writeToFile(dirPath, "_abiEncodedRequest.txt", StringsBase.toHexString(response.abiEncodedRequest), true);
        console.log("Successfully prepared attestation request and saved to abiEncodedRequest.txt");
    }
}

// STEP 2: Submits the prepared request to the FDC Hub on Flare.
//    *** RUN THIS SCRIPT ON A FLARE NETWORK (e.g., Coston2) ***
//      forge script script/CrossChainFdc.s.sol:SubmitRequest --rpc-url $COSTON2_RPC_URL --broadcast
contract SubmitRequest is Script {
    function run() external {
        console.log("--- Step 2: Submitting FDC request ---");
        string memory requestHex = vm.readFile(string.concat(dirPath, "_abiEncodedRequest.txt"));
        bytes memory request = vm.parseBytes(requestHex);

        uint256 timestamp = FdcBase.submitAttestationRequest(request);
        uint256 votingRoundId = FdcBase.calculateRoundId(timestamp);

        FdcBase.writeToFile(dirPath, "_votingRoundId.txt", Strings.toString(votingRoundId), true);
        console.log("Successfully submitted request. Voting Round ID:", votingRoundId);
    }
}

// STEP 3: Waits, retrieves proof, and delivers it to the consumer contract.
//    *** RUN THIS SCRIPT ON THE TARGET CHAIN (e.g., Coston2) ***
//      forge script script/CrossChainFdc.s.sol:InteractWithContract --rpc-url $COSTON2_RPC_URL --broadcast --ffi
contract InteractWithContract is Script {
    function run() external {
        console.log("--- Step 3: Executing proof delivery ---");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address characterListAddress = vm.parseAddress(vm.readFile(string.concat(dirPath, "_starWarsCharacterList.txt")));
        require(characterListAddress != address(0), "starWarsCharacterList address missing from config.");

        StarWarsCharacterListV3 characterList = StarWarsCharacterListV3(characterListAddress);
        console.log("Using StarWarsCharacterListV3 consumer at:", address(characterList));

        string memory requestHex = vm.readFile(string.concat(dirPath, "_abiEncodedRequest.txt"));
        uint256 votingRoundId = FdcBase.stringToUint(vm.readFile(string.concat(dirPath, "_votingRoundId.txt")));
        
        address fdcVerificationAddress = vm.parseAddress(vm.readFile(string.concat(dirPath, "_fdcVerification.txt")));
        require(fdcVerificationAddress != address(0), "FdcVerification address not found in config.");

        FdcVerification fdcVerification = FdcVerification(fdcVerificationAddress);
        uint8 protocolId = fdcVerification.fdcProtocolId();
        
        bytes memory proofData = FdcBase.retrieveProofWithPolling(protocolId, requestHex, votingRoundId);

        FdcBase.ParsableProof memory parsedProof = abi.decode(proofData, (FdcBase.ParsableProof));
        IWeb2Json.Response memory proofResponse = abi.decode(parsedProof.responseHex, (IWeb2Json.Response));
        IWeb2Json.Proof memory finalProof = IWeb2Json.Proof(parsedProof.proofs, proofResponse);

        console.log("\nDelivering proof to consumer contract...");
        vm.startBroadcast(deployerPrivateKey);
        characterList.addCharacter{value: 1}(finalProof);
        vm.stopBroadcast();
        console.log("Proof successfully delivered!");

        StarWarsCharacter[] memory characters = characterList.getAllCharacters();
        require(characters.length > 0, "Verification failed: No character was added.");
        console.log("\n--- Character Added Verification ---");
        console.log("Name:", characters[0].name);
        console.log("Number of Movies:", characters[0].numberOfMovies);
        console.log("API UID:", characters[0].apiUid);
        console.log("BMI:", characters[0].bmi);
    }
}