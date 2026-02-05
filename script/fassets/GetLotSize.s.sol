// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { AssetManagerSettings } from "flare-periphery/src/coston2/data/AssetManagerSettings.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/fassets/GetLotSize.s.sol:GetLotSize --rpc-url $COSTON2_RPC_URL

contract GetLotSize is Script {
    function run() external view {
        // Get FAssets FXRP asset manager on Coston2 network
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();

        // Get the settings
        AssetManagerSettings.Data memory settings = assetManager.getSettings();

        // Extract lot size info
        uint64 lotSizeAMG = settings.lotSizeAMG;
        uint8 assetDecimals = settings.assetDecimals;

        // Calculate lot size in human-readable format
        // lotSizeAMG is in Asset Minting Granularity units
        // To convert to actual token amount: lotSizeAMG * 10^(assetDecimals - AMG_DECIMALS)
        // AMG typically uses the same decimals as the asset for FXRP

        console.log("=== FXRP Lot Size Info ===");
        console.log("Lot Size (AMG):", lotSizeAMG);
        console.log("Asset Decimals:", assetDecimals);

        // For FXRP: 1 lot = 10 XRP (lotSizeAMG = 10 * 10^6 = 10,000,000 for 6 decimals)
        uint256 lotSizeInTokens = uint256(lotSizeAMG);
        console.log("Lot Size (smallest units):", lotSizeInTokens);

        // Calculate human-readable lot size
        if (assetDecimals > 0) {
            uint256 divisor = 10 ** assetDecimals;
            uint256 wholePart = lotSizeInTokens / divisor;
            console.log("Lot Size (whole tokens):", wholePart);
        }
    }
}
