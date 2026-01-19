// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";
import { IFirelightVault } from "../../src/firelight/IFirelightVault.sol";
import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * FirelightVault Redeem Script
 *
 * This script creates a redemption request from the FirelightVault (ERC-4626).
 * Redeem burns shares to withdraw assets. Redemptions are delayed and must be claimed after the period ends.
 *
 * Usage:
 *   forge script script/firelight/Redeem.s.sol:Redeem --rpc-url $COSTON2_RPC_URL --broadcast
 *
 * Environment variables:
 *   PRIVATE_KEY - Required: Private key for signing transactions
 */
contract Redeem is Script {
    address public constant FIRELIGHT_VAULT_ADDRESS = 0x91Bfe6A68aB035DFebb6A770FFfB748C03C0E40B;
    uint256 public constant SHARES_TO_REDEEM = 1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address account = vm.addr(deployerPrivateKey);

        IFirelightVault vault = IFirelightVault(FIRELIGHT_VAULT_ADDRESS);

        // Get asset info
        address assetAddress = vault.asset();
        IERC20Metadata assetMetadata = IERC20Metadata(assetAddress);
        string memory symbol = assetMetadata.symbol();
        uint8 assetDecimals = assetMetadata.decimals();

        // Calculate shares amount
        uint256 sharesAmount = SHARES_TO_REDEEM * (10 ** assetDecimals);

        // Log redeem info
        logRedeemInfo(account, assetAddress, symbol, assetDecimals, sharesAmount);

        // Validate redeem
        uint256 maxRedeem = vault.maxRedeem(account);
        console.log("Max redeem:", maxRedeem);
        require(sharesAmount <= maxRedeem, "Shares amount exceeds max allowed");

        // Check user balance
        uint256 userBalance = vault.balanceOf(account);
        console.log("User balance (shares):", userBalance);
        require(userBalance >= sharesAmount, "Insufficient shares for redemption");

        // Preview assets to receive
        uint256 assetsToReceive = vault.previewRedeem(sharesAmount);
        console.log("Assets to receive (preview):", assetsToReceive);

        // Execute transaction
        vm.startBroadcast(deployerPrivateKey);

        uint256 assets = vault.redeem(sharesAmount, account, account);
        console.log("Redeem request successful!");
        console.log("Assets to be withdrawn:", assets);
        console.log("Note: Redemption is delayed. Claim after period ends using ClaimWithdraw script.");

        vm.stopBroadcast();
    }

    function logRedeemInfo(
        address account,
        address assetAddress,
        string memory symbol,
        uint8 assetDecimals,
        uint256 sharesAmount
    ) internal pure {
        console.log("=== Redeem (ERC-4626) ===");
        console.log("Sender:", account);
        console.log("Vault:", FIRELIGHT_VAULT_ADDRESS);
        console.log("Asset:", assetAddress);
        console.log("Asset symbol:", symbol);
        console.log("Asset decimals:", uint256(assetDecimals));
        console.log("Shares to redeem (raw):", sharesAmount);
        console.log("Shares to redeem:", SHARES_TO_REDEEM);
    }
}
