// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {Vm} from "dependencies/forge-std-1.9.5/src/Vm.sol";
import {Surl} from "dependencies/surl-0.0.0/src/Surl.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {ContractRegistry} from "dependencies/flare-periphery-0.0.22/src/coston2/ContractRegistry.sol";
import {IFdcHub} from "dependencies/flare-periphery-0.0.22/src/coston2/IFdcHub.sol";
import {IFlareSystemsManager} from "dependencies/flare-periphery-0.0.22/src/coston2/IFlareSystemsManager.sol";
import {IAddressValidity} from "dependencies/flare-periphery-0.0.22/src/coston2/IAddressValidity.sol";
import {TransferEventListener} from "src/FdcTransferEventListener.sol";
import {Base as StringsBase} from "src/utils/fdcStrings/Base.sol";
import {IFdcRequestFeeConfigurations} from "dependencies/flare-periphery-0.0.22/src/coston2/IFdcRequestFeeConfigurations.sol";

address constant VM_ADDRESS = address(
    uint160(uint256(keccak256("hevm cheat code")))
);
Vm constant vm = Vm(VM_ADDRESS);

library Base {
    using Surl for *;

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

    function prepareAttestationRequest(
        string memory attestationType,
        string memory sourceId,
        string memory requestBody
    ) internal view returns (string[] memory, string memory) {
        // We read the API key from the .env file
        string memory apiKey = vm.envString("VERIFIER_API_KEY");

        // Preparing headers
        string[] memory headers = prepareHeaders(apiKey);
        // Preparing body
        string memory body = prepareBody(
            attestationType,
            sourceId,
            requestBody
        );

        console.log(
            "headers: %s",
            string.concat("{", headers[0], ", ", headers[1]),
            "}\n"
        );
        console.log("body: %s\n", body);
        return (headers, body);
    }

    function prepareProofRequest(
        string memory votingRoundId,
        string memory requestBytes
    ) internal view returns (string[] memory, string memory) {
        string memory apiKey = vm.envString("X_API_KEY");
        string[] memory headers = prepareHeaders(apiKey);
        string memory body = string.concat(
            '{"votingRoundId":',
            votingRoundId,
            ',"requestBytes":"',
            requestBytes,
            '"}'
        );

        console.log(
            "headers: %s",
            string.concat("{", headers[0], ", ", headers[1]),
            "}\n"
        );
        console.log("body: %s\n", body);
        return (headers, body);
    }

    function prepareHeaders(
        string memory apiKey
    ) internal pure returns (string[] memory) {
        string[] memory headers = new string[](2);
        headers[0] = string.concat('"X-API-KEY": ', apiKey);
        headers[1] = '"Content-Type": "application/json"';
        return headers;
    }

    function postAttestationRequest(
        string memory url,
        string[] memory headers,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        (status, data) = url.post(headers, body);
        return (status, data);
    }

    function parseData(bytes memory data) internal pure returns (bytes memory) {
        console.log("raw data: ");
        console.logBytes(data);
        console.log("\n");
        string memory dataJsonString = string(data);
        console.log("data: %s\n", dataJsonString);

        return vm.parseJson(dataJsonString);
    }

    function parseAttestationRequest(
        bytes memory data
    ) internal pure returns (AttestationResponse memory) {
        string memory dataString = string(data);
        console.log("data: %s\n", dataString);
        bytes memory dataJson = vm.parseJson(dataString);

        AttestationResponse memory response = abi.decode(
            dataJson,
            (AttestationResponse)
        );

        console.log("response status: %s\n", response.status);
        console.log("response abiEncodedRequest: ");
        console.logBytes(response.abiEncodedRequest);
        console.log("\n");
        // FIXME what is the point of the following line?
        // bytes memory memoryAbiEncodedRequest = response.abiEncodedRequest;

        return response;
    }

    function submitAttestationRequest(bytes memory abiEncodedRequest) internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IFdcRequestFeeConfigurations fdcRequestFeeConfigurations = ContractRegistry
                .getFdcRequestFeeConfigurations();
        uint256 requestFee = fdcRequestFeeConfigurations.getRequestFee(
            abiEncodedRequest
        );
        console.log("request fee: %s\n", requestFee);
        vm.stopBroadcast();

        vm.startBroadcast(deployerPrivateKey);

        // address fdcHubAddress = 0x48aC463d7975828989331F4De43341627b9c5f1D;
        IFdcHub fdcHub = ContractRegistry.getFdcHub();
        console.log("fcdHub address:");
        console.log(address(fdcHub));
        console.log("\n");

        fdcHub.requestAttestation{value: requestFee * 1 wei}(abiEncodedRequest);
        vm.stopBroadcast();
    }

    function writeToFile(
        string memory dirPath,
        string memory fileName,
        string memory printString,
        bool newFile
    ) internal {
        require(
            vm.isDir(dirPath),
            string.concat("Manually create the directory: ", dirPath)
        );
        string memory filePath = string.concat(dirPath, fileName, ".txt");
        if (newFile) {
            vm.writeFile(filePath, printString);
        } else {
            vm.writeLine(filePath, printString);
        }
    }

    function toUtf8HexString(
        string memory _string
    ) internal pure returns (string memory) {
        string memory encodedString = StringsBase.toHexString(
            abi.encodePacked(_string)
        );
        uint256 stringLength = bytes(encodedString).length;
        require(stringLength <= 64, "String too long");
        uint256 paddingLength = 64 - stringLength + 2;
        for (uint256 i = 0; i < paddingLength; i++) {
            encodedString = string.concat(encodedString, "0");
        }
        return encodedString;
    }

    function prepareBody(
        string memory attestationType,
        string memory sourceId,
        string memory body
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"attestationType": ',
                '"',
                attestationType,
                '"',
                ', "sourceId": ',
                '"',
                sourceId,
                '"',
                ', "requestBody": ',
                body,
                "}"
            );
    }

    function toJsonString(
        ProofRequest memory request
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"roundId": ',
                request.roundId,
                ', "requestBytes": ',
                '"',
                request.requestBytes,
                '"',
                "}"
            );
    }

    function stringToUint(
        string memory s
    ) internal pure returns (uint256 result) {
        bytes memory b = bytes(s);
        uint256 i;
        result = 0;
        for (i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }

    function calculateRoundId() internal returns (uint32) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Calculating roundId
        IFlareSystemsManager flareSystemsManager = ContractRegistry
            .getFlareSystemsManager();

        uint64 firstVodingRoundStartTs = flareSystemsManager
            .firstVotingRoundStartTs();
        uint64 rewardEpochDurationSeconds = flareSystemsManager
            .votingEpochDurationSeconds();

        uint32 roundId = flareSystemsManager.getCurrentVotingEpochId();
        console.log("roundId: %s\n", Strings.toString(roundId));
        vm.stopBroadcast();

        return roundId;
    }
}
