// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";
import {IFdcVerification} from "flare-periphery/src/coston2/IFdcVerification.sol";
import {FdcStrings} from "src/utils/fdcStrings/Payment.sol";
import {IPayment} from "flare-periphery/src/coston2/IPayment.sol";

struct Payment {
    uint64 blockNumber;
    uint64 blockTimestamp;
    bytes32 sourceAddressHash;
    bytes32 receivingAddressHash;
    int256 spentAmount;
    bytes32 standardPaymentReference;
    uint8 status;
}

interface IPaymentRegistry {
    function registerPayment(IPayment.Proof calldata _transaction) external;
}

contract PaymentRegistry is IPaymentRegistry {
    Payment[] public verifiedPayments;

    function isPaymentProofValid(
        IPayment.Proof calldata transaction
    ) public view returns (bool) {
        // Use the library to get the verifier contract and verify that this transaction was proved by state connector
        IFdcVerification fdc = ContractRegistry.getFdcVerification();
        console.log("transaction: %s\n", FdcStrings.toJsonString(transaction));
        // return true;
        return fdc.verifyPayment(transaction);
    }

    function registerPayment(IPayment.Proof calldata _transaction) external {
        // 1. FDC Logic
        // Check that this Payment has indeed been confirmed by the FDC
        require(isPaymentProofValid(_transaction), "Invalid transaction proof");

        // 2. Business logic
        Payment memory provedPayment = Payment(
            _transaction.data.responseBody.blockNumber,
            _transaction.data.responseBody.blockTimestamp,
            _transaction.data.responseBody.sourceAddressHash,
            _transaction.data.responseBody.receivingAddressHash,
            _transaction.data.responseBody.spentAmount,
            _transaction.data.responseBody.standardPaymentReference,
            _transaction.data.responseBody.status
        );

        verifiedPayments.push(provedPayment);
    }
}
