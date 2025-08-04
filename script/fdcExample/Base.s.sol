// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {Vm} from "dependencies/forge-std-1.9.5/src/Vm.sol";
import {Surl} from "dependencies/surl-0.0.0/src/Surl.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";
import {IFdcHub} from "flare-periphery/src/coston2/IFdcHub.sol";
import {IFlareSystemsManager} from "flare-periphery/src/coston2/IFlareSystemsManager.sol";
import {IAddressValidity} from "flare-periphery/src/coston2/IAddressValidity.sol";
import {TransferEventListener} from "src/FdcTransferEventListener.sol";
import {Base as StringsBase} from "src/utils/fdcStrings/Base.sol";
import {IFdcRequestFeeConfigurations} from "flare-periphery/src/coston2/IFdcRequestFeeConfigurations.sol";
import {IRelay} from "flare-periphery/src/coston2/IRelay.sol";

address constant VM_ADDRESS = address(
    uint160(uint256(keccak256("hevm cheat code")))
);
Vm constant vm = Vm(VM_ADDRESS);

/**
 * @title Base Library
 * @notice A utility library for preparing and handling Flare FDC attestation requests and proofs in a Foundry environment.
 * @dev This library interacts with the Flare Verifier API, Data Availability Layer, and on-chain Flare contracts.
 * It relies on Foundry cheat codes (Vm) for environment variable access and external calls.
 */
library Base {
    using Surl for *;

    //-/////////////////////////////////////////////////////////////////////////
    //                             CONSTANTS
    //-/////////////////////////////////////////////////////////////////////////

    uint256 private constant MAX_FINALIZATION_ATTEMPTS = 40;
    uint256 private constant FINALIZATION_POLL_INTERVAL_SECONDS = 30;
    uint256 private constant MAX_DA_LAYER_ATTEMPTS = 15;
    uint256 private constant DA_LAYER_POLL_INTERVAL_SECONDS = 10;
    uint256 private constant PADDED_HEX_STRING_LENGTH = 64;

    //-/////////////////////////////////////////////////////////////////////////
    //                               STRUCTS
    //-/////////////////////////////////////////////////////////////////////////

    struct ParsableProof {
        bytes32 attestationType;
        bytes32[] proofs;
        bytes responseHex;
    }

    struct AttestationResponse {
        bytes abiEncodedRequest;
        string status;
    }

    struct ProofRequest {
        string roundId;
        string requestBytes;
    }

    //-/////////////////////////////////////////////////////////////////////////
    //                      VERIFIER API HELPERS
    //-/////////////////////////////////////////////////////////////////////////

    /**
     * @notice A generic function to prepare an FDC request for the Verifier API.
     * @param url The Verifier API endpoint URL.
     * @param attestationTypeName The name of the attestation type (e.g., "AddressValidity").
     * @param sourceName The name of the data source (e.g., "Etherscan").
     * @param requestBody The JSON string representing the specific request parameters.
     * @return abiEncodedRequest The ABI-encoded request data from the verifier.
     */
    function prepareFdcRequest(
        string memory url,
        string memory attestationTypeName,
        string memory sourceName,
        string memory requestBody
    ) internal returns (bytes memory abiEncodedRequest) {
        string memory attestationTypeHex = toUtf8HexString(attestationTypeName);
        string memory sourceIdHex = toUtf8HexString(sourceName);

        (string[] memory headers, string memory body) = prepareAttestationRequest(
            attestationTypeHex,
            sourceIdHex,
            requestBody
        );

        (, bytes memory data) = postAttestationRequest(url, headers, body);

        AttestationResponse memory response = parseAttestationRequest(data);

        // Check for a "VALID" response from the verifier.
        require(
            keccak256(bytes(response.status)) == keccak256(bytes("VALID")),
            string.concat("Verifier API error for ", attestationTypeName, " request: ", response.status)
        );

        require(response.abiEncodedRequest.length > 0, "Verifier returned an empty request despite a VALID status.");

        return response.abiEncodedRequest;
    }

    /**
     * @notice Prepares the full attestation request payload for the Verifier API.
     * @param attestationType The hex-encoded attestation type.
     * @param sourceId The hex-encoded source ID.
     * @param requestBody The JSON string for the request body.
     * @return headers An array of HTTP headers.
     * @return body The complete JSON request body as a string.
     */
    function prepareAttestationRequest(
        string memory attestationType,
        string memory sourceId,
        string memory requestBody
    ) internal view returns (string[] memory headers, string memory body) {
        string memory apiKey = vm.envString("VERIFIER_API_KEY_TESTNET");
        headers = prepareHeaders(apiKey);
        body = prepareBody(attestationType, sourceId, requestBody);
        console.log("headers: {%s, %s}\n", headers[0], headers[1]);
        console.log("body: %s\n", body);
    }

    /**
     * @notice Prepares the HTTP headers for an API request.
     * @param apiKey The API key for authentication.
     * @return headers An array of formatted HTTP header strings.
     */
    function prepareHeaders(string memory apiKey) internal pure returns (string[] memory headers) {
        headers = new string[](2);
        headers[0] = string.concat('"X-API-KEY": "', apiKey, '"');
        headers[1] = '"Content-Type": "application/json"';
        return headers;
    }

    /**
     * @notice Constructs the JSON body for the Verifier API request.
     * @param attestationType The hex-encoded attestation type.
     * @param sourceId The hex-encoded source ID.
     * @param body The specific request body content.
     * @return The complete JSON body as a string.
     */
    function prepareBody(
        string memory attestationType,
        string memory sourceId,
        string memory body
    ) internal pure returns (string memory) {
        return string.concat(
            '{"attestationType": "',
            attestationType,
            '", "sourceId": "',
            sourceId,
            '", "requestBody": ',
            body,
            "}"
        );
    }

    /**
     * @notice Sends a POST request to the specified URL.
     * @param url The target URL.
     * @param headers An array of HTTP headers.
     * @param body The request body.
     * @return status The HTTP status code of the response.
     * @return data The response data.
     */
    function postAttestationRequest(
        string memory url,
        string[] memory headers,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        (status, data) = url.post(headers, body);
        return (status, data);
    }

    //-/////////////////////////////////////////////////////////////////////////
    //                      ON-CHAIN INTERACTION HELPERS
    //-/////////////////////////////////////////////////////////////////////////

    /**
     * @notice Submits an ABI-encoded attestation request to the FdcHub contract.
     * @dev Uses Foundry's `vm.broadcast` to send the transaction.
     * @param abiEncodedRequest The ABI-encoded request data from the verifier.
     * @return timestamp The block timestamp of the submission transaction.
     */
    function submitAttestationRequest(bytes memory abiEncodedRequest) internal returns (uint256 timestamp) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IFdcRequestFeeConfigurations fdcRequestFeeConfigurations = ContractRegistry.getFdcRequestFeeConfigurations();
        uint256 requestFee = fdcRequestFeeConfigurations.getRequestFee(abiEncodedRequest);
        console.log("request fee: %s\n", requestFee);
        vm.stopBroadcast();

        vm.startBroadcast(deployerPrivateKey);
        IFdcHub fdcHub = ContractRegistry.getFdcHub();
        console.log("fcdHub address: %s\n", address(fdcHub));
        fdcHub.requestAttestation{value: requestFee}(abiEncodedRequest);
        timestamp = vm.getBlockTimestamp();
        vm.stopBroadcast();
        return timestamp;
    }

    /**
     * @notice Calculates the voting round ID for a given timestamp.
     * @param timestamp The timestamp to calculate the round ID for.
     * @return roundId The corresponding voting round ID.
     */
    function calculateRoundId(uint256 timestamp) internal returns (uint256 roundId) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IFlareSystemsManager flareSystemsManager = ContractRegistry.getFlareSystemsManager();
        uint64 firstVotingRoundStartTs = flareSystemsManager.firstVotingRoundStartTs();
        uint64 rewardEpochDurationSeconds = flareSystemsManager.votingEpochDurationSeconds();
        console.log("timestamp: %s\n", timestamp);
        console.log("firstVotingRoundStartTs: %s\n", firstVotingRoundStartTs);
        console.log("rewardEpochDurationSeconds: %s\n", rewardEpochDurationSeconds);
        roundId = (timestamp - uint256(firstVotingRoundStartTs)) / uint256(rewardEpochDurationSeconds);
        console.log("roundId: %s\n", Strings.toString(roundId));
        vm.stopBroadcast();
        return roundId;
    }

    //-/////////////////////////////////////////////////////////////////////////
    //                      POLLING & PROOF RETRIEVAL
    //-/////////////////////////////////////////////////////////////////////////

    /**
     * @notice Waits for a specific voting round to be finalized on-chain.
     * @dev Polls the `isFinalized` function on the Relay contract.
     * @param protocolId The protocol ID for the attestation.
     * @param roundId The voting round ID to check.
     */
    function waitForRoundFinalization(uint8 protocolId, uint256 roundId) internal {
        IRelay relay = ContractRegistry.getRelay();
        console.log("Using Relay contract at address:", address(relay));
        console.log(
            "Waiting for on-chain finalization of Voting Round ID: %s using Protocol ID: %s",
            Strings.toString(roundId),
            Strings.toString(protocolId)
        );

        for (uint256 i = 0; i < MAX_FINALIZATION_ATTEMPTS; i++) {
            vm.roll(block.number + 1); // Ensure state change is reflected
            if (relay.isFinalized(protocolId, roundId)) {
                console.log("Round %s is finalized on-chain!", Strings.toString(roundId));
                return;
            }
            console.log(
                "Round not finalized (attempt %s/%s). Waiting %s seconds...",
                Strings.toString(i + 1),
                Strings.toString(MAX_FINALIZATION_ATTEMPTS),
                Strings.toString(FINALIZATION_POLL_INTERVAL_SECONDS)
            );
            vm.sleep(FINALIZATION_POLL_INTERVAL_SECONDS);
        }
        revert(
            "Failed to confirm round finalization on-chain. The network may be slow or the roundId/protocolId may be incorrect."
        );
    }

    /**
     * @notice Retrieves a proof from the Data Availability Layer with polling.
     * @dev First waits for the round to be finalized on-chain, then polls the DA Layer API.
     * @param protocolId The protocol ID.
     * @param requestBytesHex The hex representation of the request bytes.
     * @param votingRoundId The voting round ID.
     * @return The JSON data containing the proof.
     */
    function retrieveProofWithPolling(
        uint8 protocolId,
        string memory requestBytesHex,
        uint256 votingRoundId
    ) internal returns (bytes memory) {
        // Stage 1: Wait for on-chain finalization
        waitForRoundFinalization(protocolId, votingRoundId);

        // Stage 2: Poll the Data Availability Layer
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL");
        require(bytes(daLayerUrl).length > 0, "COSTON2_DA_LAYER_URL env var not set");

        string[] memory headers = prepareHeaders(vm.envString("X_API_KEY"));
        string memory body = string.concat(
            '{"votingRoundId":',
            Strings.toString(votingRoundId),
            ',"requestBytes":"',
            requestBytesHex,
            '"}'
        );
        string memory url = string.concat(daLayerUrl, "api/v1/fdc/proof-by-request-round-raw");

        console.log("Polling DA Layer URL:", url);
        console.log("Request Body:", body);

        bytes memory data;
        for (uint256 i = 0; i < MAX_DA_LAYER_ATTEMPTS; i++) {
            (, bytes memory responseData) = postAttestationRequest(url, headers, body);
            string memory responseString = string(responseData);

            if (bytes(responseString).length > 100 && vm.parseJsonBool(responseString, ".response_hex")) {
                console.log("Proof successfully retrieved from DA Layer.");
                data = parseData(responseData);
                break;
            }
            console.log(
                "Proof not available on DA Layer yet (attempt %s/%s). Waiting %s seconds...",
                Strings.toString(i + 1),
                Strings.toString(MAX_DA_LAYER_ATTEMPTS),
                Strings.toString(DA_LAYER_POLL_INTERVAL_SECONDS)
            );
            vm.sleep(DA_LAYER_POLL_INTERVAL_SECONDS);
        }

        require(data.length > 0, "Failed to retrieve proof after multiple attempts.");
        return data;
    }

    //-/////////////////////////////////////////////////////////////////////////
    //                          PARSING UTILITIES
    //-/////////////////////////////////////////////////////////////////////////

    /**
     * @notice Parses a raw JSON byte string using Foundry's `parseJson`.
     * @param data The raw byte data from an API response.
     * @return The parsed JSON data.
     */
    function parseData(bytes memory data) internal pure returns (bytes memory) {
        console.log("raw data: ");
        console.logBytes(data);
        string memory dataJsonString = string(data);
        console.log("data: %s\n", dataJsonString);
        return vm.parseJson(dataJsonString);
    }

    /**
     * @notice Parses the attestation response JSON into the AttestationResponse struct.
     * @param data The raw byte data from the Verifier API.
     * @return response The parsed `AttestationResponse` struct.
     */
    function parseAttestationRequest(bytes memory data) internal pure returns (AttestationResponse memory response) {
        string memory dataString = string(data);
        console.log("data: %s\n", dataString);
        bytes memory dataJson = vm.parseJson(dataString);
        response = abi.decode(dataJson, (AttestationResponse));
        console.log("response status: %s\n", response.status);
        console.log("response abiEncodedRequest: ");
        console.logBytes(response.abiEncodedRequest);
    }

    //-/////////////////////////////////////////////////////////////////////////
    //                          STRING UTILITIES
    //-/////////////////////////////////////////////////////////////////////////

    /**
     * @notice Converts a string to a right-padded 32-byte hex string (64 hex chars).
     * @param _string The input string.
     * @return A 64-character hex string prefixed with "0x".
     */
    function toUtf8HexString(string memory _string) internal pure returns (string memory) {
        string memory encodedString = StringsBase.toHexString(abi.encodePacked(_string));
        uint256 stringLength = bytes(encodedString).length;
        require(stringLength <= PADDED_HEX_STRING_LENGTH, "String too long for 32-byte padding");
        uint256 paddingLength = PADDED_HEX_STRING_LENGTH - stringLength + 2; // +2 for "0x"
        for (uint256 i = 0; i < paddingLength; i++) {
            encodedString = string.concat(encodedString, "0");
        }
        return encodedString;
    }

    /**
     * @notice Converts a string representation of a number (integer or decimal) to a scaled integer.
     * @param s The string to convert (e.g., "-123.45").
     * @param decimals The number of decimal places for scaling.
     * @return result The scaled integer value.
     */
    function stringToScaledInt(string memory s, uint8 decimals) public pure returns (int256 result) {
        bytes memory b = bytes(s);
        int256 sign = 1;
        uint256 start = 0;
        if (b.length > 0 && b[0] == "-") {
            sign = -1;
            start = 1;
        }

        uint256 dotIndex = b.length;
        for (uint256 i = start; i < b.length; i++) {
            if (b[i] == ".") {
                dotIndex = i;
                break;
            }
        }

        uint256 integerPart = 0;
        for (uint256 i = start; i < dotIndex; i++) {
            uint8 digit = uint8(b[i]) - 48;
            require(digit < 10, "Invalid integer part");
            integerPart = integerPart * 10 + digit;
        }

        uint256 fractionalPart = 0;
        uint256 fractionalLen = 0;
        if (dotIndex < b.length - 1) {
            fractionalLen = b.length - 1 - dotIndex;
            for (uint256 i = dotIndex + 1; i < b.length; i++) {
                uint8 digit = uint8(b[i]) - 48;
                require(digit < 10, "Invalid fractional part");
                fractionalPart = fractionalPart * 10 + digit;
            }
        }

        result = int256(integerPart * (10 ** decimals));
        if (fractionalPart > 0) {
            if (fractionalLen > decimals) {
                fractionalPart /= (10 ** (fractionalLen - decimals));
            } else if (fractionalLen < decimals) {
                fractionalPart *= (10 ** (decimals - fractionalLen));
            }
            result += int256(fractionalPart);
        }

        result *= sign;
    }

    /**
     * @notice Converts a string of digits to a uint256.
     * @param s The string containing only digits.
     * @return result The converted unsigned integer.
     */
    function stringToUint(string memory s) internal pure returns (uint256 result) {
        bytes memory b = bytes(s);
        for (uint256 i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            require(c >= 48 && c <= 57, "String contains non-digit characters");
            result = result * 10 + (c - 48);
        }
    }

    /**
     * @notice Converts a scaled integer to a decimal string representation.
     * @param _value The scaled integer value.
     * @param _decimals The number of decimal places used for scaling.
     * @return A string representation of the decimal number.
     */
    function fromInt(int256 _value, uint8 _decimals) public pure returns (string memory) {
        int256 integralPart = _value / int256(10 ** _decimals);
        int256 fractionalPart = _value % int256(10 ** _decimals);
        if (fractionalPart < 0) {
            fractionalPart = -fractionalPart;
        }
        return string.concat(Strings.toStringSigned(integralPart), ".", Strings.toString(uint256(fractionalPart)));
    }

    //-/////////////////////////////////////////////////////////////////////////
    //                              MISC
    //-/////////////////////////////////////////////////////////////////////////

    /**
     * @notice Writes a string to a specified file in a directory.
     * @dev Uses Foundry's `vm.writeFile` or `vm.writeLine`.
     * @param dirPath The path to the directory.
     * @param fileName The name of the file (without extension).
     * @param printString The content to write.
     * @param newFile If true, creates a new file; if false, appends a line.
     */
    function writeToFile(string memory dirPath, string memory fileName, string memory printString, bool newFile)
        internal
    {
        require(vm.isDir(dirPath), string.concat("Manually create the directory: ", dirPath));
        string memory filePath = string.concat(dirPath, fileName, ".txt");
        if (newFile) {
            vm.writeFile(filePath, printString);
        } else {
            vm.writeLine(filePath, printString);
        }
    }
}