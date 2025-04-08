// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base} from "./Base.sol";
import {IReferencedPaymentNonexistence} from "dependencies/flare-periphery-0.0.22/src/coston2/IReferencedPaymentNonexistence.sol";

library FdcStrings {
    function toJsonString(
        IReferencedPaymentNonexistence.Request memory request
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
        IReferencedPaymentNonexistence.Response memory response
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
        IReferencedPaymentNonexistence.Proof memory proof
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
        IReferencedPaymentNonexistence.RequestBody memory requestBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"minimalBlockNumber":',
                Strings.toString(requestBody.minimalBlockNumber),
                ',"deadlineBlockNumber":',
                Strings.toString(requestBody.deadlineBlockNumber),
                ',"deadlineTimestamp":',
                Strings.toString(requestBody.deadlineTimestamp),
                ',"destinationAddressHash":"',
                Base.toString(requestBody.destinationAddressHash),
                '","amount":"',
                Strings.toString(requestBody.amount),
                '","standardPaymentReference":"',
                Base.toString(requestBody.standardPaymentReference),
                '","checkSourceAddresses":',
                Base.toString(requestBody.checkSourceAddresses),
                ',"sourceAddressesRoot":"',
                Base.toString(requestBody.sourceAddressesRoot),
                '"}'
            );
    }

    function toJsonString(
        IReferencedPaymentNonexistence.ResponseBody memory responseBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"minimalBlockTimestamp":',
                Strings.toString(responseBody.minimalBlockTimestamp),
                ',"firstOverflowBlockNumber":',
                Strings.toString(responseBody.firstOverflowBlockNumber),
                ',"firstOverflowBlockTimestamp":',
                Strings.toString(responseBody.firstOverflowBlockTimestamp),
                "}"
            );
    }
}
