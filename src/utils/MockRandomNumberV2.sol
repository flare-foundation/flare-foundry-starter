// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {RandomNumberV2Interface} from "dependencies/flare-periphery-0.0.22/src/coston2/RandomNumberV2Interface.sol";

contract MockRandomNumberV2 is RandomNumberV2Interface {
    uint256 private _randomNumber;
    bool private _isSecureRandom;
    uint256 private _randomTimestamp;

    function getRandomNumber()
        public
        view
        returns (
            uint256 randomNumber,
            bool isSecureRandom,
            uint256 randomTimestamp
        )
    {
        return (_randomNumber, _isSecureRandom, _randomTimestamp);
    }

    function getRandomNumberHistorical(
        uint256 votingRoundId
    )
        public
        view
        returns (
            uint256 randomNumber,
            bool isSecureRandom,
            uint256 randomTimestamp
        )
    {
        // Warning suppression
        require(votingRoundId != uint256(0));
        return (_randomNumber, _isSecureRandom, _randomTimestamp);
    }

    function setRandomNumber(uint256 number) public {
        _randomNumber = number;
    }

    function setIsSecureRandom(bool isSecureRandom) public {
        _isSecureRandom = isSecureRandom;
    }

    function setRandomTimestamp(uint256 timestamp) public {
        _randomTimestamp = timestamp;
    }
}
