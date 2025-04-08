// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base} from "./Base.sol";
import {IEVMTransaction} from "dependencies/flare-periphery-0.0.22/src/coston2/IEVMTransaction.sol";

library FdcStrings {
    function toJsonString(
        IEVMTransaction.Request memory request
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"attestationType":"',
                Base.toHexString(request.attestationType),
                '","sourceId":"',
                Base.toHexString(request.sourceId),
                '","messageIntegrityCode":"',
                Base.toString(request.messageIntegrityCode),
                '","requestBody":',
                toJsonString(request.requestBody),
                "}"
            );
    }

    function toJsonString(
        IEVMTransaction.Response memory response
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"attestationType":"',
                Base.toHexString(response.attestationType),
                '","sourceId":"',
                Base.toHexString(response.sourceId),
                '","votingRound":',
                '"',
                Strings.toString(response.votingRound),
                '"',
                ',"lowestUsedTimestamp":',
                '"',
                Strings.toString(response.lowestUsedTimestamp),
                '"',
                ',"requestBody":',
                toJsonString(response.requestBody),
                ',"responseBody":',
                toJsonString(response.responseBody),
                "}"
            );
    }

    function toJsonString(
        IEVMTransaction.Proof memory proof
    ) internal pure returns (string memory) {
        return
            string.concat(
                // FIXME should this be data or response
                '{"response":',
                toJsonString(proof.data),
                // FIXME should this be proof or merkleProof
                ',"proof":',
                Base.toString(proof.merkleProof),
                "}"
            );
    }

    function toJsonString(
        IEVMTransaction.RequestBody memory requestBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"transactionHash":"',
                Base.toString(requestBody.transactionHash),
                '", "requiredConfirmations":',
                '"',
                Strings.toString(requestBody.requiredConfirmations),
                '"',
                ', "provideInput": ',
                Base.toString(requestBody.provideInput),
                ', "listEvents": ',
                Base.toString(requestBody.listEvents),
                ', "logIndices": ',
                Base.toString(requestBody.logIndices),
                "}"
            );
    }

    function toJsonString(
        IEVMTransaction.ResponseBody memory responseBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"blockNumber":',
                '"',
                Strings.toString(responseBody.blockNumber),
                '"',
                ',"timestamp":',
                '"',
                Strings.toString(responseBody.timestamp),
                '"',
                ',"sourceAddress":"',
                Base.toHexString(abi.encodePacked(responseBody.sourceAddress)),
                '","isDeployment":',
                Base.toString(responseBody.isDeployment),
                ',"receivingAddress":"',
                Base.toHexString(
                    abi.encodePacked(responseBody.receivingAddress)
                ),
                '","value":',
                '"',
                Strings.toString(responseBody.value),
                '"',
                ',"input":"',
                Base.toHexString(responseBody.input),
                '","status":',
                '"',
                Strings.toString(responseBody.status),
                '"',
                ',"events":',
                toJsonString(responseBody.events),
                "}"
            );
    }

    function toJsonString(
        IEVMTransaction.Event[] memory events
    ) internal pure returns (string memory) {
        string memory result = "[";
        for (uint i = 0; i < events.length; i++) {
            result = string.concat(result, toJsonString(events[i]));
            if (i < events.length - 1) {
                result = string.concat(result, ",");
            }
        }
        return string.concat(result, "]");
    }

    function toJsonString(
        IEVMTransaction.Event memory _event
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"logIndex":',
                Strings.toString(_event.logIndex),
                ',"emitterAddress":"',
                Base.toHexString(abi.encodePacked(_event.emitterAddress)),
                '","topics":',
                Base.toString(_event.topics),
                // HACK to avoid the error with reading JSON file, where Foundry interprets strings
                // with 0x of length less than 66 as bytes32 instead of bytes
                ',"data":"0x',
                Base.toString(_event.data),
                '","removed":',
                Base.toString(_event.removed),
                "}"
            );
    }
}
