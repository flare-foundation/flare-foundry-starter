// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./generated/interfaces/verification/IJsonApiVerification.sol";
import "./generated/implementation/verification/JsonApiVerification.sol";

struct Weather {
    int256 latitude; // Latitude in microdegrees
    int256 longitude; // Longitude in microdegrees
    int256 temperature; // Temperature in microkelvins
    int256 windSpeed; // Wind speed in micro-meters per second
    uint256 windDeg; // Wind direction in degrees
    uint256 timestamp; // Timestamp in seconds since epoch
    string[] description; // Weather descriptions
}

contract JsonApiExample {
    Weather[] public weathers;
    IJsonApiVerification public jsonApiAttestationVerification;

    constructor() {
        jsonApiAttestationVerification = new JsonApiVerification();
    }

    function addWeather(IJsonApi.Response calldata jsonResponse) public {
        // We mock the proof for testing and hackathon
        IJsonApi.Proof memory proof = IJsonApi.Proof({
            merkleProof: new bytes32[](0),
            data: jsonResponse
        });
        require(
            jsonApiAttestationVerification.verifyJsonApi(proof),
            "Invalid proof"
        );

        Weather memory _weather = abi.decode(
            jsonResponse.responseBody.abi_encoded_data,
            (Weather)
        );

        weathers.push(_weather);
    }
}
