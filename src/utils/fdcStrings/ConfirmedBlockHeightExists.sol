// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base} from "./Base.sol";
import {IConfirmedBlockHeightExists} from "dependencies/flare-periphery-0.0.22/src/coston2/IConfirmedBlockHeightExists.sol";

library FdcStrings {
    function toJsonString(
        IConfirmedBlockHeightExists.Request memory request
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"attestationType":"',
                Base.toString(request.attestationType),
                '","sourceId":"',
                Base.toString(request.sourceId),
                '","messageIntegrityCode":"',
                Base.toString(request.messageIntegrityCode),
                '","requestBody":',
                toJsonString(request.requestBody),
                "}"
            );
    }

    function toJsonString(
        IConfirmedBlockHeightExists.Response memory response
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"attestationType":"',
                Base.toString(response.attestationType),
                '","sourceId":"',
                Base.toString(response.sourceId),
                '","votingRound":',
                Strings.toString(response.votingRound),
                ',"lowestUsedTimestamp":',
                Strings.toString(response.lowestUsedTimestamp),
                ',"requestBody":',
                toJsonString(response.requestBody),
                ',"responseBody":',
                toJsonString(response.responseBody),
                "}"
            );
    }

    function toJsonString(
        IConfirmedBlockHeightExists.Proof memory proof
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"merkleProof":',
                Base.toString(proof.merkleProof),
                ',"data":',
                toJsonString(proof.data),
                "}"
            );
    }

    function toJsonString(
        IConfirmedBlockHeightExists.RequestBody memory requestBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"blockNumber":',
                Strings.toString(requestBody.blockNumber),
                ',"queryWindow":',
                Strings.toString(requestBody.queryWindow),
                "}"
            );
    }

    function toJsonString(
        IConfirmedBlockHeightExists.ResponseBody memory responseBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"blockTimestamp":',
                Strings.toString(responseBody.blockTimestamp),
                ',"numberOfConfirmations":',
                Strings.toString(responseBody.numberOfConfirmations),
                ',"lowestQueryWindowBlockNumber":',
                Strings.toString(responseBody.lowestQueryWindowBlockNumber),
                ',"lowestQueryWindowBlockTimestamp":',
                Strings.toString(responseBody.lowestQueryWindowBlockTimestamp),
                "}"
            );
    }
}
