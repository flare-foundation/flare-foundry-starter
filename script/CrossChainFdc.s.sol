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
string constant ATTESTATION_TYPE_NAME = "Web2Json";
string constant FDC_DATA_DIR = "data/crossChainFdc/";
string constant CONFIG_FILE = "CrossChainFdcConfig.json";

using stdJson for string;

// Deploys all persistent contracts for the example and saves their addresses to a JSON file.
// Run this script once to set up the on-chain infrastructure.
//      forge script script/CrossChainFdc.s.sol:DeployInfrastructure --rpc-url coston2 --broadcast --private-key $PRIVATE_KEY -vvvv
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

        // --- CORRECTED JSON WRITING ---
        // Manually construct a simple, flat JSON string to guarantee the correct format
        // and prevent parsing errors in subsequent scripts.
        vm.createDir(FDC_DATA_DIR, true);
        string memory configPath = string.concat(FDC_DATA_DIR, CONFIG_FILE);
        string memory json = string.concat(
            '{"addressUpdater":"', vm.toString(address(addressUpdater)),
            '","fdcVerification":"', vm.toString(address(fdcVerification)),
            '","starWarsCharacterList":"', vm.toString(address(characterList)),
            '","relayAddress":"', vm.toString(relayAddress),
            '"}'
        );
        vm.writeFile(configPath, json);

        console.log("\n--- Infrastructure Deployment Complete ---");
        console.log("Configuration saved to:", configPath);
        console.log("\n--- Contract Addresses ---");
        console.log("AddressUpdater:        ", address(addressUpdater));
        console.log("FdcVerification:       ", address(fdcVerification));
        console.log("StarWarsCharacterList: ", address(characterList));
        console.log("Relay (dynamic):       ", relayAddress);
    }
}

// STEP 1: Prepares the FDC request by calling the verifier API.
//    *** RUN THIS SCRIPT ON A FLARE NETWORK (e.g., Coston2) ***
//      forge script script/CrossChainFdc.s.sol:PrepareRequest --rpc-url coston2 --broadcast --ffi --private-key $PRIVATE_KEY
contract PrepareRequest is Script {
    using Surl for *;
    string public constant SOURCE_NAME = "PublicWeb2";

    function run() external {
        console.log("--- Step 1: Preparing FDC request ---");
        vm.createDir(FDC_DATA_DIR, true);

        string memory attestationType = FdcBase.toUtf8HexString(ATTESTATION_TYPE_NAME);
        string memory sourceId = FdcBase.toUtf8HexString(SOURCE_NAME);

        string memory apiUrl = "https://swapi.info/api/people/3"; // C-3PO
        string memory postProcessJq = '{name: .name, height: .height, mass: .mass, numberOfMovies: .films | length, apiUid: (.url | split(\\"/\\") | .[-1] | tonumber)}';
        string memory abiSignature = '{\\"components\\":[{\\"internalType\\":\\"string\\",\\"name\\":\\"name\\",\\"type\\":\\"string\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"height\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"mass\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"numberOfMovies\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"apiUid\\",\\"type\\":\\"uint256\\"}],\\"name\\":\\"dto\\",\\"type\\":\\"tuple\\"}';
        string memory requestBody = string.concat('{"url":"',apiUrl,'","httpMethod":"GET","headers":"{}","queryParams":"{}","body":"{}","postProcessJq":"',postProcessJq,'","abiSignature":"',abiSignature,'"}');

        (string[] memory headers, string memory body) = FdcBase.prepareAttestationRequest(attestationType, sourceId, requestBody);

        string memory baseUrl = vm.envString("WEB2JSON_VERIFIER_URL_TESTNET");
        string memory url = string.concat(baseUrl, ATTESTATION_TYPE_NAME, "/prepareRequest");
        
        (, bytes memory data) = url.post(headers, body);
        FdcBase.AttestationResponse memory response = FdcBase.parseAttestationRequest(data);
        
        FdcBase.writeToFile(FDC_DATA_DIR, "abiEncodedRequest.txt", StringsBase.toHexString(response.abiEncodedRequest), true);
        console.log("Successfully prepared attestation request and saved to abiEncodedRequest.txt");
    }
}

// STEP 2: Submits the prepared request to the FDC Hub on Flare.
//    *** RUN THIS SCRIPT ON A FLARE NETWORK (e.g., Coston2) ***
//      forge script script/CrossChainFdc.s.sol:SubmitRequest --rpc-url coston2 --broadcast --private-key $PRIVATE_KEY
contract SubmitRequest is Script {
    function run() external {
        console.log("--- Step 2: Submitting FDC request ---");
        string memory requestHex = vm.readFile(string.concat(FDC_DATA_DIR, "abiEncodedRequest.txt"));
        bytes memory request = vm.parseBytes(requestHex);

        uint256 timestamp = FdcBase.submitAttestationRequest(request);
        uint256 votingRoundId = FdcBase.calculateRoundId(timestamp);

        FdcBase.writeToFile(FDC_DATA_DIR, "votingRoundId.txt", Strings.toString(votingRoundId), true);
        console.log("Successfully submitted request. Voting Round ID:", votingRoundId);
    }
}

// STEP 3: Waits, retrieves proof, and delivers it to the consumer contract.
//    *** RUN THIS SCRIPT ON THE TARGET CHAIN (e.g., Coston2) ***
//      forge script script/CrossChainFdc.s.sol:ExecuteProofDelivery --rpc-url coston2 --broadcast --ffi --private-key $PRIVATE_KEY
contract ExecuteProofDelivery is Script {
    function run() external {
        console.log("--- Step 3: Executing proof delivery ---");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        string memory configPath = string.concat(FDC_DATA_DIR, CONFIG_FILE);
        string memory configJson = vm.readFile(configPath);
        require(bytes(configJson).length > 0, "Config file not found. Run DeployInfrastructure first.");

        address characterListAddress = configJson.readAddress(".starWarsCharacterList");
        require(characterListAddress != address(0), "starWarsCharacterList address missing from config.");

        StarWarsCharacterListV3 characterList = StarWarsCharacterListV3(characterListAddress);
        console.log("Using StarWarsCharacterListV3 consumer at:", address(characterList));

        string memory requestHex = vm.readFile(string.concat(FDC_DATA_DIR, "abiEncodedRequest.txt"));
        uint256 votingRoundId = FdcBase.stringToUint(vm.readFile(string.concat(FDC_DATA_DIR, "votingRoundId.txt")));
        
        // --- CORRECTED: Dynamically get protocol ID from the contract instance ---
        // 1. Read the FdcVerification contract's address from the config file.
        address fdcVerificationAddress = configJson.readAddress(".fdcVerification");
        require(fdcVerificationAddress != address(0), "FdcVerification address not found in config.");

        // 2. Instantiate the contract using its address and type.
        FdcVerification fdcVerification = FdcVerification(fdcVerificationAddress);

        // 3. Call the function on the contract instance to get the protocol ID.
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