// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Surl} from "surl/Surl.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base as FdcBase} from "../fdcExample/Base.s.sol";
import {Base as StringsBase} from "../../src/utils/fdcStrings/Base.sol";
import {IWeb2Json} from "flare-periphery/src/coston2/IWeb2Json.sol";
import {WeatherIdAgency} from "../../src/weatherInsurance/WeatherIdAgency.sol";
import {WeatherIdConfig} from "./WeatherIdConfig.s.sol";
import {IFlareSystemsManager} from "flare-periphery/src/coston2/IFlareSystemsManager.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";

string constant FDC_DATA_DIR_WEATHER_ID = "data/weatherInsurance/weatherId/";
string constant ATTESTATION_TYPE_NAME_ID = "Web2Json";

// forge script script/weatherInsurance/WeatherId.s.sol:DeployAgency --rpc-url $COSTON2_RPC_URL --broadcast --verify -vvvv
contract DeployAgency is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        WeatherIdAgency agency = new WeatherIdAgency();
        vm.stopBroadcast();
        console.log("WeatherIdAgency deployed to:", address(agency));
        console.log("\nACTION REQUIRED: Update script/weatherInsurance/WeatherIdConfig.s.sol with this address.");
    }
}

// forge script script/weatherInsurance/WeatherId.s.sol:CreatePolicy --rpc-url $COSTON2_RPC_URL --broadcast --ffi -vvvv
contract CreatePolicy is Script {
    using Surl for *;

    function run() external {
        vm.createDir(FDC_DATA_DIR_WEATHER_ID, true);
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address agencyAddress = WeatherIdConfig.WEATHER_ID_AGENCY_ADDRESS;
        require(agencyAddress != address(0), "Agency address not set in WeatherIdConfig.s.sol");
        WeatherIdAgency agency = WeatherIdAgency(agencyAddress);

        // --- Get exact coordinates from OpenWeatherMap using FFI ---
        string memory apiKey = vm.envString("OPEN_WEATHER_API_KEY");
        string memory initialLat = "46.419"; // Example coordinates
        string memory initialLon = "15.587";
        string memory url = string.concat("https://api.openweathermap.org/data/2.5/weather?lat=", initialLat, "&lon=", initialLon, "&appid=", apiKey, "&units=metric");
        string[] memory headers = new string[](0);
        
        console.log("Fetching exact coordinates from OpenWeatherMap...");
        (, bytes memory data) = url.get(headers);
        bytes memory coordJson = vm.parseJson(vm.toString(data), ".coord");
        // Note: OpenWeatherMap returns numbers, so parseJsonUint is fine. We scale by 1e6.
        int256 actualLat = int256(vm.parseJsonUint(vm.toString(coordJson), ".lat") * 1e6);
        int256 actualLon = int256(vm.parseJsonUint(vm.toString(coordJson), ".lon") * 1e6);

        // --- Policy Parameters ---
        uint256 startOffset = 120; // Starts in 2 minutes
        uint256 duration = 60 * 60; // Lasts 1 hour
        uint256 weatherIdThreshold = 800; // Trigger for "Clouds" category (IDs 800-804). See https://openweathermap.org/weather-conditions
        uint256 premium = 0.01 ether;
        uint256 coverage = 0.1 ether;
        uint256 startTimestamp = block.timestamp + startOffset;
        uint256 expirationTimestamp = startTimestamp + duration;

        vm.startBroadcast(deployerPrivateKey);
        agency.createPolicy{value: premium}(actualLat, actualLon, startTimestamp, expirationTimestamp, weatherIdThreshold, coverage);
        vm.stopBroadcast();
        
        console.log("Policy created successfully for lat/lon:", StringsBase.fromInt(actualLat, 6), StringsBase.fromInt(actualLon, 6));
        console.log("Check the contract on the block explorer for the new policy ID.");
    }
}

// forge script script/weatherInsurance/WeatherId.s.sol:ClaimPolicy --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(uint256)" <POLICY_ID>
contract ClaimPolicy is Script {
    function run(uint256 policyId) external {
        uint256 insurerPrivateKey = vm.envUint("PRIVATE_KEY");
        address agencyAddress = WeatherIdConfig.WEATHER_ID_AGENCY_ADDRESS;
        WeatherIdAgency agency = WeatherIdAgency(agencyAddress);
        
        // Correctly call the getPolicy function
        WeatherIdAgency.Policy memory policy = agency.getPolicy(policyId);
        require(policy.status == WeatherIdAgency.PolicyStatus.Unclaimed, "Policy already claimed or settled");
        
        vm.startBroadcast(insurerPrivateKey);
        agency.claimPolicy{value: policy.coverage}(policyId);
        vm.stopBroadcast();
        
        console.log("Policy", policyId, "claimed successfully by insurer:", vm.addr(insurerPrivateKey));
    }
}

// forge script script/weatherInsurance/WeatherId.s.sol:ResolvePolicy --rpc-url $COSTON2_RPC_URL --broadcast --ffi --sig "run(uint256)" <POLICY_ID>
contract ResolvePolicy is Script {
    using Surl for *;

    function run(uint256 policyId) external {
        address agencyAddress = WeatherIdConfig.WEATHER_ID_AGENCY_ADDRESS;
        WeatherIdAgency agency = WeatherIdAgency(agencyAddress);
        WeatherIdAgency.Policy memory policy = agency.getPolicy(policyId);
        
        bytes memory abiEncodedRequest = prepareFdcRequest(policy.latitude, policy.longitude);
        
        uint256 submissionTimestamp = FdcBase.submitAttestationRequest(abiEncodedRequest);
        IFlareSystemsManager fsm = ContractRegistry.getFlareSystemsManager();
        uint64 firstVotingRoundStartTs = fsm.firstVotingRoundStartTs();
        uint64 votingEpochDurationSeconds = fsm.votingEpochDurationSeconds();

        // Calculate the round in which the request was submitted
        uint256 submissionRoundId = (submissionTimestamp - firstVotingRoundStartTs) / votingEpochDurationSeconds;
        console.log("Attestation request submitted in voting round:", submissionRoundId);

        // The attestation proof will be available in the *next* voting round.
        uint256 finalizationRoundId = submissionRoundId + 1;
        console.log("Proof will be available for retrieval in round:", finalizationRoundId);
        // TODO: FIGURE OUT WAIT AND RECEIVE ATTESTATION REQUEST -- DEBUG

        // Wait for the finalization round to end
        uint256 finalizationRoundEndTs = ((finalizationRoundId + 1) * votingEpochDurationSeconds) + firstVotingRoundStartTs;
        
        // Add a buffer (e.g., 20 seconds) for the data to propagate to the DA layer
        uint256 targetTimestamp = finalizationRoundEndTs + 20;
        uint256 currentTime = block.timestamp;
        
        // TODO: REFACTOR THIS
        if (targetTimestamp > currentTime) {
            uint256 waitDuration = targetTimestamp - currentTime;
            console.log("Waiting for", waitDuration, "seconds for the attestation to be finalized...");
            string[] memory sleepCmd = new string[](3);
            sleepCmd[0] = "bash";
            sleepCmd[1] = "-c";
            sleepCmd[2] = string.concat("sleep ", Strings.toString(waitDuration));
            vm.ffi(sleepCmd);
        }

        // 3. Retrieve the proof off-chain from the DA layer
        string[] memory headers = FdcBase.prepareHeaders(vm.envString("X_API_KEY"));
        string memory body = string.concat(
            '{"votingRoundId":', Strings.toString(finalizationRoundId),
            ',"requestBytes":"', StringsBase.toHexString(abiEncodedRequest), '"}'
        );
        string memory url = string.concat(vm.envString("COSTON2_DA_LAYER_URL"), "api/v1/fdc/proof-by-request-round-raw");

        bytes memory data;
        bool success = false;
        for (uint256 attempt = 0; attempt < 3 && !success; attempt++) {
            console.log("Attempt %d to retrieve proof for round %d...", attempt + 1, finalizationRoundId);
            (, data) = url.post(headers, body);
            string memory dataString = string(data);
            if (bytes(dataString).length > 50) { // Check for a reasonable response length
                success = true;
                console.log("Successfully retrieved proof from DA layer.");
            } else {
                console.log("Error from DA layer (or request not found):", dataString);
                if (attempt < 2) {
                    string[] memory retrySleepCmd = new string[](3);
                    retrySleepCmd[0] = "bash";
                    retrySleepCmd[1] = "-c";
                    retrySleepCmd[2] = "sleep 10";
                    vm.ffi(retrySleepCmd);
                }
            }
        }
        require(success, "Failed to retrieve proof after all retries.");

        // 4. Parse the proof
        bytes memory dataJson = FdcBase.parseData(data);
        FdcBase.ParsableProof memory parsableProof = abi.decode(dataJson, (FdcBase.ParsableProof));
        IWeb2Json.Response memory proofResponse = abi.decode(parsableProof.responseHex, (IWeb2Json.Response));
        IWeb2Json.Proof memory finalProof = IWeb2Json.Proof(parsableProof.proofs, proofResponse);

        // 5. Use the proof in an on-chain transaction
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        agency.resolvePolicy(policyId, finalProof);
        vm.stopBroadcast();

        console.log("ResolvePolicy transaction sent for policy", policyId);
    }

    function prepareFdcRequest(int256 lat, int256 lon) internal returns (bytes memory) {
        string memory attestationType = FdcBase.toUtf8HexString(ATTESTATION_TYPE_NAME_ID);
        string memory sourceId = FdcBase.toUtf8HexString("PublicWeb2");
        string memory requestBody = prepareApiRequestBody(lat, lon);
        (string[] memory headers, string memory body) = FdcBase.prepareAttestationRequest(attestationType, sourceId, requestBody);

        string memory baseUrl = vm.envString("WEB2JSON_VERIFIER_URL_TESTNET");
        string memory url = string.concat(baseUrl, "Web2Json/prepareRequest");

        (, bytes memory data) = url.post(headers, body);
        FdcBase.AttestationResponse memory response = FdcBase.parseAttestationRequest(data);
        require(response.abiEncodedRequest.length > 0, "Verifier returned empty request");
        return response.abiEncodedRequest;
    }

    function prepareApiRequestBody(int256 lat, int256 lon) internal returns (string memory) {
        string memory apiKey = vm.envString("OPEN_WEATHER_API_KEY");
        require(bytes(apiKey).length > 0, "OPEN_WEATHER_API_KEY not set in .env");

        string memory latStr = StringsBase.fromInt(lat, 6);
        string memory lonStr = StringsBase.fromInt(lon, 6);
        
        string memory queryParams = string.concat('{\\"lat\\":\\"', latStr, '\\",\\"lon\\":\\"', lonStr, '\\",\\"units\\":\\"metric\\",\\"appid\\":\\"', apiKey, '\\"}');
        string memory postProcessJq = '{latitude: (.coord.lat | if . != null then .*1000000 else 0 end | floor),longitude: (.coord.lon | if . != null then .*1000000 else 0 end | floor),weatherId: .weather[0].id,weatherMain: .weather[0].main,description: .weather[0].description,temperature: (.main.temp | if . != null then .*1000000 else 0 end | floor),windSpeed: (.wind.speed | if . != null then . *1000000 else 0 end | floor),windDeg: .wind.deg}';
        string memory abiSignature = '{\\"components\\":[{\\"internalType\\":\\"int256\\",\\"name\\":\\"latitude\\",\\"type\\":\\"int256\\"},{\\"internalType\\":\\"int256\\",\\"name\\":\\"longitude\\",\\"type\\":\\"int256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"weatherId\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"string\\",\\"name\\":\\"weatherMain\\",\\"type\\":\\"string\\"},{\\"internalType\\":\\"string\\",\\"name\\":\\"description\\",\\"type\\":\\"string\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"temperature\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"windSpeed\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"windDeg\\",\\"type\\":\\"uint256\\"}],\\"name\\":\\"dto\\",\\"type\\":\\"tuple\\"}';

        return string.concat(
            '{"url":"https://api.openweathermap.org/data/2.5/weather","httpMethod":"GET","headers":"{}","queryParams":"',
            queryParams,
            '","body":"{}","postProcessJq":"',
            postProcessJq,
            '","abiSignature":"',
            abiSignature,
            '"}'
        );
    }
}

// forge script script/weatherInsurance/WeatherId.s.sol:ExpirePolicy --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(uint256)" <POLICY_ID>
contract ExpirePolicy is Script {
    function run(uint256 policyId) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address agencyAddress = WeatherIdConfig.WEATHER_ID_AGENCY_ADDRESS;
        WeatherIdAgency agency = WeatherIdAgency(agencyAddress);

        vm.startBroadcast(deployerPrivateKey);
        agency.expirePolicy(policyId);
        vm.stopBroadcast();

        console.log("Attempted to expire policy", policyId);
    }
}

// forge script script/weatherInsurance/WeatherId.s.sol:RetireUnclaimedPolicy --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(uint256)" <POLICY_ID>
contract RetireUnclaimedPolicy is Script {
    function run(uint256 policyId) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address agencyAddress = WeatherIdConfig.WEATHER_ID_AGENCY_ADDRESS;
        WeatherIdAgency agency = WeatherIdAgency(agencyAddress);

        vm.startBroadcast(deployerPrivateKey);
        agency.retireUnclaimedPolicy(policyId);
        vm.stopBroadcast();

        console.log("Attempted to retire unclaimed policy", policyId);
    }
}