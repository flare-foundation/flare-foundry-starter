// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base as FdcBase} from "../script/fdcExample/Base.s.sol";
import {Base as StringsBase} from "../../src/utils/fdcStrings/Base.sol";
import {IWeb2Json} from "flare-periphery/src/coston2/IWeb2Json.sol";
import {WeatherIdAgency} from "../../src/weatherInsurance/WeatherIdAgency.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";
import {IRelay} from "flare-periphery/src/coston2/IRelay.sol";

string constant FDC_DATA_DIR_WEATHER_ID = "data/weatherInsurance/weatherId/";
uint8 constant FDC_PROTOCOL_ID = 200;

//      forge script script/WeatherId.s.sol:DeployAgency --rpc-url coston2 --broadcast --verify --verifier blockscout --verifier-url https://coston2-explorer.flare.network/api/ --private-key $PRIVATE_KEY
contract DeployAgency is Script {
    function run() external {
        vm.createDir(FDC_DATA_DIR_WEATHER_ID, true);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        WeatherIdAgency agency = new WeatherIdAgency();
        vm.stopBroadcast();
        
        string memory filePath = string.concat(FDC_DATA_DIR_WEATHER_ID, "WeatherIdAgency.json");
        string memory json = string.concat('{"weatherIdAgencyAddress":"', vm.toString(address(agency)), '"}');
        vm.writeFile(filePath, json);
        
        console.log("WeatherIdAgency deployed to:", address(agency));
        console.log("Configuration saved to:", filePath);
    }
}

contract WeatherIdScriptBase is Script {
    /**
     * @notice Reads the agency address from the JSON config file and returns an initialized contract instance.
     */
    function _getAgency() internal returns (WeatherIdAgency) {
        string memory filePath = string.concat(FDC_DATA_DIR_WEATHER_ID, "WeatherIdAgency.json");
        require(vm.exists(filePath), "Config file not found. Please run DeployAgency script first.");
        
        string memory json = vm.readFile(filePath);

        address agencyAddress = vm.parseJsonAddress(json, ".weatherIdAgencyAddress");
        require(agencyAddress != address(0), "Failed to read a valid agency address from config file.");
        return WeatherIdAgency(agencyAddress);
    }
}


//      forge script script/WeatherId.s.sol:CreatePolicy --rpc-url coston2 --broadcast --ffi --private-key $PRIVATE_KEY
contract CreatePolicy is WeatherIdScriptBase {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        WeatherIdAgency agency = _getAgency();

        // --- Get exact coordinates from OpenWeatherMap ---
        string memory apiKey = vm.envString("OPEN_WEATHER_API_KEY");
        require(bytes(apiKey).length > 0, "OPEN_WEATHER_API_KEY must be set in your .env file");
        
        // Using Miami, FL coordinates as it is currently ~5 PM EDT on an August evening.
        string memory url = string.concat("https://api.openweathermap.org/data/2.5/weather?lat=25.7617&lon=-80.1918&appid=", apiKey, "&units=metric");
        console.log("Fetching exact coordinates from OpenWeatherMap...");
        
        string[] memory inputs = new string[](3);
        inputs[0] = "curl";
        inputs[1] = "-s";
        inputs[2] = url;
        string memory jsonResponse = string(vm.ffi(inputs));
        
        string memory latString = vm.parseJsonString(jsonResponse, ".coord.lat");
        string memory lonString = vm.parseJsonString(jsonResponse, ".coord.lon");

        int256 actualLat = FdcBase.stringToScaledInt(latString, 6);
        int256 actualLon = FdcBase.stringToScaledInt(lonString, 6);

        // --- Policy Parameters ---
        uint256 startOffset = 120; // Starts in 2 minutes
        uint256 duration = 60 * 60; // Lasts 1 hour
        uint256 weatherIdThreshold = 800; // ID for "clear sky" is 800. Payout if weather is not clear.
        uint256 premium = 0.01 ether;
        uint256 coverage = 0.1 ether;
        uint256 startTimestamp = block.timestamp + startOffset;
        uint256 expirationTimestamp = startTimestamp + duration;

        vm.startBroadcast(deployerPrivateKey);
        agency.createPolicy{value: premium}(actualLat, actualLon, startTimestamp, expirationTimestamp, weatherIdThreshold, coverage);
        vm.stopBroadcast();
        
        console.log("Policy created successfully for lat/lon:", latString, lonString);
        console.log("Check the contract on the block explorer for the new policy ID.");
    }
}

//      forge script script/WeatherId.s.sol:ClaimPolicy --rpc-url coston2 --broadcast --private-key $PRIVATE_KEY --sig "run(uint256)" <POLICY_ID>
contract ClaimPolicy is WeatherIdScriptBase {
    function run(uint256 policyId) external {
        uint256 insurerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        WeatherIdAgency agency = _getAgency();
        
        WeatherIdAgency.Policy memory policy = agency.getPolicy(policyId);
        require(policy.status == WeatherIdAgency.PolicyStatus.Unclaimed, "Policy already claimed or settled");
        
        vm.startBroadcast(insurerPrivateKey);
        agency.claimPolicy{value: policy.coverage}(policyId);
        vm.stopBroadcast();
        
        console.log("Policy", policyId, "claimed successfully by insurer:", vm.addr(insurerPrivateKey));
    }
}

// STEP 1: Prepare the FDC request and save it to a file.
//      forge script script/WeatherId.s.sol:PrepareResolveRequest --rpc-url coston2 --broadcast --ffi --private-key $PRIVATE_KEY --sig "run(uint256)" <POLICY_ID>
contract PrepareResolveRequest is WeatherIdScriptBase {
    function run(uint256 policyId) external {
        console.log("--- Step 1: Preparing resolve request for policy", policyId, "---");
        
        WeatherIdAgency agency = _getAgency();
        WeatherIdAgency.Policy memory policy = agency.getPolicy(policyId);
        
        bytes memory abiEncodedRequest = _prepareFdcRequest(policy.latitude, policy.longitude);
        
        FdcBase.writeToFile(FDC_DATA_DIR_WEATHER_ID, "resolve_request.txt", StringsBase.toHexString(abiEncodedRequest), true);
        
        console.log("Successfully prepared attestation request and saved to resolve_request.txt");
    }

    function _prepareFdcRequest(int256 lat, int256 lon) private returns (bytes memory) {
        string memory requestBody = _prepareApiRequestBody(lat, lon);
        string memory url = string.concat(vm.envString("WEB2JSON_VERIFIER_URL_TESTNET"), "Web2Json/prepareRequest");
        
        // *** FIX: The 'body' variable should be 'string memory', not 'string[] memory'. ***
        (string[] memory headers, string memory body) = FdcBase.prepareAttestationRequest(
            FdcBase.toUtf8HexString("Web2Json"), 
            FdcBase.toUtf8HexString("PublicWeb2"), 
            requestBody
        );
        
        (, bytes memory data) = FdcBase.postAttestationRequest(url, headers, body);
        
        FdcBase.AttestationResponse memory response = FdcBase.parseAttestationRequest(data);
        require(response.abiEncodedRequest.length > 0, "Verifier returned empty request");
        return response.abiEncodedRequest;
    }

    function _prepareApiRequestBody(int256 lat, int256 lon) private view returns (string memory) {
        string memory apiKey = vm.envString("OPEN_WEATHER_API_KEY");
        require(bytes(apiKey).length > 0, "OPEN_WEATHER_API_KEY not set in .env");

        string memory latStr = FdcBase.fromInt(lat, 6);
        string memory lonStr = FdcBase.fromInt(lon, 6);
        
        string memory queryParams = string.concat('{\\"lat\\":\\"', latStr, '\\",\\"lon\\":\\"', lonStr, '\\",\\"units\\":\\"metric\\",\\"appid\\":\\"', apiKey, '\\"}');
        string memory postProcessJq = '{latitude: (.coord.lat | if . != null then .*1000000 else 0 end | floor),longitude: (.coord.lon | if . != null then .*1000000 else 0 end | floor),weatherId: .weather[0].id,weatherMain: .weather[0].main,description: .weather[0].description,temperature: (.main.temp | if . != null then .*1000000 else 0 end | floor),windSpeed: (.wind.speed | if . != null then . *1000000 else 0 end | floor),windDeg: .wind.deg}';
        string memory abiSignature = '{\\"components\\":[{\\"internalType\\":\\"int256\\",\\"name\\":\\"latitude\\",\\"type\\":\\"int256\\\"},{\\"internalType\\":\\"int256\\",\\"name\\":\\"longitude\\",\\"type\\":\\"int256\\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"weatherId\\",\\"type\\":\\"uint256\\\"},{\\"internalType\\":\\"string\\",\\"name\\":\\"weatherMain\\",\\"type\\":\\"string\\\"},{\\"internalType\\":\\"string\\",\\"name\\":\\"description\\",\\"type\\":\\"string\\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"temperature\\",\\"type\\":\\"uint256\\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"windSpeed\\",\\"type\\":\\"uint256\\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"windDeg\\",\\"type\\":\\"uint256\\\"}],\\"name\\":\\"dto\\",\\"type\\":\\"tuple\\"}';

        return string.concat('{"url":"https://api.openweathermap.org/data/2.5/weather","httpMethod":"GET","headers":"{}","queryParams":"',queryParams,'","body":"{}","postProcessJq":"',postProcessJq,'","abiSignature":"',abiSignature,'"}');
    }
}

// STEP 2: Submit the request to the FDC and save the round ID.
//      forge script script/WeatherId.s.sol:SubmitResolveRequest --rpc-url coston2 --broadcast --private-key $PRIVATE_KEY
contract SubmitResolveRequest is WeatherIdScriptBase {
    function run() external {
        console.log("--- Step 2: Submitting resolve request to FDC ---");
        
        string memory requestHex = vm.readFile(string.concat(FDC_DATA_DIR_WEATHER_ID, "resolve_request.txt"));
        bytes memory abiEncodedRequest = vm.parseBytes(requestHex);

        uint256 submissionTimestamp = FdcBase.submitAttestationRequest(abiEncodedRequest);
        uint256 submissionRoundId = FdcBase.calculateRoundId(submissionTimestamp);
        
        // Save the round ID to a file for the final step
        FdcBase.writeToFile(FDC_DATA_DIR_WEATHER_ID, "resolve_roundId.txt", Strings.toString(submissionRoundId), true);
        
        console.log("Request submitted successfully in Voting Round ID:", submissionRoundId);
    }
}

// STEP 3: Wait for finalization, retrieve the proof, and resolve the policy.
//      forge script script/WeatherId.s.sol:ExecuteResolve --rpc-url coston2 --broadcast --ffi --private-key $PRIVATE_KEY --sig "run(uint256)" <POLICY_ID>
contract ExecuteResolve is WeatherIdScriptBase {
    function run(uint256 policyId) external {
        console.log("--- Step 3: Executing resolution for policy", policyId, "---");
        
        string memory requestHex = vm.readFile(string.concat(FDC_DATA_DIR_WEATHER_ID, "resolve_request.txt"));
        string memory roundIdStr = vm.readFile(string.concat(FDC_DATA_DIR_WEATHER_ID, "resolve_roundId.txt"));
        uint256 submissionRoundId = FdcBase.stringToUint(roundIdStr);

        // This is the long-running part that waits and polls
        bytes memory proofData = FdcBase.retrieveProofWithPolling(
            FDC_PROTOCOL_ID,
            requestHex,
            submissionRoundId
        );

        // Now broadcast the final transaction
        WeatherIdAgency agency = _getAgency();
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

//      forge script script/WeatherId.s.sol:ExpirePolicy --rpc-url coston2 --broadcast --private-key $PRIVATE_KEY --sig "run(uint256)" <POLICY_ID>
contract ExpirePolicy is WeatherIdScriptBase {
    function run(uint256 policyId) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        WeatherIdAgency agency = _getAgency();
        
        vm.startBroadcast(deployerPrivateKey);
        agency.expirePolicy(policyId);
        vm.stopBroadcast();
        console.log("Attempted to expire policy", policyId);
    }
}

//      forge script script/WeatherId.s.sol:RetireUnclaimedPolicy --rpc-url coston2 --broadcast --private-key $PRIVATE_KEY --sig "run(uint256)" <POLICY_ID>
contract RetireUnclaimedPolicy is WeatherIdScriptBase {
    function run(uint256 policyId) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        WeatherIdAgency agency = _getAgency();

        vm.startBroadcast(deployerPrivateKey);
        agency.retireUnclaimedPolicy(policyId);
        vm.stopBroadcast();
        console.log("Attempted to retire unclaimed policy", policyId);
    }
}