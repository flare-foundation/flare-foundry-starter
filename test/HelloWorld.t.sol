// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "dependencies/forge-std-1.9.5/src/Test.sol";
import {HelloWorld} from "src/HelloWorld.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";

contract HelloWorldTest is Test {
    HelloWorld helloWorld;

    function setUp() public {
        helloWorld = new HelloWorld("Alderaan");
    }

    function test_Constructor() public view {
        string memory expected1 = "Hello World!";
        string memory greet1 = helloWorld.greet();
        require(
            Strings.equal(greet1, expected1),
            string.concat("Expected: ", expected1, ", got:", greet1)
        );

        string memory expected2 = string.concat(
            "Hello, ",
            helloWorld.world(),
            "!"
        );
        string memory greet2 = helloWorld.greetWorld();
        require(
            Strings.equal(greet2, expected2),
            string.concat("Expected: ", expected2, ", got:", greet2)
        );
    }

    function test_GreetByName() public view {
        string memory name = "Grand Moff Tarkin";
        string memory greet = helloWorld.greetByName(name);
        string memory expected = string.concat("Hello, ", name, "!");
        require(
            Strings.equal(greet, expected),
            string.concat("Expected: ", expected, ", got:", greet)
        );
    }
}
