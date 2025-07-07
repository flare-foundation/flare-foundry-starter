// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import { FAssetsSettings } from "../../src/fassets/FAssetsSettings.sol";

// Run with command
// forge script script/fassets/FAssetsSettings.s.sol:Deploy --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL

contract Deploy is Script {
    // Address of the AssetManager contract on Flare Testnet Coston2
    address constant ASSET_MANAGER = address(0xDeD50DA9C3492Bee44560a4B35cFe0e778F41eC5);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the FAssetsSettings contract
        FAssetsSettings fAssetsSettings = new FAssetsSettings(ASSET_MANAGER);
        console.log("FAssetsSettings deployed at:", address(fAssetsSettings));

        // Get lot size and decimals
        (uint64 lotSizeAMG, uint8 assetDecimals) = fAssetsSettings.getLotSize();
        console.log("Lot Size (AMG):", lotSizeAMG);
        console.log("Asset Decimals:", assetDecimals);

        vm.stopBroadcast();
    }
}

