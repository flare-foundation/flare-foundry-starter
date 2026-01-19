// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";
import { IFirelightVault } from "../../src/firelight/IFirelightVault.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * FirelightVault Deposit Script
 *
 * This script deposits assets into the FirelightVault (ERC-4626).
 * It approves tokens and deposits the specified amount, receiving vault shares in return.
 *
 * Usage:
 *   forge script script/firelight/Deposit.s.sol:Deposit --rpc-url $COSTON2_RPC_URL --broadcast
 *
 * Environment variables:
 *   PRIVATE_KEY - Required: Private key for signing transactions
 */
contract Deposit is Script {
    address public constant FIRELIGHT_VAULT_ADDRESS = 0x91Bfe6A68aB035DFebb6A770FFfB748C03C0E40B;
    uint256 public constant TOKENS_TO_DEPOSIT = 1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address account = vm.addr(deployerPrivateKey);

        IFirelightVault vault = IFirelightVault(FIRELIGHT_VAULT_ADDRESS);

        // Get asset info
        address assetAddress = vault.asset();
        IERC20 assetToken = IERC20(assetAddress);
        IERC20Metadata assetMetadata = IERC20Metadata(assetAddress);
        string memory symbol = assetMetadata.symbol();
        uint8 assetDecimals = assetMetadata.decimals();

        // Calculate deposit amount
        uint256 depositAmount = TOKENS_TO_DEPOSIT * (10 ** assetDecimals);

        // Log deposit info
        logDepositInfo(account, assetAddress, symbol, assetDecimals, depositAmount);

        // Validate deposit
        uint256 maxDeposit = vault.maxDeposit(account);
        console.log("Max deposit:", maxDeposit);
        require(depositAmount <= maxDeposit, "Deposit amount exceeds max allowed");

        // Check balance
        uint256 balance = assetToken.balanceOf(account);
        console.log("Account balance:", balance);
        require(balance >= depositAmount, "Insufficient balance");

        // Execute transactions
        vm.startBroadcast(deployerPrivateKey);

        // Approve tokens
        assetToken.approve(FIRELIGHT_VAULT_ADDRESS, depositAmount);
        console.log("Approved tokens for vault");

        // Deposit
        uint256 shares = vault.deposit(depositAmount, account);
        console.log("Deposit successful!");
        console.log("Shares received:", shares);

        vm.stopBroadcast();
    }

    function logDepositInfo(
        address account,
        address assetAddress,
        string memory symbol,
        uint8 assetDecimals,
        uint256 amount
    ) internal pure {
        console.log("=== Deposit (ERC-4626) ===");
        console.log("Sender:", account);
        console.log("Vault:", FIRELIGHT_VAULT_ADDRESS);
        console.log("Asset:", assetAddress);
        console.log("Asset symbol:", symbol);
        console.log("Asset decimals:", uint256(assetDecimals));
        console.log("Deposit amount (raw):", amount);
        console.log("Deposit amount (tokens):", TOKENS_TO_DEPOSIT);
    }
}
