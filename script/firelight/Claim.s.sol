// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";
import { IFirelightVault } from "../../src/firelight/IFirelightVault.sol";
import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * FirelightVault Claim Script
 *
 * This script claims pending withdrawals from the FirelightVault.
 * Withdrawals must be requested first using withdraw/redeem, then claimed after the period ends.
 *
 * Usage:
 *   forge script script/firelight/Claim.s.sol:Claim --rpc-url $COSTON2_RPC_URL --broadcast
 */
contract Claim is Script {
    address public constant FIRELIGHT_VAULT_ADDRESS = 0x91Bfe6A68aB035DFebb6A770FFfB748C03C0E40B;

    // Period to claim (0 means auto-detect all claimable periods)
    uint256 public constant PERIOD_TO_CLAIM = 0;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address account = vm.addr(deployerPrivateKey);

        IFirelightVault vault = IFirelightVault(FIRELIGHT_VAULT_ADDRESS);

        // Get asset info
        address assetAddress = vault.asset();
        IERC20Metadata assetMetadata = IERC20Metadata(assetAddress);
        string memory symbol = assetMetadata.symbol();
        uint8 assetDecimals = assetMetadata.decimals();

        // Log claim info
        logClaimInfo(account, assetAddress, symbol, assetDecimals);

        // Get current period info
        uint256 currentPeriod = logPeriodInfo(vault);

        // Find claimable periods (only past periods can be claimed)
        (uint256[] memory claimablePeriods, uint256[] memory withdrawalAmounts, uint256 count) = findClaimablePeriods(
            vault,
            account,
            currentPeriod
        );

        // Log claimable periods
        logClaimablePeriods(claimablePeriods, withdrawalAmounts, count, symbol, assetDecimals);

        if (count == 0) {
            console.log("\nNo claims to execute.");
            return;
        }

        // Execute claims
        vm.startBroadcast(deployerPrivateKey);

        if (PERIOD_TO_CLAIM > 0) {
            // Claim specific period
            bool found = false;
            for (uint256 i = 0; i < count; i++) {
                if (claimablePeriods[i] == PERIOD_TO_CLAIM) {
                    found = true;
                    executeClaim(vault, PERIOD_TO_CLAIM, symbol, assetDecimals);
                    break;
                }
            }
            if (!found) {
                console.log("\nPeriod", PERIOD_TO_CLAIM, "has no claimable withdrawals.");
            }
        } else {
            // Claim all claimable periods
            console.log("\n=== Executing Claims ===");
            for (uint256 i = 0; i < count; i++) {
                executeClaim(vault, claimablePeriods[i], symbol, assetDecimals);
            }
        }

        vm.stopBroadcast();
    }

    function logClaimInfo(
        address account,
        address assetAddress,
        string memory symbol,
        uint8 assetDecimals
    ) internal pure {
        console.log("=== Claim Withdrawals (ERC-4626) ===");
        console.log("Sender:", account);
        console.log("Vault:", FIRELIGHT_VAULT_ADDRESS);
        console.log("Asset:", assetAddress);
        console.log("Asset symbol:", symbol);
        console.log("Asset decimals:", uint256(assetDecimals));
    }

    function logPeriodInfo(IFirelightVault vault) internal view returns (uint256) {
        uint256 currentPeriod = vault.currentPeriod();
        uint48 currentPeriodEnd = vault.currentPeriodEnd();

        console.log("\n=== Period Info ===");
        console.log("Current period:", currentPeriod);
        console.log("Current period ends:", formatTimestamp(currentPeriodEnd));
        console.log("Scanning periods: 0 to", currentPeriod > 0 ? currentPeriod - 1 : 0);

        return currentPeriod;
    }

    function findClaimablePeriods(
        IFirelightVault vault,
        address account,
        uint256 currentPeriod
    ) internal view returns (uint256[] memory periods, uint256[] memory withdrawalAmounts, uint256 count) {
        // Allocate max possible size
        periods = new uint256[](currentPeriod);
        withdrawalAmounts = new uint256[](currentPeriod);
        count = 0;

        // Only past periods can be claimed (period < currentPeriod) and not already claimed
        for (uint256 period = 0; period < currentPeriod; period++) {
            uint256 withdrawals = vault.withdrawalsOf(period, account);
            bool claimed = vault.isWithdrawClaimed(period, account);
            if (withdrawals > 0 && !claimed) {
                periods[count] = period;
                withdrawalAmounts[count] = withdrawals;
                count++;
            }
        }

        return (periods, withdrawalAmounts, count);
    }

    function logClaimablePeriods(
        uint256[] memory periods,
        uint256[] memory withdrawals,
        uint256 count,
        string memory symbol,
        uint8 assetDecimals
    ) internal pure {
        console.log("\n=== Pending Withdrawals (Claimable) ===");

        if (count == 0) {
            console.log("No claimable withdrawals found.");
            return;
        }

        uint256 totalWithdrawals = 0;
        for (uint256 i = 0; i < count; i++) {
            console.log("Period", periods[i], ":", withdrawals[i]);
            console.log("  Formatted:", formatDecimals(withdrawals[i], assetDecimals), symbol);
            totalWithdrawals += withdrawals[i];
        }

        console.log("Total pending:", totalWithdrawals);
        console.log("  Formatted:", formatDecimals(totalWithdrawals, assetDecimals), symbol);
    }

    function executeClaim(IFirelightVault vault, uint256 period, string memory symbol, uint8 assetDecimals) internal {
        try vault.claimWithdraw(period) returns (uint256 claimedAssets) {
            console.log("Claimed period", period, ":", claimedAssets);
            console.log("  Formatted:", formatDecimals(claimedAssets, assetDecimals), symbol);
        } catch {
            console.log("Skipped period", period, "(already claimed or not claimable)");
        }
    }

    function formatTimestamp(uint48 timestamp) internal pure returns (string memory) {
        return string.concat(vm.toString(uint256(timestamp)), " (unix)");
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
