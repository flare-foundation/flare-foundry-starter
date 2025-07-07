// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {console} from "dependencies/forge-std-1.9.5/src/console.sol";

import { AssetManagerRegistry } from "../../src/fassets/AssetManagerRegistry.sol";

// Run with command
// forge script script/fassets/AssetManagerRegistry.s.sol:Deploy --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the FAssetsSettings contract
        AssetManagerRegistry assetManagerRegistry = new AssetManagerRegistry();
        console.log("AssetManagerRegistry deployed at:", address(assetManagerRegistry));

        // Get asset manager address
        (address assetManagerAddress) = assetManagerRegistry.getFxrpAssetManager();
        console.log("Asset manager address", assetManagerAddress);

        vm.stopBroadcast();
    }
}

