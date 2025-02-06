// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";

library Base {
    function toString(bool _bool) internal pure returns (string memory) {
        return _bool ? "true" : "false";
    }

    function toString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return toHexString(bytesArray);
    }

    function toHexString(bytes32 _bytes32) public pure returns (string memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return toHexString(bytesArray);
    }

    // function toString(bytes32 _bytes32) public pure returns (string memory) {
    //     uint8 i = 0;
    //     while (i < 32 && _bytes32[i] != 0) {
    //         i++;
    //     }
    //     bytes memory bytesArray = new bytes(i);
    //     for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
    //         bytesArray[i] = _bytes32[i];
    //     }
    //     return string(bytesArray);
    // }

    function toString(bytes memory data) public pure returns (string memory) {
        return string(data);
    }

    function toHexString(
        bytes memory data
    ) public pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    function toString(
        uint32[] memory values
    ) internal pure returns (string memory) {
        string memory result = "[";
        for (uint i = 0; i < values.length; i++) {
            result = string.concat(result, Strings.toString(values[i]));
            if (i < values.length - 1) {
                result = string.concat(result, ",");
            }
        }
        return string.concat(result, "]");
    }

    function toString(
        bytes32[] memory values
    ) internal pure returns (string memory) {
        string memory result = '["';
        for (uint i = 0; i < values.length; i++) {
            result = string.concat(result, toHexString(values[i]));
            if (i < values.length - 1) {
                result = string.concat(result, '","');
            }
        }
        return string.concat(result, '"]');
    }
}
