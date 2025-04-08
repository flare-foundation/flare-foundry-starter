// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "dependencies/forge-std-1.9.5/src/Test.sol";
import {GuessingGame} from "src/GuessingGame.sol";
import {ContractRegistry} from "dependencies/flare-periphery-0.0.22/src/coston2/ContractRegistry.sol";

import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {MockRandomNumberV2} from "src/utils/MockRandomNumberV2.sol";

contract TestGuessingGame is Test {
    GuessingGame game;
    MockRandomNumberV2 mockRandom;
    uint16 _secretNumber;
    uint256 _maxNumber;

    function setUp() public {
        _secretNumber = 42;
        _maxNumber = 100;
        mockRandom = new MockRandomNumberV2();
        vm.mockCall(
            ContractRegistry.FLARE_CONTRACT_REGISTRY_ADDRESS,
            abi.encodeWithSelector(
                ContractRegistry
                    .FLARE_CONTRACT_REGISTRY
                    .getContractAddressByHash
                    .selector,
                keccak256(abi.encode("RandomNumberV2"))
            ),
            abi.encode(address(mockRandom))
        );
        mockRandom.setRandomNumber(_secretNumber);
    }

    function test_RevertWhen_MaxNumberTooBig() public {
        vm.expectRevert("Only numbers smaller than 65535 allowed");
        game = new GuessingGame(1000000);
    }

    function testFuzz_guess(uint16 number) public {
        vm.assume(number <= 111);

        game = new GuessingGame(_maxNumber);
        string memory got = game.guess(number);
        string memory expected;
        if (number > _maxNumber) {
            expected = string.concat(
                "Numbers go only up to ",
                Strings.toString(_maxNumber)
            );
        } else if (number > _secretNumber) {
            expected = "Too big";
        } else if (number < _secretNumber) {
            expected = "Too small";
        } else if (number == _secretNumber) {
            expected = "CORRECT!";
        } else {
            expected = "IMPOSSIBLE!";
        }
        require(
            Strings.equal(got, expected),
            string.concat("Expected: ", expected, ", got:", got)
        );
    }

    function test_resetGame() public {
        game = new GuessingGame(_maxNumber);
        uint16 _newSecretNumber = 69;

        string memory expected1 = "CORRECT!";
        string memory got1 = game.guess(_secretNumber);

        require(
            Strings.equal(got1, expected1),
            string.concat("Expected: ", expected1, ", got:", got1)
        );

        mockRandom.setRandomNumber(_newSecretNumber);
        game.resetGame();

        string memory expected2 = "CORRECT!";
        string memory got2 = game.guess(_newSecretNumber);
        require(
            Strings.equal(got2, expected2),
            string.concat("Expected: ", expected2, ", got:", got2)
        );
    }
}
