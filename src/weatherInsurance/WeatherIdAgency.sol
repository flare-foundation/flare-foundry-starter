// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {IWeb2Json} from "flare-periphery/src/coston2/IWeb2Json.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";

// All floats are scaled by 1e6
struct WeatherIdDataTransportObject {
    int256 latitude;
    int256 longitude;
    uint256 weatherId;
    string weatherMain;
    string description;
    uint256 temperature;
    uint256 windSpeed;
    uint256 windDeg;
}

contract WeatherIdAgency {
    enum PolicyStatus {
        Unclaimed,
        Open,
        Settled
    }

    struct Policy {
        address holder;
        int256 latitude;
        int256 longitude;
        uint256 startTimestamp;
        uint256 expirationTimestamp;
        uint256 weatherIdThreshold;
        uint256 premium;
        uint256 coverage;
        PolicyStatus status;
        uint256 id;
    }

    Policy[] public registeredPolicies;
    mapping(uint256 => address) public insurers;

    event PolicyCreated(uint256 id, address holder);
    event PolicyClaimed(uint256 id, address insurer);
    event PolicySettled(uint256 id, address winner);
    event PolicyExpired(uint256 id);
    event PolicyRetired(uint256 id);

    function createPolicy(
        int256 latitude,
        int256 longitude,
        uint256 startTimestamp,
        uint256 expirationTimestamp,
        uint256 weatherIdThreshold,
        uint256 coverage
    ) public payable {
        require(msg.value > 0, "No premium paid");
        require(startTimestamp < expirationTimestamp, "Start must be before expiration");
        require(block.timestamp < startTimestamp, "Policy cannot be created in the past");

        Policy memory newPolicy = Policy({
            holder: msg.sender,
            latitude: latitude,
            longitude: longitude,
            startTimestamp: startTimestamp,
            expirationTimestamp: expirationTimestamp,
            weatherIdThreshold: weatherIdThreshold,
            premium: msg.value,
            coverage: coverage,
            status: PolicyStatus.Unclaimed,
            id: registeredPolicies.length
        });

        registeredPolicies.push(newPolicy);
        emit PolicyCreated(newPolicy.id, msg.sender);
    }

    function claimPolicy(uint256 id) public payable {
        Policy storage policy = registeredPolicies[id];
        require(policy.status == PolicyStatus.Unclaimed, "Policy not available to be claimed");
        require(block.timestamp < policy.startTimestamp, "Cannot claim a policy that has already started");
        require(msg.value >= policy.coverage, "Insufficient coverage paid");

        policy.status = PolicyStatus.Open;
        insurers[id] = msg.sender;

        payable(msg.sender).transfer(policy.premium);
        emit PolicyClaimed(id, msg.sender);
    }

    function resolvePolicy(uint256 id, IWeb2Json.Proof calldata proof) public {
        Policy storage policy = registeredPolicies[id];
        require(policy.status == PolicyStatus.Open, "Policy is not open");
        require(block.timestamp >= policy.startTimestamp, "Policy not yet in effect");
        require(block.timestamp <= policy.expirationTimestamp, "Policy has expired");
        require(isJsonApiProofValid(proof), "Invalid FDC proof");

        WeatherIdDataTransportObject memory dto = abi.decode(proof.data.responseBody.abiEncodedData, (WeatherIdDataTransportObject));
        require(dto.latitude == policy.latitude && dto.longitude == policy.longitude, "Proof coordinates do not match policy");

        if (dto.weatherId >= policy.weatherIdThreshold && (dto.weatherId / 100) == (policy.weatherIdThreshold / 100)) {
            policy.status = PolicyStatus.Settled;
            payable(policy.holder).transfer(policy.coverage);
            emit PolicySettled(id, policy.holder);
        }
    }

    function expirePolicy(uint256 id) public {
        Policy storage policy = registeredPolicies[id];
        require(policy.status == PolicyStatus.Open, "Policy is not open");
        require(block.timestamp > policy.expirationTimestamp, "Policy has not yet expired");
        
        policy.status = PolicyStatus.Settled;
        payable(insurers[id]).transfer(policy.coverage);
        emit PolicyExpired(id);
    }

    function retireUnclaimedPolicy(uint256 id) public {
        Policy storage policy = registeredPolicies[id];
        require(policy.status == PolicyStatus.Unclaimed, "Policy is not unclaimed");
        require(block.timestamp > policy.startTimestamp, "Policy has not started yet");

        policy.status = PolicyStatus.Settled;
        payable(policy.holder).transfer(policy.premium);
        emit PolicyRetired(id);
    }

    // --- View Functions ---
    function getPolicy(uint256 id) public view returns (Policy memory) {
        return registeredPolicies[id];
    }
    
    function getInsurer(uint256 id) public view returns (address) { return insurers[id]; }
    function getAllPolicies() public view returns (Policy[] memory) { return registeredPolicies; }
    
    function isJsonApiProofValid(IWeb2Json.Proof calldata _proof) private view returns (bool) {
        return ContractRegistry.getFdcVerification().verifyJsonApi(_proof);
    }
}