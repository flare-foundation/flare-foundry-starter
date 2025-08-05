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

// forge script script/MinTemp.s.sol:DeployAgency --rpc-url $COSTON2_RPC_URL --broadcast --verify -vvvv
contract DeployAgency is Script {
    function run() external {
        vm.createDir(FDC_DATA_DIR, true);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MinTempAgency agency = new MinTempAgency();
        vm.stopBroadcast();
        console.log("MinTempAgency deployed to:", address(agency));
        
        // *** FIX: Use a more descriptive key name for clarity. ***
        string memory filePath = string.concat(FDC_DATA_DIR, "MinTempAgency.json");
        string memory json = string.concat('{"agencyAddress":"', vm.toString(address(agency)), '"}');
        vm.writeFile(filePath, json);
        console.log("MinTempAgency address saved to:", filePath);   
    }
}

contract WeatherScriptBase is Script {
    /**
     * @notice Reads the agency address from the JSON config file and returns an initialized contract instance.
     */
    function _getAgency() internal returns (MinTempAgency) {
        string memory filePath = string.concat(FDC_DATA_DIR, "MinTempAgency.json");
        
        require(vm.exists(filePath), "Config file not found. Please run DeployAgency script first.");
        
        string memory json = vm.readFile(filePath);

        // Use the robust vm.parseJsonAddress cheatcode with the correct key.
        // The original code `abi.decode(vm.parseJson(json), (address))` was incorrect and would fail.
        address agencyAddress = vm.parseJsonAddress(json, ".agencyAddress"); 
        
        require(agencyAddress != address(0), "Failed to read a valid agency address from config file.");
        return MinTempAgency(agencyAddress);
    }
}


// forge script script/MinTemp.s.sol:CreatePolicy --rpc-url $COSTON2_RPC_URL --broadcast -vvvv
contract CreatePolicy is WeatherScriptBase {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // *** FIX: Replaced duplicated code with a single, correct helper function call. ***
        MinTempAgency agency = _getAgency();

        // Policy Parameters
        int256 latitude = 46419402; // Scaled by 1e6 (e.g., 46.419402 for Maribor, Slovenia)
        int256 longitude = 15587079; // Scaled by 1e6 (e.g., 15.587079)
        uint256 startOffset = 180; // Starts in 3 minutes to allow for claiming
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

// forge script script/MinTemp.s.sol:ClaimPolicy --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(uint256)" <POLICY_ID>
contract ClaimPolicy is WeatherScriptBase {
    function run(uint256 policyId) external {
        uint256 insurerPrivateKey = vm.envUint("PRIVATE_KEY"); // Using same key for simplicity
        
        // *** FIX: Replaced duplicated code with a single, correct helper function call. ***
        MinTempAgency agency = _getAgency();
        
        MinTempAgency.Policy memory policy = agency.getPolicy(policyId);
        require(policy.status == MinTempAgency.PolicyStatus.Unclaimed, "Policy not in Unclaimed state");
        
        vm.startBroadcast(insurerPrivateKey);
        agency.claimPolicy{value: policy.coverage}(policyId);
        vm.stopBroadcast();
        
        console.log("Policy", policyId, "claimed successfully by insurer:", vm.addr(insurerPrivateKey));
    }
}

// forge script script/MinTemp.s.sol:ResolvePolicy --rpc-url $COSTON2_RPC_URL --broadcast --ffi --sig "run(uint256)" <POLICY_ID>
contract ResolvePolicy is WeatherScriptBase {
    using Surl for *;

    function run(uint256 policyId) external {
        MinTempAgency agency = _getAgency();

        MinTempAgency.Policy memory policy = agency.getPolicy(policyId);
        require(policy.status == MinTempAgency.PolicyStatus.Open, "Policy not in Open state");
        require(block.timestamp > policy.expirationTimestamp, "Policy has not expired yet");

        // 1. Prepare the attestation request off-chain
        bytes memory abiEncodedRequest = prepareFdcRequest(policy.latitude, policy.longitude);

        // 2. Submit the request on-chain to get a voting round ID
        uint256 submissionTimestamp = FdcBase.submitAttestationRequest(abiEncodedRequest);
        IFlareSystemsManager fsm = ContractRegistry.getFlareSystemsManager();
        uint64 firstVotingRoundStartTs = fsm.firstVotingRoundStartTs();
        uint64 votingEpochDurationSeconds = fsm.votingEpochDurationSeconds();

        uint256 submissionRoundId = (submissionTimestamp - firstVotingRoundStartTs) / votingEpochDurationSeconds;
        console.log("Attestation request submitted in voting round:", submissionRoundId);

        uint256 finalizationRoundId = submissionRoundId + 1;
        console.log("Proof will be available for retrieval in round:", finalizationRoundId);

        uint256 finalizationRoundEndTs = ((finalizationRoundId + 1) * votingEpochDurationSeconds) + firstVotingRoundStartTs;
        uint256 targetTimestamp = finalizationRoundEndTs + 20; // Add buffer
        
        if (targetTimestamp > block.timestamp) {
            uint256 waitDuration = targetTimestamp - block.timestamp;
            console.log("Waiting for", waitDuration, "seconds for the attestation to be finalized...");
            vm.sleep(waitDuration);
        }

        // 3. Retrieve the proof off-chain from the DA layer
        string[] memory headers = FdcBase.prepareHeaders(vm.envString("X_API_KEY"));
        string memory body = string.concat(
            '{"votingRoundId":', Strings.toString(finalizationRoundId),
            ',"requestBytes":"', StringsBase.toHexString(abiEncodedRequest), '"}'
        );
        string memory url = string.concat(vm.envString("COSTON2_DA_LAYER_URL"), "api/v1/fdc/proof-by-request-round-raw");

        // todo: fix polling
        bytes memory data = FdcBase.retrieveProofWithPolling(url, headers, body);
        require(data.length > 0, "Failed to retrieve proof after multiple attempts.");

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
        string memory attestationType = FdcBase.toUtf8HexString(ATTESTATION_TYPE_NAME);
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
        string memory postProcessJq = '{\\"latitude\\": (.coord.lat | if . != null then .*1000000 else 0 end | floor),\\"longitude\\": (.coord.lon | if . != null then .*1000000 else 0 end | floor),\\"description\\": .weather[0].description,\\"temperature\\": (.main.temp | if . != null then .*1000000 else 0 end | floor),\\"minTemp\\": (.main.temp_min | if . != null then .*1000000 else 0 end | floor),\\"windSpeed\\": (.wind.speed | if . != null then . *1000000 else 0 end | floor),\\"windDeg\\": .wind.deg}';
        string memory abiSignature = '{\\"components\\":[{\\"internalType\\":\\"int256\\",\\"name\\":\\"latitude\\",\\"type\\":\\"int256\\"},{\\"internalType\\":\\"int256\\",\\"name\\":\\"longitude\\",\\"type\\":\\"int256\\"},{\\"internalType\\":\\"string\\",\\"name\\":\\"description\\",\\"type\\":\\"string\\"},{\\"internalType\\":\\"int256\\",\\"name\\":\\"temperature\\",\\"type\\":\\"int256\\"},{\\"internalType\\":\\"int256\\",\\"name\\":\\"minTemp\\",\\"type\\":\\"int256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"windSpeed\\",\\"type\\":\\"uint256\\"},{\\"internalType\\":\\"uint256\\",\\"name\\":\\"windDeg\\",\\"type\\":\\"uint256\\"}],\\"name\\":\\"dto\\",\\"type\\":\\"tuple\\"}';

        return string.concat('{"url":"https://api.openweathermap.org/data/2.5/weather","httpMethod":"GET","headers":"{}","queryParams":"',queryParams,'","body":"{}","postProcessJq":"',postProcessJq,'","abiSignature":"',abiSignature,'"}');
    }
}

// forge script script/MinTemp.s.sol:ExpirePolicy --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(uint256)" <POLICY_ID>
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

// forge script script/MinTemp.s.sol:RetireUnclaimedPolicy --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(uint256)" <POLICY_ID>
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