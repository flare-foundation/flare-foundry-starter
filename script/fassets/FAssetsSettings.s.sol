// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import { FAssetsSettings } from "../../src/fassets/FAssetsSettings.sol";

contract DeployAngGetFAssetsSettings is Script {
    // Address of the AssetManager contract on Songbird Testnet Coston
    address constant ASSET_MANAGER = address(0x56728e46908fB6FcC5BCD2cc0c0F9BB91C3e4D34);

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

