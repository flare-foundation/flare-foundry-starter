// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { HelloWorld } from "src/HelloWorld.sol";

// Run with command
// solhint-disable-next-line max-line-length
//      forge script script/HelloWorld.s.sol:Deploy "Coruscant" --sig "run(string)" --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --verify --verifier blockscout --verifier-url $COSTON2_EXPLORER_API

contract Deploy is Script {
    HelloWorld public helloWorld;

    function run(string calldata _name) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        helloWorld = new HelloWorld(_name);

        vm.stopBroadcast();
    }
}
