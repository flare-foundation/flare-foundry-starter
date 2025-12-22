// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Surl } from "surl/Surl.sol";
import { Strings } from "@openzeppelin-contracts/utils/Strings.sol";
import { Base as FdcBase } from "../script/fdcExample/Base.s.sol";
import { Base as StringsBase } from "../src/utils/fdcStrings/Base.sol";
import { IWeb2Json } from "flare-periphery/src/coston2/IWeb2Json.sol";
import { StarWarsCharacterListV3, StarWarsCharacter } from "../src/crossChainFdc/Web2Json.sol";
import { AddressUpdater } from "../src/crossChainFdc/AddressUpdater.sol";
import { FdcVerification } from "../src/crossChainFdc/FdcVerification.sol";
import { IIAddressUpdatable } from "../src/crossChainFdc/IIAddressUpdatable.sol";

// --- Configuration ---
string constant attestationTypeName = "Web2Json";
string constant dirPath = "data/crossChainFdc/";

using stdJson for string;

// solhint-disable-next-line max-line-length
// Deploys the persistent CORE INFRASTRUCTURE contracts to the Target chain (adapt as needed and ensure the Relay is deployed).
// Run this script only once per network.
//      forge script script/CrossChainFdc.s.sol:DeployInfrastructure --rpc-url $XRPLEVM_RPC_URL_TESTNET --broadcast
contract DeployInfrastructure is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address governance = vm.addr(deployerPrivateKey);

        // On a non-Flare chain, the Relay address is a known, pre-deployed address.
        // It must be provided in the .env file.
        address relayAddress = vm.envAddress("RELAY_ADDRESS");

        require(relayAddress != address(0), "Error: RELAY_ADDRESS not set in .env or invalid.");

        vm.startBroadcast(deployerPrivateKey);

        AddressUpdater addressUpdater = new AddressUpdater(governance);
        // The protocol ID must match the one used by the FDC instance on the Flare network (e.g., 200 for Coston2).
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

        vm.stopBroadcast();

        vm.createDir(dirPath, true);
        vm.writeFile(string.concat(dirPath, "addressUpdater.txt"), vm.toString(address(addressUpdater)));
        vm.writeFile(string.concat(dirPath, "fdcVerification.txt"), vm.toString(address(fdcVerification)));
    }
}

// STEP 1: Prepares and submits the FDC request on the Flare Network.
//    *** RUN THIS SCRIPT ON A FLARE NETWORK (e.g., Coston2) ***
//      forge script script/CrossChainFdc.s.sol:PrepareAndSubmitRequest --rpc-url $COSTON2_RPC_URL --broadcast --ffi
contract PrepareAndSubmitRequest is Script {
    using Surl for *;
    string public constant SOURCE_NAME = "PublicWeb2";

    function run() external {
        vm.createDir(dirPath, true);

        string memory attestationType = FdcBase.toUtf8HexString(attestationTypeName);
        string memory sourceId = FdcBase.toUtf8HexString(SOURCE_NAME);

        string memory apiUrl = "https://swapi.info/api/people/3"; // C-3PO
        string
            // solhint-disable-next-line max-line-length
            memory postProcessJq = "{name: .name, height: .height, mass: .mass, numberOfMovies: .films | length, apiUid: (.url | split(\\'/\\') | .[-1] | tonumber)}";
        string
            // solhint-disable-next-line max-line-length
            memory abiSignature = "{\\'components\\':[{\\'internalType\\':\\'string\\',\\'name\\':\\'name\\',\\'type\\':\\'string\\'},{\\'internalType\\':\\'uint256\\',\\'name\\':\\'height\\',\\'type\\':\\'uint256\\'},{\\'internalType\\':\\'uint256\\',\\'name\\':\\'mass\\',\\'type\\':\\'uint256\\'},{\\'internalType\\':\\'uint256\\',\\'name\\':\\'numberOfMovies\\',\\'type\\':\\'uint256\\'},{\\'internalType\\':\\'uint256\\',\\'name\\':\\'apiUid\\',\\'type\\':\\'uint256\\'}],\\'name\\':\\'dto\\',\\'type\\':\\'tuple\\'}";
        string memory requestBody = string.concat(
            "{'url':'",
            apiUrl,
            "','httpMethod':'GET','headers':'{}','queryParams':'{}','body':'{}','postProcessJq':'",
            postProcessJq,
            "','abiSignature':'",
            abiSignature,
            "'}"
        );

        // Prepare request off-chain
        (string[] memory headers, string memory body) = FdcBase.prepareAttestationRequest(
            attestationType,
            sourceId,
            requestBody
        );
        string memory baseUrl = vm.envString("WEB2JSON_VERIFIER_URL_TESTNET");
        string memory url = string.concat(baseUrl, "/", attestationTypeName, "/prepareRequest");
        (, bytes memory data) = url.post(headers, body);
        FdcBase.AttestationResponse memory response = FdcBase.parseAttestationRequest(data);

        // Submit request on-chain
        uint256 timestamp = FdcBase.submitAttestationRequest(response.abiEncodedRequest);
        uint256 votingRoundId = FdcBase.calculateRoundId(timestamp);

        // Write data to files for the next step
        FdcBase.writeToFile(
            dirPath,
            "abiEncodedRequest.txt",
            StringsBase.toHexString(response.abiEncodedRequest),
            true
        );
        FdcBase.writeToFile(dirPath, "votingRoundId.txt", Strings.toString(votingRoundId), true);
    }
}

// STEP 2: Deploys the consumer, waits, retrieves proof, and delivers it on the target chain.
//    *** RUN THIS SCRIPT ON THE TARGET CHAIN (e.g., XRPL Testnet) ***
// solhint-disable-next-line max-line-length
//      forge script script/CrossChainFdc.s.sol:DeliverProofToContract --rpc-url $XRPLEVM_RPC_URL_TESTNET --broadcast --ffi
contract DeliverProofToContract is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // --- Deploy Consumer Contract ---
        string memory fdcVerificationPath = string.concat(dirPath, "fdcVerification.txt");
        require(vm.exists(fdcVerificationPath), "Infrastructure not deployed. Run DeployInfrastructure first.");
        address fdcVerificationAddress = vm.parseAddress(vm.readFile(fdcVerificationPath));

        vm.startBroadcast(deployerPrivateKey);
        StarWarsCharacterListV3 characterList = new StarWarsCharacterListV3(fdcVerificationAddress);
        vm.stopBroadcast();

        // --- Retrieve Proof and Interact ---
        string memory requestHex = vm.readFile(string.concat(dirPath, "abiEncodedRequest.txt"));
        uint256 votingRoundId = FdcBase.stringToUint(vm.readFile(string.concat(dirPath, "votingRoundId.txt")));

        // The FdcVerification contract on the target chain holds the protocol ID for the source Flare network.
        FdcVerification fdcVerification = FdcVerification(fdcVerificationAddress);
        uint8 protocolId = fdcVerification.fdcProtocolId();

        bytes memory proofData = FdcBase.retrieveProof(protocolId, requestHex, votingRoundId);

        FdcBase.ParsableProof memory parsedProof = abi.decode(proofData, (FdcBase.ParsableProof));
        IWeb2Json.Response memory proofResponse = abi.decode(parsedProof.responseHex, (IWeb2Json.Response));
        IWeb2Json.Proof memory finalProof = IWeb2Json.Proof(parsedProof.proofs, proofResponse);

        vm.startBroadcast(deployerPrivateKey);
        characterList.addCharacter{ value: 1 }(finalProof);
        vm.stopBroadcast();

        StarWarsCharacter[] memory characters = characterList.getAllCharacters();
        require(characters.length > 0, "Verification failed: No character was added.");
    }
}
