// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {ContractRegistry} from "dependencies/flare-periphery-0.0.22/src/coston2/ContractRegistry.sol";
import {FtsoV2Interface} from "dependencies/flare-periphery-0.0.22/src/coston2/FtsoV2Interface.sol";

//

contract FtsoExample {
    FtsoV2Interface ftso;
    string public message;

    constructor() {
        ftso = ContractRegistry.getFtsoV2();
    }

    function getFeedById() public {
        bytes21 id = 0x01464c522f55534400000000000000000000000000;
        (uint256 value, int8 decimals, uint64 timestamp) = ftso.getFeedById(id);
        // string memory idString = string(id);
        message = string.concat(
            "The value of feed ",
            "0x01464c522f55534400000000000000000000000000",
            " at time ",
            Strings.toString(timestamp),
            " was ",
            Strings.toString(value),
            "e",
            Strings.toStringSigned(decimals)
        );
    }
}
