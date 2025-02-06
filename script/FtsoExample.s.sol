// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {FtsoExample} from "src/FtsoExample.sol";

// Run with command
//      forge script script/FtsoExample.s.sol:Deploy --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --verify
//      forge script script/FtsoExample.s.sol:Deploy --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --resume --verify --verifier-url https://api.routescan.io/v2/network/testnet/evm/114/etherscan/api

//      forge script script/FtsoExample.s.sol:Deploy --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key "X" --broadcast --verify --verifier-url https://api.routescan.io/v2/network/testnet/evm/114/etherscan/api

contract Deploy is Script {
    FtsoExample ftso;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ftso = new FtsoExample();

        vm.stopBroadcast();
    }
}
