// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Surl} from "surl/Surl.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base as FdcBase} from "../script/fdcExample/Base.s.sol";
import {Base as StringsBase} from "src/utils/fdcStrings/Base.sol";
import {IWeb2Json} from "flare-periphery/src/coston2/IWeb2Json.sol";
import {MinTempAgency} from "src/weatherInsurance/MinTempAgency.sol";
import {IFlareSystemsManager} from "flare-periphery/src/coston2/IFlareSystemsManager.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";

string constant FDC_DATA_DIR = "data/weatherInsurance/";
string constant ATTESTATION_TYPE_NAME = "Web2Json";
uint8 constant FDC_PROTOCOL_ID = 200;

//      forge script script/MinTemp.s.sol:DeployAgency --rpc-url $COSTON2_RPC_URL --broadcast --verify -vvvv
contract DeployAgency is Script {
    function run() external {
        vm.createDir(FDC_DATA_DIR, true);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MinTempAgency agency = new MinTempAgency();
        vm.stopBroadcast();
        console.log("MinTempAgency deployed to:", address(agency));
        
        string memory filePath = string.concat(FDC_DATA_DIR, "MinTempAgency.json");
        string memory json = string.concat('{"agencyAddress":"', vm.toString(address(agency)), '"}');
        vm.writeFile(filePath, json);
        console.log("MinTempAgency address saved to:", filePath);   
    }
}

contract WeatherScriptBase is Script {
    function _getAgency() internal returns (MinTempAgency) {
        string memory filePath = string.concat(FDC_DATA_DIR, "MinTempAgency.json");
        require(vm.exists(filePath), "Config file not found. Please run DeployAgency script first.");
        string memory json = vm.readFile(filePath);
        address agencyAddress = vm.parseJsonAddress(json, ".agencyAddress"); 
        require(agencyAddress != address(0), "Failed to read a valid agency address from config file.");
        return MinTempAgency(agencyAddress);
    }
}


//      forge script script/MinTemp.s.sol:CreatePolicy --rpc-url $COSTON2_RPC_URL --broadcast -vvvv
contract CreatePolicy is WeatherScriptBase {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        MinTempAgency agency = _getAgency();
        int256 latitude = 46419402; // Scaled by 1e6 (e.g., 46.419402 for Maribor, Slovenia)
        int256 longitude = 15587079; // Scaled by 1e6 (e.g., 15.587079)
        uint256 startOffset = 180; // Starts in 3 minutes
        uint256 duration = 60 * 60; // Lasts 1 hour
        int256 minTempThreshold = 10 * 1e6; // 10 degrees Celsius
        uint256 premium = 0.01 ether;
        uint256 coverage = 0.1 ether;
        uint256 startTimestamp = block.timestamp + startOffset;
        uint256 expirationTimestamp = startTimestamp + duration;

        vm.startBroadcast(deployerPrivateKey);
        agency.createPolicy{value: premium}(latitude, longitude, startTimestamp, expirationTimestamp, minTempThreshold, coverage);
        vm.stopBroadcast();
        
        console.log("Policy created successfully. Check the contract on the block explorer for the new policy ID.");
    }
}

//      forge script script/MinTemp.s.sol:ClaimPolicy --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(uint256)" <POLICY_ID>
contract ClaimPolicy is WeatherScriptBase {
    function run(uint256 policyId) external {
        uint256 insurerPrivateKey = vm.envUint("PRIVATE_KEY");
        MinTempAgency agency = _getAgency();
        MinTempAgency.Policy memory policy = agency.getPolicy(policyId);
        require(policy.status == MinTempAgency.PolicyStatus.Unclaimed, "Policy not in Unclaimed state");
        
        vm.startBroadcast(insurerPrivateKey);
        agency.claimPolicy{value: policy.coverage}(policyId);
        vm.stopBroadcast();
        
        console.log("Policy", policyId, "claimed successfully by insurer:", vm.addr(insurerPrivateKey));
    }
}

// STEP 1: Prepare the FDC request for resolving a policy and save it to a file.
//      forge script script/MinTemp.s.sol:PrepareResolveRequest --rpc-url $COSTON2_RPC_URL --broadcast --ffi --sig "run(uint256)" <POLICY_ID>
contract PrepareResolveRequest is WeatherScriptBase {
    function run(uint256 policyId) external {
        console.log("--- Step 1: Preparing resolve request for policy", policyId, "---");
        
        MinTempAgency agency = _getAgency();
        MinTempAgency.Policy memory policy = agency.getPolicy(policyId);

        bytes memory abiEncodedRequest = prepareFdcRequest(policy.latitude, policy.longitude);
        
        FdcBase.writeToFile(FDC_DATA_DIR, "resolve_request.txt", StringsBase.toHexString(abiEncodedRequest), true);
        
        console.log("Successfully prepared attestation request and saved to resolve_request.txt");
    }

    function prepareFdcRequest(int256 lat, int256 lon) internal returns (bytes memory) {
        string memory attestationType = FdcBase.toUtf8HexString(ATTESTATION_TYPE_NAME);
        string memory sourceId = FdcBase.toUtf8HexString("PublicWeb2");
        string memory requestBody = prepareApiRequestBody(lat, lon);
        (string[] memory headers, string memory body) = FdcBase.prepareAttestationRequest(attestationType, sourceId, requestBody);
        string memory baseUrl = vm.envString("WEB2JSON_VERIFIER_URL_TESTNET");
        string memory url = string.concat(baseUrl, "Web2Json/prepareRequest");
        (, bytes memory data) = FdcBase.postAttestationRequest(url, headers, body);
        FdcBase.AttestationResponse memory response = FdcBase.parseAttestationRequest(data);
        require(response.abiEncodedRequest.length > 0, "Verifier returned empty request");
        return response.abiEncodedRequest;
    }

    function prepareApiRequestBody(int256 lat, int256 lon) internal view returns (string memory) {
        string memory apiKey = vm.envString("OPEN_WEATHER_API_KEY");
        require(bytes(apiKey).length > 0, "OPEN_WEATHER_API_KEY not set in .env");
        string memory latStr = StringsBase.fromInt(lat, 6);
        string memory lonStr = StringsBase.fromInt(lon, 6);
        string memory queryParams = string.concat('{\\"lat\\":\\"', latStr, '\\",\\"lon\\":\\"', lonStr, '\\",\\"units\\":\\"metric\\",\\"appid\\":\\"', apiKey, '\\"}');
        string memory postProcessJq = '{\\"latitude\\": (.coord.lat | if . != null then .*1000000 else 0 end | floor),\\"longitude\\": (.coord.lon | if . != null then .*1000000 else 0 end | floor),\\"description\\": .weather[0].description,\\"temperature\\": (.main.temp | if . != null then .*1000000 else 0 end | floor),\\"minTemp\\": (.main.temp_min | if . != null then .*1000000 else 0 end | floor),\\"windSpeed\\": (.wind.speed | if . != null then . *1000000 else 0 end | floor),\\"windDeg\\": .wind.deg}';
        string memory abiSignature = '{\\"components\\":[{\\"internalType\\":\\"int256\\",\\"name\\":\\"latitude\\",\\"type\\":\\"int256\\"},{\\"internalType\\":\\"int256\\",\\"name\\":\\"longitude\\",\\"type\\":\\"int256\\"},{\\"internalType\\":\\"string\\",\\"name\\":\\"description\\",\\"type\\":\\"string\\"},{\\"internalType\\":\\"int256\\",\\"name\\":\\"temperature\\",\\"type\\":\\"int256\\"},{\\"internalType\\":\\"int256\\",\\"name\\":\\"minTemp\\",\\"type\\":\\"int256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"windSpeed\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"windDeg\\",\\"type\\":\\"uint256\\"}],\\"name\\":\\"dto\\",\\"type\\":\\"tuple\\"}';
        return string.concat('{"url":"https://api.openweathermap.org/data/2.5/weather","httpMethod":"GET","headers":"{}","queryParams":"',queryParams,'","body":"{}","postProcessJq":"',postProcessJq,'","abiSignature":"',abiSignature,'"}');
    }
}

// STEP 2: Submit the prepared request to the FDC and save the resulting round ID.
//      forge script script/MinTemp.s.sol:SubmitResolveRequest --rpc-url $COSTON2_RPC_URL --broadcast
contract SubmitResolveRequest is WeatherScriptBase {
    function run() external {
        console.log("--- Step 2: Submitting resolve request to FDC ---");
        
        string memory requestHex = vm.readFile(string.concat(FDC_DATA_DIR, "resolve_request.txt"));
        bytes memory abiEncodedRequest = vm.parseBytes(requestHex);

        uint256 submissionTimestamp = FdcBase.submitAttestationRequest(abiEncodedRequest);
        uint256 submissionRoundId = FdcBase.calculateRoundId(submissionTimestamp);
        
        FdcBase.writeToFile(FDC_DATA_DIR, "resolve_roundId.txt", Strings.toString(submissionRoundId), true);
        
        console.log("Request submitted successfully in Voting Round ID:", submissionRoundId);
    }
}

// STEP 3: Wait for finalization, retrieve the proof, and send the final transaction.
//      forge script script/MinTemp.s.sol:ExecuteResolve --rpc-url $COSTON2_RPC_URL --broadcast --ffi --sig "run(uint256)" <POLICY_ID>
contract ExecuteResolve is WeatherScriptBase {
    function run(uint256 policyId) external {
        console.log("--- Step 3: Executing resolution for policy", policyId, "---");
        
        string memory requestHex = vm.readFile(string.concat(FDC_DATA_DIR, "resolve_request.txt"));
        string memory roundIdStr = vm.readFile(string.concat(FDC_DATA_DIR, "resolve_roundId.txt"));
        uint256 submissionRoundId = FdcBase.stringToUint(roundIdStr);

        // This is the long-running part that waits and polls
        bytes memory proofData = FdcBase.retrieveProofWithPolling(
            FDC_PROTOCOL_ID,
            requestHex,
            submissionRoundId
        );

        // Now broadcast the final transaction
        MinTempAgency agency = _getAgency();
        FdcBase.ParsableProof memory parsableProof = abi.decode(proofData, (FdcBase.ParsableProof));
        IWeb2Json.Response memory proofResponse = abi.decode(parsableProof.responseHex, (IWeb2Json.Response));
        IWeb2Json.Proof memory finalProof = IWeb2Json.Proof(parsableProof.proofs, proofResponse);

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        agency.resolvePolicy(policyId, finalProof);
        vm.stopBroadcast();

        console.log("ResolvePolicy transaction sent successfully for policy", policyId);
    }
}


//      forge script script/MinTemp.s.sol:ExpirePolicy --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(uint256)" <POLICY_ID>
contract ExpirePolicy is WeatherScriptBase {
    function run(uint256 policyId) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        MinTempAgency agency = _getAgency();
        vm.startBroadcast(deployerPrivateKey);
        agency.expirePolicy(policyId);
        vm.stopBroadcast();
        console.log("Attempted to expire policy", policyId);
    }
}

//      forge script script/MinTemp.s.sol:RetireUnclaimedPolicy --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(uint256)" <POLICY_ID>
contract RetireUnclaimedPolicy is WeatherScriptBase {
    function run(uint256 policyId) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        MinTempAgency agency = _getAgency();
        vm.startBroadcast(deployerPrivateKey);
        agency.retireUnclaimedPolicy(policyId);
        vm.stopBroadcast();
        console.log("Attempted to retire unclaimed policy", policyId);
    }
}