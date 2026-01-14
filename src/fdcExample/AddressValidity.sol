// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin-contracts/utils/Strings.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { IFdcVerification } from "flare-periphery/src/coston2/IFdcVerification.sol";
import { IAddressValidity } from "flare-periphery/src/coston2/IAddressValidity.sol";

interface IAddressRegistry {
    function registerAddress(string calldata _addressStr, IAddressValidity.Proof calldata _transaction) external;
}

contract AddressRegistry is IAddressRegistry {
    string[] public verifiedAddresses;

    function registerAddress(string calldata _addressStr, IAddressValidity.Proof calldata _transaction) external {
        // 1. FDC Logic
        // Check that this AddressValidity has indeed been confirmed by the FDC
        require(isAddressValidityProofValid(_transaction), "Invalid transaction proof");

        // 2. Business logic
        string memory provedAddress = _transaction.data.requestBody.addressStr;
        require(
            Strings.equal(provedAddress, _addressStr),
            string.concat("Invalid address.\n\tProvided: ", _addressStr, "\n\tProved: ", provedAddress)
        );
        verifiedAddresses.push(provedAddress);
    }

    function isAddressValidityProofValid(IAddressValidity.Proof calldata transaction) public view returns (bool) {
        // Use the library to get the verifier contract and verify that this transaction was proved by FDC
        IFdcVerification fdc = ContractRegistry.getFdcVerification();

        // return true;
        return fdc.verifyAddressValidity(transaction);
    }
}
