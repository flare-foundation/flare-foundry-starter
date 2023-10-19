// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

contract Mock {
    fallback() external payable {
        revert("Mock should have a mocked method");
    }
}
