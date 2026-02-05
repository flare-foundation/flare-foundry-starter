// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { IFirelightVault } from "../../src/firelight/IFirelightVault.sol";
import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * FirelightVault Withdraw Script
 *
 * This script creates a withdrawal request from the FirelightVault (ERC-4626).
 * Withdrawals are delayed and must be claimed after the period ends.
 *
 * Usage:
 *   forge script script/firelight/Withdraw.s.sol:Withdraw --rpc-url $COSTON2_RPC_URL --broadcast
 */
contract Withdraw is Script {
    address public constant FIRELIGHT_VAULT_ADDRESS = 0x91Bfe6A68aB035DFebb6A770FFfB748C03C0E40B;
    uint256 public constant TOKENS_TO_WITHDRAW = 1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address account = vm.addr(deployerPrivateKey);

        IFirelightVault vault = IFirelightVault(FIRELIGHT_VAULT_ADDRESS);

        // Get asset info
        address assetAddress = vault.asset();
        IERC20Metadata assetMetadata = IERC20Metadata(assetAddress);
        string memory symbol = assetMetadata.symbol();
        uint8 assetDecimals = assetMetadata.decimals();

        // Calculate withdraw amount
        uint256 withdrawAmount = TOKENS_TO_WITHDRAW * (10 ** assetDecimals);

        // Log withdraw info
        logWithdrawInfo(account, assetAddress, symbol, assetDecimals, withdrawAmount);

        // Validate withdraw
        uint256 maxWithdraw = vault.maxWithdraw(account);
        console.log("Max withdraw:", maxWithdraw);
        require(withdrawAmount <= maxWithdraw, "Withdraw amount exceeds max allowed");

        // Check user balance and shares needed
        uint256 userBalance = vault.balanceOf(account);
        console.log("User balance (shares):", userBalance);

        uint256 sharesNeeded = vault.previewWithdraw(withdrawAmount);
        console.log("Shares needed for withdrawal:", sharesNeeded);
        require(userBalance >= sharesNeeded, "Insufficient shares for withdrawal");

        // Execute transaction
        vm.startBroadcast(deployerPrivateKey);

        uint256 shares = vault.withdraw(withdrawAmount, account, account);
        console.log("Withdraw request successful!");
        console.log("Shares burned:", shares);
        console.log("Note: Withdrawal is delayed. Claim after period ends using ClaimWithdraw script.");

        vm.stopBroadcast();
    }

    function logWithdrawInfo(
        address account,
        address assetAddress,
        string memory symbol,
        uint8 assetDecimals,
        uint256 withdrawAmount
    ) internal pure {
        console.log("=== Withdraw (ERC-4626) ===");
        console.log("Sender:", account);
        console.log("Vault:", FIRELIGHT_VAULT_ADDRESS);
        console.log("Asset:", assetAddress);
        console.log("Asset symbol:", symbol);
        console.log("Asset decimals:", uint256(assetDecimals));
        console.log("Withdraw amount (raw):", withdrawAmount);
        console.log("Withdraw amount (tokens):", TOKENS_TO_WITHDRAW);
    }
}
