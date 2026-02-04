// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// solhint-disable max-line-length
import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { FtsoExample } from "src/FtsoExample.sol";

// Run with command
//      forge script script/FtsoExample.s.sol:Deploy --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --verify --verifier blockscout --verifier-url $COSTON2_EXPLORER_API
//      forge script script/FtsoExample.s.sol:Deploy --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --resume --verify --verifier blockscout --verifier-url $COSTON2_EXPLORER_API

contract Deploy is Script {
    FtsoExample public ftso;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ftso = new FtsoExample();

        vm.stopBroadcast();
    }
}
