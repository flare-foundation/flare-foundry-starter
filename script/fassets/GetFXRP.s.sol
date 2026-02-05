// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/fassets/GetFXRP.s.sol:GetFXRP --rpc-url $COSTON2_RPC_URL
contract GetFXRP is Script {
    function run() external view {
        // Get FAssets FXRP asset manager on Coston2 network
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();

        // Get the fAsset (FXRP) token address
        address fxrpAddress = address(assetManager.fAsset());

        // Get token metadata
        IERC20Metadata fxrp = IERC20Metadata(fxrpAddress);
        string memory name = fxrp.name();
        string memory symbol = fxrp.symbol();
        uint8 decimals = fxrp.decimals();

        console.log("=== FXRP Token Info ===");
        console.log("Address:", fxrpAddress);
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Decimals:", decimals);
    }
}
