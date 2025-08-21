// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";

import {IAssetManager} from "flare-periphery/src/coston2/IAssetManager.sol";

// Contract for accessing FAssets settings from the asset manager
contract FAssetsSettings {
    // This function gets two important numbers from the asset manager settings:
    // * lotSizeAMG: The smallest amount you can trade (in AMG units)
    // * assetDecimals: How many decimal places the asset uses
    // FAssets Operation Parameters https://dev.flare.network/fassets/operational-parameters
    function getLotSize()
        public
        view
        returns (uint64 lotSizeAMG, uint8 assetDecimals)
    {
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();
        lotSizeAMG = assetManager.getSettings().lotSizeAMG;
        assetDecimals = assetManager.getSettings().assetDecimals;

        return (lotSizeAMG, assetDecimals);
    }
}
