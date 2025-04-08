// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Base} from "./Base.sol";
import {IPayment} from "dependencies/flare-periphery-0.0.22/src/coston2/IPayment.sol";

library FdcStrings {
    function toJsonString(
        IPayment.Request memory request
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
        IPayment.Response memory response
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
        IPayment.Proof memory proof
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
        IPayment.RequestBody memory requestBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"transactionId":"',
                Base.toString(requestBody.transactionId),
                '","inUtxo":',
                Strings.toString(requestBody.inUtxo),
                ',"utxo":',
                Strings.toString(requestBody.utxo),
                "}"
            );
    }

    function toJsonString(
        IPayment.ResponseBody memory responseBody
    ) internal pure returns (string memory) {
        return
            string.concat(
                '{"blockNumber":',
                Strings.toString(responseBody.blockNumber),
                ',"blockTimestamp":',
                Strings.toString(responseBody.blockTimestamp),
                ',"sourceAddressHash":"',
                Base.toString(responseBody.sourceAddressHash),
                '","sourceAddressesRoot":"',
                Base.toString(responseBody.sourceAddressesRoot),
                '","receivingAddressHash":"',
                Base.toString(responseBody.receivingAddressHash),
                '","intendedReceivingAddressHash":"',
                Base.toString(responseBody.intendedReceivingAddressHash),
                '","spentAmount":',
                Strings.toStringSigned(responseBody.spentAmount),
                ',"intendedSpentAmount":',
                Strings.toStringSigned(responseBody.intendedSpentAmount),
                ',"receivedAmount":',
                Strings.toStringSigned(responseBody.receivedAmount),
                ',"intendedReceivedAmount":',
                Strings.toStringSigned(responseBody.intendedReceivedAmount),
                ',"standardPaymentReference":"',
                Base.toString(responseBody.standardPaymentReference),
                '","oneToOne":',
                Base.toString(responseBody.oneToOne),
                ',"status":',
                Strings.toString(responseBody.status),
                "}"
            );
    }
}
