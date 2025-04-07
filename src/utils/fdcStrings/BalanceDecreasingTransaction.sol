// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base} from "./Base.sol";
import {IBalanceDecreasingTransaction} from "dependencies/flare-periphery-0.0.22/src/coston2/IBalanceDecreasingTransaction.sol";

library FdcStrings {
    function toJsonString(
        IBalanceDecreasingTransaction.Request memory request
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
        IBalanceDecreasingTransaction.Response memory response
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
        IBalanceDecreasingTransaction.Proof memory proof
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
        IBalanceDecreasingTransaction.RequestBody memory requestBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"transactionId":"',
                Base.toString(requestBody.transactionId),
                '","sourceAddressIndicator":"',
                Base.toString(requestBody.sourceAddressIndicator),
                '"}'
            );
    }

    function toJsonString(
        IBalanceDecreasingTransaction.ResponseBody memory responseBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"blockNumber":',
                Strings.toString(responseBody.blockNumber),
                ',"blockTimestamp":',
                Strings.toString(responseBody.blockTimestamp),
                ',"sourceAddressHash":"',
                Base.toString(responseBody.sourceAddressHash),
                '","spentAmount":',
                Strings.toStringSigned(responseBody.spentAmount),
                ',"standardPaymentReference":"',
                Base.toString(responseBody.standardPaymentReference),
                '"}'
            );
    }
}
