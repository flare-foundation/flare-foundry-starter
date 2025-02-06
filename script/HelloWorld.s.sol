// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {HelloWorld} from "src/HelloWorld.sol";

// Run with command
//      forge script script/HelloWorld.s.sol:Deploy "Coruscant" --sig "run(string)" --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --verify

contract Deploy is Script {
    HelloWorld helloWorld;

    function run(string calldata _name) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        helloWorld = new HelloWorld(_name);

        vm.stopBroadcast();
    }
}
