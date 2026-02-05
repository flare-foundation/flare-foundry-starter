// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { IFirelightVault } from "../../src/firelight/IFirelightVault.sol";
import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * FirelightVault Status Script
 *
 * This script displays information about a FirelightVault contract.
 * It shows vault metrics, period configuration, user balances, and withdrawal information.
 *
 * Usage:
 *   forge script script/firelight/Status.s.sol:Status --rpc-url $COSTON2_RPC_URL
 */
contract Status is Script {
    address public constant FIRELIGHT_VAULT_ADDRESS = 0x91Bfe6A68aB035DFebb6A770FFfB748C03C0E40B;

    function run() external view {
        IFirelightVault vault = IFirelightVault(FIRELIGHT_VAULT_ADDRESS);

        // Get vault info
        address asset = vault.asset();
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 currentPeriod = vault.currentPeriod();
        uint48 currentPeriodStart = vault.currentPeriodStart();
        uint48 currentPeriodEnd = vault.currentPeriodEnd();
        uint48 nextPeriodEnd = vault.nextPeriodEnd();
        uint256 pcLen = vault.periodConfigurationsLength();
        IFirelightVault.PeriodConfiguration memory currentPeriodConfig = vault.currentPeriodConfiguration();

        // Get asset info
        IERC20Metadata assetToken = IERC20Metadata(asset);
        string memory assetSymbol = assetToken.symbol();
        uint8 assetDecimals = assetToken.decimals();

        // Log asset information
        logAssetInfo(asset, assetSymbol, assetDecimals);

        // Log vault balances
        logVaultBalances(totalAssets, totalSupply, assetSymbol, assetDecimals);

        // Log period configuration
        logPeriodConfiguration(
            pcLen,
            currentPeriod,
            currentPeriodStart,
            currentPeriodEnd,
            nextPeriodEnd,
            currentPeriodConfig
        );

        // Get user info from env if available
        address account = vm.envOr("ACCOUNT", address(0));
        if (account != address(0)) {
            logUserInfo(vault, account, assetSymbol, assetDecimals);
            logUserWithdrawals(vault, account, currentPeriod, assetSymbol, assetDecimals);
        } else {
            console.log("\n=== User Info ===");
            console.log("Set ACCOUNT env var to display user-specific info");
        }
    }

    // internal view functions
    function logUserInfo(
        IFirelightVault vault,
        address account,
        string memory assetSymbol,
        uint8 assetDecimals
    ) internal view {
        console.log("\n=== User Info ===");
        console.log("Account:", account);

        uint256 userBalance = vault.balanceOf(account);
        uint256 userBalanceAssets = vault.convertToAssets(userBalance);
        uint256 userMaxDeposit = vault.maxDeposit(account);
        uint256 userMaxMint = vault.maxMint(account);
        uint256 userMaxWithdraw = vault.maxWithdraw(account);
        uint256 userMaxRedeem = vault.maxRedeem(account);

        console.log("User balance (shares):", userBalance);
        console.log("  Formatted:", formatDecimals(userBalance, assetDecimals), "shares");
        console.log("User balance (assets):", userBalanceAssets);
        console.log("  Formatted:", formatDecimals(userBalanceAssets, assetDecimals), assetSymbol);
        console.log("Max deposit:", userMaxDeposit);
        console.log("Max mint:", userMaxMint);
        console.log("Max withdraw:", userMaxWithdraw);
        console.log("Max redeem:", userMaxRedeem);
    }

    function logUserWithdrawals(
        IFirelightVault vault,
        address account,
        uint256 currentPeriod,
        string memory assetSymbol,
        uint8 assetDecimals
    ) internal view {
        console.log("\n=== User Withdrawals ===");

        // Check current period
        uint256 withdrawals = vault.withdrawalsOf(currentPeriod, account);
        if (withdrawals != 0) {
            console.log("Period", currentPeriod, ":", withdrawals);
            console.log("  Formatted:", formatDecimals(withdrawals, assetDecimals), assetSymbol);
        }

        // Check previous period if exists
        if (currentPeriod > 0) {
            uint256 prevWithdrawals = vault.withdrawalsOf(currentPeriod - 1, account);
            if (prevWithdrawals != 0) {
                console.log("Period", currentPeriod - 1, ":", prevWithdrawals);
                console.log("  Formatted:", formatDecimals(prevWithdrawals, assetDecimals), assetSymbol);
            }
        }
    }

    // internal pure functions
    function logAssetInfo(address asset, string memory assetSymbol, uint8 assetDecimals) internal pure {
        console.log("\n=== Asset ===");
        console.log("Asset address:", asset);
        console.log("Asset symbol:", assetSymbol);
        console.log("Asset decimals:", uint256(assetDecimals));
    }

    function logVaultBalances(
        uint256 totalAssets,
        uint256 totalSupply,
        string memory assetSymbol,
        uint8 assetDecimals
    ) internal pure {
        console.log("\n=== Vault Balances ===");
        console.log("Total assets (excl. pending withdrawals):", totalAssets);
        console.log("  Formatted:", formatDecimals(totalAssets, assetDecimals), assetSymbol);
        console.log("Total supply (shares):", totalSupply);
        console.log("  Formatted:", formatDecimals(totalSupply, assetDecimals), "shares");

        // Calculate exchange rate (assets per share)
        if (totalSupply != 0) {
            uint256 precision = 10 ** assetDecimals;
            uint256 rate = (totalAssets * precision) / totalSupply;
            console.log("Exchange rate:", formatDecimals(rate, assetDecimals), string.concat(assetSymbol, "/share"));
        } else {
            console.log("Exchange rate: N/A (no shares minted)");
        }
    }

    function logPeriodConfiguration(
        uint256 pcLen,
        uint256 currentPeriod,
        uint48 currentPeriodStart,
        uint48 currentPeriodEnd,
        uint48 nextPeriodEnd,
        IFirelightVault.PeriodConfiguration memory currentPeriodConfig
    ) internal pure {
        console.log("\n=== Period Configuration ===");
        console.log("Period configurations count:", pcLen);
        console.log("Current period:", currentPeriod);
        console.log("Current period start:", formatTimestamp(currentPeriodStart));
        console.log("Current period end:", formatTimestamp(currentPeriodEnd));
        console.log("Next period end:", formatTimestamp(nextPeriodEnd));
        console.log("Current period config:");
        console.log("  epoch:", uint256(currentPeriodConfig.epoch));
        console.log("  duration:", uint256(currentPeriodConfig.duration));
        console.log("  startingPeriod:", currentPeriodConfig.startingPeriod);
    }

    function formatTimestamp(uint48 timestamp) internal pure returns (string memory) {
        return string.concat(vm.toString(uint256(timestamp)), " (", vm.toString(uint256(timestamp)), " unix)");
    }

    function formatDecimals(uint256 value, uint8 decimals) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 divisor = 10 ** decimals;
        uint256 integerPart = value / divisor;
        uint256 fractionalPart = value % divisor;

        if (fractionalPart == 0) {
            return vm.toString(integerPart);
        }

        // Build fractional string with leading zeros
        string memory fractionalStr = vm.toString(fractionalPart);
        uint256 fractionalLen = bytes(fractionalStr).length;

        // Pad with leading zeros if needed
        string memory padding = "";
        for (uint256 i = fractionalLen; i < decimals; i++) {
            padding = string.concat(padding, "0");
        }

        // Trim trailing zeros
        bytes memory fractionalBytes = bytes(string.concat(padding, fractionalStr));
        uint256 lastNonZero = fractionalBytes.length;
        for (uint256 i = fractionalBytes.length; i > 0; i--) {
            if (fractionalBytes[i - 1] != "0") {
                lastNonZero = i;
                break;
            }
        }

        bytes memory trimmed = new bytes(lastNonZero);
        for (uint256 i = 0; i < lastNonZero; i++) {
            trimmed[i] = fractionalBytes[i];
        }

        return string.concat(vm.toString(integerPart), ".", string(trimmed));
    }
}
