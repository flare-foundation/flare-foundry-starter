// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Surl} from "surl/Surl.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base as FdcBase} from "../fdcExample/Base.s.sol";
import {Base as StringsBase} from "../../src/utils/fdcStrings/Base.sol";
import {IWeb2Json} from "flare-periphery/src/coston2/IWeb2Json.sol";
import {IRelay} from "flare-periphery/src/coston2/IRelay.sol";
import {IFdcVerification} from "flare-periphery/src/coston2/IFdcVerification.sol";
import {StarWarsCharacterListV3, IStarWarsCharacterListV3, StarWarsCharacter} from "../../src/crossChainFdc/Web2Json.sol";
import {CrossChainFdcConfig} from "./Config.s.sol";

// --- Configuration ---
string constant FDC_DATA_DIR = "data/crossChainFdc/";
string constant ATTESTATION_TYPE_NAME = "Web2Json";

// 1. Prepares and submits the FDC request.
//    *** RUN THIS SCRIPT ON A FLARE NETWORK (e.g., Coston2) ***
contract PrepareAndSubmitRequest is Script {
    /* ... This contract is correct, no changes needed ... */
    using Surl for *;

    string public constant SOURCE_NAME = "PublicWeb2";

    function run() external {
        vm.createDir(FDC_DATA_DIR, true);

        string memory attestationType = FdcBase.toUtf8HexString(ATTESTATION_TYPE_NAME);
        string memory sourceId = FdcBase.toUtf8HexString(SOURCE_NAME);

        string memory apiUrl = "https://swapi.info/api/people/3";
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
        FdcBase.writeToFile(FDC_DATA_DIR, "abiEncodedRequest", StringsBase.toHexString(abiEncodedRequest), true);
        
        // Submit request to FDC Hub
        uint256 timestamp = FdcBase.submitAttestationRequest(abiEncodedRequest);
        uint256 votingRoundId = FdcBase.calculateRoundId(timestamp);

        FdcBase.writeToFile(FDC_DATA_DIR, "votingRoundId", Strings.toString(votingRoundId), true);
        console.log("Successfully prepared and submitted request. Voting Round ID:", votingRoundId);
    }
}


// 2. Deploys the consumer contract and delivers the proof.
//    *** RUN THIS SCRIPT ON THE TARGET CHAIN (e.g., xrplEVMTestnet) ***
contract DeliverProof is Script {
    using Surl for *;

    function run() external {
        console.log("DeliverProof script started!");

        // --- Step 1: Read config and deploy the consumer contract ---
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address fdcVerificationAddress = CrossChainFdcConfig.FDC_VERIFICATION;
        require(fdcVerificationAddress != address(0), "FDC_VERIFICATION address not set in Config.s.sol");

        vm.startBroadcast(deployerPrivateKey);
        StarWarsCharacterListV3 consumerContract = new StarWarsCharacterListV3(fdcVerificationAddress);
        vm.stopBroadcast();
        console.log("StarWarsCharacterListV3 consumer deployed to:", address(consumerContract));

        // --- Step 2: Wait for Finalization and Retrieve Proof ---
        string memory requestFilePath = string.concat(FDC_DATA_DIR, "abiEncodedRequest.txt");
        string memory roundIdFilePath = string.concat(FDC_DATA_DIR, "votingRoundId.txt");

        // Ensure input files exist before reading them.
        require(vm.exists(requestFilePath), "ERROR: abiEncodedRequest.txt not found. Did you run PrepareAndSubmitRequest script?");
        require(vm.exists(roundIdFilePath), "ERROR: votingRoundId.txt not found. Did you run PrepareAndSubmitRequest script?");

        string memory requestBytesHex = vm.readFile(requestFilePath);
        string memory votingRoundIdStr = vm.readFile(roundIdFilePath);
        uint256 votingRoundId = FdcBase.stringToUint(votingRoundIdStr);
        
        console.log("Waiting for round %s to be finalized on-chain...", votingRoundIdStr);
        
        // This function now contains both the on-chain finalization check and the off-chain API polling
        bytes memory proofData = waitForFinalizationAndRetrieveProof(requestBytesHex, votingRoundId);

        FdcBase.ParsableProof memory parsedProof = abi.decode(proofData, (FdcBase.ParsableProof));
        IWeb2Json.Response memory proofResponse = abi.decode(parsedProof.responseHex, (IWeb2Json.Response));
        IWeb2Json.Proof memory finalProof = IWeb2Json.Proof(parsedProof.proofs, proofResponse);

        // --- Step 3: Call the consumer contract with the proof ---
        vm.startBroadcast(deployerPrivateKey);
        consumerContract.addCharacter{value: 1}(finalProof);
        vm.stopBroadcast();

        console.log("\nSuccessfully delivered proof to consumer contract!");

        // --- Verification ---
        StarWarsCharacter[] memory characters = consumerContract.getAllCharacters();
        require(characters.length > 0, "No character was added.");
        console.log("--- Character Added ---");
        console.log("Name:", characters[0].name);
        console.log("Number of Movies:", characters[0].numberOfMovies);
        console.log("API UID:", characters[0].apiUid);
        console.log("BMI:", characters[0].bmi);
    }

    /// @notice Waits for a round to be finalized on-chain, then polls the DA layer for the proof.
    function waitForFinalizationAndRetrieveProof(
        string memory _requestBytesHex,
        uint256 _votingRoundId
    ) internal returns (bytes memory) {
        // --- On-Chain Finalization Check (on Target Chain) ---
        IRelay relay = IRelay(CrossChainFdcConfig.RELAY_ADDRESS);
        IFdcVerification fdcVerification = IFdcVerification(CrossChainFdcConfig.FDC_VERIFICATION);

        console.log("--- Waiting for Finalization on Target Chain ---");
        console.log("Relay Contract: %s", address(relay));
        console.log("FDC Verification Contract: %s", address(fdcVerification));
        
        // We need the protocolId to check for finalization.
        uint8 protocolId = fdcVerification.fdcProtocolId();

        console.log("Checking for finalization of Voting Round ID: %s", _votingRoundId);
        console.log("Using Protocol ID: %s", protocolId);

        while (!relay.isFinalized(protocolId, _votingRoundId)) {
            console.log("Round not finalized. Waiting 30 seconds...");
            vm.sleep(30); // Sleep for 30 seconds
        }
        console.log("Round %s is finalized on-chain!", _votingRoundId);

        // --- Off-Chain DA Layer Polling (to Flare Network DA Layer) ---
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL");
        require(bytes(daLayerUrl).length > 0, "COSTON2_DA_LAYER_URL env var not set");
        string memory apiKey = vm.envString("X_API_KEY");

        string[] memory headers = FdcBase.prepareHeaders(apiKey);
        string memory body = string.concat(
            '{"votingRoundId":',
            Strings.toString(_votingRoundId),
            ',"requestBytes":"',
            _requestBytesHex,
            '"}'
        );

        string memory url = string.concat(daLayerUrl, "api/v1/fdc/proof-by-request-round-raw");
        console.log("Polling DA Layer URL:", url);

        bytes memory data;
        for (uint256 i = 0; i < 30; i++) { // Poll for ~5 minutes max (30 * 10s)
            (, bytes memory responseData) = url.post(headers, body);
            // Check if the response contains the proof data (is valid JSON with a response_hex field)
            if (bytes(vm.toString(responseData)).length > 100 && vm.parseJsonBool(vm.toString(responseData), ".response_hex")) {
                data = responseData;
                break;
            }
            console.log("Proof not available on DA Layer yet, waiting 10 seconds...");
            vm.sleep(10);
        }

        require(data.length > 0, "Failed to retrieve proof after multiple attempts.");
        console.log("Proof successfully retrieved from DA Layer.");

        return FdcBase.parseData(data);
    }
}