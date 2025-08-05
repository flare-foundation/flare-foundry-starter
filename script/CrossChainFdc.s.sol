// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
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

// --- Configuration ---
string constant ATTESTATION_TYPE_NAME = "Web2Json";
string constant FDC_DATA_DIR = "data/crossChainFdc/";

// Deploys the core infrastructure contracts on the target non-Flare chain.
//      forge script script/CrossChainFdc.s.sol:DeployInfrastructure --rpc-url coston2 --broadcast --private-key $PRIVATE_KEY -vvvv
contract DeployInfrastructure is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address governance = vm.addr(deployerPrivateKey);

        // 1. Get pre-existing Relay address from environment. This is a critical dependency.
        // todo: get relay address from periphery
        address relayAddress = vm.envAddress("RELAY_ADDRESS");
        require(relayAddress != address(0), "Error: RELAY_ADDRESS environment variable not set or invalid.");

        vm.startBroadcast(deployerPrivateKey);

        // 2. Deploy core contracts
        AddressUpdater addressUpdater = new AddressUpdater(governance);
        // The FDC Protocol ID (200) is specific to the State Connector instance on the Flare network.
        FdcVerification fdcVerification = new FdcVerification(address(addressUpdater), 200);
        
        // 3. Configure AddressUpdater with required contract names and addresses
        string[] memory names = new string[](2);
        address[] memory addresses = new address[](2);

        names[0] = "Relay";
        addresses[0] = relayAddress; // Use the address from env

        names[1] = "AddressUpdater";
        addresses[1] = address(addressUpdater);

        addressUpdater.addOrUpdateContractNamesAndAddresses(names, addresses);
        
        // 4. Update FdcVerification so it knows the address of the Relay contract
        IIAddressUpdatable[] memory contractsToUpdate = new IIAddressUpdatable[](1);
        contractsToUpdate[0] = fdcVerification;
        addressUpdater.updateContractAddresses(contractsToUpdate);

        vm.stopBroadcast();

        // 5. Create and write the configuration file AFTER all on-chain operations are successful.
        vm.createDir(FDC_DATA_DIR, true);
        string memory filePath = string.concat(FDC_DATA_DIR, "CrossChainFdcConfig.json");
        
        // Construct a clean, human-readable JSON object.
        string memory json = string.concat(
            '{"addressUpdater":"', vm.toString(address(addressUpdater)),
            '","fdcVerification":"', vm.toString(address(fdcVerification)),
            '","relayAddress":"', vm.toString(relayAddress),
            '"}'
        );
        vm.writeFile(filePath, json);

        // --- Final Log Output ---
        console.log("\n--- Infrastructure Deployment Complete ---");
        console.log("Configuration saved to:", filePath);
        console.log("\n--- Contract Addresses ---");
        console.log("AddressUpdater:  ", address(addressUpdater));
        console.log("FdcVerification: ", address(fdcVerification));
        console.log("Relay (from env):", relayAddress);
        console.log("\nNOTE: The Config.s.sol file is no longer needed and can be deleted.");
    }
}

// 1. Prepares and submits the FDC request on a Flare Network.
//    *** RUN THIS SCRIPT ON A FLARE NETWORK (e.g., Coston2) ***
//      forge script script/CrossChainFdc.s.sol:PrepareAndSubmitRequest --rpc-url coston2 --broadcast --ffi --private-key $PRIVATE_KEY -vvvv
contract PrepareAndSubmitRequest is Script {
    using Surl for *;

    string public constant SOURCE_NAME = "PublicWeb2";

    function run() external {
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
        console.log("Calling Verifier URL:", url);

        (, bytes memory data) = url.post(headers, body);
        FdcBase.AttestationResponse memory response = FdcBase.parseAttestationRequest(data);
        bytes memory abiEncodedRequest = response.abiEncodedRequest;

        // Save for the next step
        FdcBase.writeToFile(FDC_DATA_DIR, "abiEncodedRequest.txt", StringsBase.toHexString(abiEncodedRequest), true);
        
        // Submit request to FDC Hub
        uint256 timestamp = FdcBase.submitAttestationRequest(abiEncodedRequest);
        uint256 votingRoundId = FdcBase.calculateRoundId(timestamp);

        FdcBase.writeToFile(FDC_DATA_DIR, "votingRoundId.txt", Strings.toString(votingRoundId), true);
        console.log("\nSuccessfully prepared and submitted request. Voting Round ID:", votingRoundId);
    }
}


// 2. Deploys the consumer contract and delivers the proof to it.
//    *** RUN THIS SCRIPT ON THE TARGET CHAIN (e.g., Coston2) ***
//      forge script script/CrossChainFdc.s.sol:DeliverProof --rpc-url coston2 --broadcast --ffi --private-key $PRIVATE_KEY -vvvv
contract DeliverProof is Script {
    using Surl for *;

    function run() external {
        console.log("--- DeliverProof script started ---");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // --- Step 1: Read config from JSON file ---
        string memory configPath = string.concat(FDC_DATA_DIR, "CrossChainFdcConfig.json");
        string memory configJson = vm.readFile(configPath);
        require(bytes(configJson).length > 0, "Config file not found or empty. Run DeployInfrastructure first.");

        // Parse addresses using the cleaner vm.parseJsonAddress cheatcode
        address fdcVerificationAddress = vm.parseJsonAddress(configJson, ".fdcVerification");
        address relayAddress = vm.parseJsonAddress(configJson, ".relayAddress");
        require(fdcVerificationAddress != address(0), "fdcVerification address is missing from config JSON.");
        require(relayAddress != address(0), "relayAddress is missing from config JSON.");
        
        // --- Step 2: Deploy the consumer contract ---
        vm.startBroadcast(deployerPrivateKey);
        StarWarsCharacterListV3 characterList = new StarWarsCharacterListV3(fdcVerificationAddress);
        vm.stopBroadcast();
        console.log("StarWarsCharacterListV3 consumer deployed to:", address(characterList));

        // --- Step 3: Wait for Finalization and Retrieve Proof ---
        string memory requestFilePath = string.concat(FDC_DATA_DIR, "abiEncodedRequest.txt");
        string memory roundIdFilePath = string.concat(FDC_DATA_DIR, "votingRoundId.txt");

        require(vm.exists(requestFilePath), "abiEncodedRequest.txt not found. Run PrepareAndSubmitRequest first.");
        require(vm.exists(roundIdFilePath), "votingRoundId.txt not found. Run PrepareAndSubmitRequest first.");

        string memory requestBytesHex = vm.readFile(requestFilePath);
        string memory votingRoundIdStr = vm.readFile(roundIdFilePath);
        uint256 votingRoundId = FdcBase.stringToUint(votingRoundIdStr);
        
        console.log("\nWaiting for round %s to be finalized...", votingRoundIdStr);
        
        // Pass addresses as arguments to avoid re-reading the config file.
        bytes memory proofData = waitForFinalizationAndRetrieveProof(requestBytesHex, votingRoundId, relayAddress, fdcVerificationAddress);

        FdcBase.ParsableProof memory parsedProof = abi.decode(proofData, (FdcBase.ParsableProof));
        IWeb2Json.Response memory proofResponse = abi.decode(parsedProof.responseHex, (IWeb2Json.Response));
        IWeb2Json.Proof memory finalProof = IWeb2Json.Proof(parsedProof.proofs, proofResponse);

        // --- Step 4: Call the consumer contract with the proof ---
        console.log("\nDelivering proof to consumer contract...");
        vm.startBroadcast(deployerPrivateKey);
        characterList.addCharacter{value: 1}(finalProof); // Example value, adjust if needed
        vm.stopBroadcast();
        console.log("Proof successfully delivered!");

        // --- Verification ---
        StarWarsCharacter[] memory characters = characterList.getAllCharacters();
        require(characters.length > 0, "Verification failed: No character was added.");
        console.log("\n--- Character Added Verification ---");
        console.log("Name:", characters[0].name);
        console.log("Number of Movies:", characters[0].numberOfMovies);
        console.log("API UID:", characters[0].apiUid);
        console.log("BMI:", characters[0].bmi);
        console.log("--- Script Finished Successfully ---");
    }

    /// @notice Waits for a round to be finalized on-chain, then polls the DA layer for the proof.
    function waitForFinalizationAndRetrieveProof(
        string memory _requestBytesHex,
        uint256 _votingRoundId,
        address _relayAddress, // Passed in as parameter
        address _fdcVerificationAddress // Passed in as parameter
    ) internal returns (bytes memory) {
        // --- On-Chain Finalization Check (on Target Chain) ---
        IRelay relay = IRelay(_relayAddress);
        IFdcVerification fdcVerification = IFdcVerification(_fdcVerificationAddress);

        console.log("--- Waiting for On-Chain Finalization ---");
        console.log("Relay Contract:", _relayAddress);
        uint8 protocolId = fdcVerification.fdcProtocolId();
        console.log("Checking for finalization of Protocol ID %s, Voting Round ID %s", protocolId, _votingRoundId);

        while (!relay.isFinalized(protocolId, _votingRoundId)) {
            console.log("Round not finalized. Waiting 30 seconds...");
            vm.sleep(30);
        }
        console.log("Round %s is finalized on-chain!", _votingRoundId);

        // --- Off-Chain DA Layer Polling ---
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL");
        require(bytes(daLayerUrl).length > 0, "COSTON2_DA_LAYER_URL env var not set");
        
        string memory url = string.concat(daLayerUrl, "api/v1/fdc/proof-by-request-round-raw");
        console.log("\n--- Polling Data Availability Layer ---");
        console.log("URL:", url);
        
        string[] memory headers = FdcBase.prepareHeaders(vm.envString("X_API_KEY"));
        string memory body = string.concat(
            '{"votingRoundId":', Strings.toString(_votingRoundId),
            ',"requestBytes":"', _requestBytesHex, '"}'
        );

        bytes memory data;
        for (uint256 i = 0; i < 30; i++) { // Poll for ~5 minutes max
            (, bytes memory responseData) = url.post(headers, body);
            // A simple check to see if the response looks like valid proof JSON
            if (bytes(vm.toString(responseData)).length > 100 && vm.parseJsonBool(vm.toString(responseData), ".response_hex")) {
                data = responseData;
                break;
            }
            console.log("Proof not yet available, waiting 10 seconds... (Attempt %s/30)", i + 1);
            vm.sleep(10);
        }

        require(data.length > 0, "Failed to retrieve proof from DA Layer after multiple attempts.");
        console.log("Proof successfully retrieved.");

        return FdcBase.parseData(data);
    }
}