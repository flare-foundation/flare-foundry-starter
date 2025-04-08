// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base} from "./Base.sol";
import {IAddressValidity} from "dependencies/flare-periphery-0.0.22/src/coston2/IAddressValidity.sol";

library FdcStrings {
    function toJsonString(
        IAddressValidity.Request memory request
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
        IAddressValidity.Response memory response
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
        IAddressValidity.Proof memory proof
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
        IAddressValidity.RequestBody memory requestBody
    ) internal pure returns (string memory) {
        return string.concat('{"addressStr":"', requestBody.addressStr, '"}');
    }

    function toJsonString(
        IAddressValidity.ResponseBody memory responseBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"isValid":',
                Base.toString(responseBody.isValid),
                ',"standardAddress":"',
                responseBody.standardAddress,
                '","standardAddressHash":"',
                Base.toString(responseBody.standardAddressHash),
                '"}'
            );
    }
}
