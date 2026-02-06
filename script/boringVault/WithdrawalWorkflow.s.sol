// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from "solady/src/tokens/ERC20.sol";
import { BoringVault } from "../../src/boringVault/BoringVault.sol";
import { AccountantWithRateProviders } from "../../src/boringVault/AccountantWithRateProviders.sol";
import { TellerWithMultiAssetSupport } from "../../src/boringVault/TellerWithMultiAssetSupport.sol";

/**
 * @title WithdrawalWorkflow
 * @notice Demonstrates the complete withdrawal workflow for Boring Vault
 *
 * You'll learn:
 * - Checking if shares are unlocked
 * - Calculating expected assets from shares
 * - Applying slippage protection for withdrawals
 * - Executing bulkWithdraw
 *
 * Prerequisites: Run DeployBoringVault.s.sol first to create deployment-addresses.json
 *
 * Run with command:
 * forge script script/boringVault/WithdrawalWorkflow.s.sol:WithdrawalWorkflow --rpc-url $COSTON2_RPC_URL --broadcast
 *
 * PREREQUISITE: You must have deposited first and waited for shares to unlock!
 */
contract WithdrawalWorkflow is Script {
    using stdJson for string;

    // Configuration
    uint256 public constant WITHDRAW_SHARES = 10; // In share units (not wei)
    uint256 public constant SLIPPAGE_BPS = 50; // 0.5% slippage tolerance

    function run() external {
        // Read deployment addresses from JSON file
        string memory json = vm.readFile("deployment-addresses.json");
        address vaultAddress = json.readAddress(".addresses.boringVault");
        address tellerAddress = json.readAddress(".addresses.teller");
        address accountantAddress = json.readAddress(".addresses.accountant");
        address assetAddress = json.readAddress(".addresses.baseToken");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        BoringVault vault = BoringVault(payable(vaultAddress));
        TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(tellerAddress);
        AccountantWithRateProviders accountant = AccountantWithRateProviders(accountantAddress);
        IERC20 asset = IERC20(assetAddress);
        IERC20Metadata assetMeta = IERC20Metadata(assetAddress);

        uint8 assetDecimals = assetMeta.decimals();
        uint8 vaultDecimals = vault.decimals();
        string memory symbol = assetMeta.symbol();
        uint256 oneShare = 10 ** vaultDecimals;
        uint256 withdrawShares = WITHDRAW_SHARES * oneShare;

        console.log("=== Boring Vault Withdrawal Workflow ===");
        console.log("");
        console.log("Withdrawer:", user);
        console.log("Asset:", symbol);
        console.log("  Address:", assetAddress);
        console.log("Vault:", vaultAddress);
        console.log("Teller:", tellerAddress);
        console.log("");

        // Check share balance
        uint256 shareBalance = vault.balanceOf(user);
        console.log("=== Step 1: Check Share Balance ===");
        console.log("Your share balance:", shareBalance / oneShare);
        console.log("Withdraw amount:", WITHDRAW_SHARES, "shares");

        require(shareBalance >= withdrawShares, "Insufficient share balance! Deposit first.");
        console.log("");

        // CRITICAL: Check if shares are unlocked
        console.log("=== Step 2: Check Share Lock Status ===");
        uint256 shareUnlockTime = teller.shareUnlockTime(user);
        uint256 currentTime = block.timestamp;
        bool isUnlocked = currentTime >= shareUnlockTime;

        console.log("Share unlock timestamp:", shareUnlockTime);
        console.log("Current timestamp:", currentTime);

        require(isUnlocked, "Shares are LOCKED! Wait until shares are unlocked to withdraw.");
        console.log("Status: UNLOCKED - Can withdraw");
        console.log("");

        // Calculate expected assets with slippage
        console.log("=== Step 3: Calculate Expected Assets ===");
        uint256 rate = accountant.getRateInQuote(ERC20(assetAddress));
        uint256 expectedAssets = (withdrawShares * rate) / oneShare;
        uint256 minimumAssets = (expectedAssets * (10000 - SLIPPAGE_BPS)) / 10000;

        console.log("Exchange rate:", rate / (10 ** assetDecimals), symbol, "per share");
        console.log("Expected assets:", expectedAssets / (10 ** assetDecimals), symbol);
        console.log("Minimum assets (with slippage):", minimumAssets / (10 ** assetDecimals), symbol);
        console.log("");

        // Check if teller is paused
        require(!teller.isPaused(), "Teller is paused! Cannot withdraw.");

        // Execute withdrawal
        console.log("=== Step 4: Execute Withdrawal ===");
        uint256 assetsBefore = asset.balanceOf(user);
        uint256 sharesBefore = vault.balanceOf(user);

        console.log("Assets before:", assetsBefore / (10 ** assetDecimals), symbol);
        console.log("Shares before:", sharesBefore / oneShare);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Withdrawing", WITHDRAW_SHARES, "shares...");
        teller.bulkWithdraw(ERC20(assetAddress), withdrawShares, minimumAssets, user);

        vm.stopBroadcast();

        // Verify result
        console.log("");
        console.log("=== Step 5: Verify Result ===");
        uint256 assetsAfter = asset.balanceOf(user);
        uint256 sharesAfter = vault.balanceOf(user);
        uint256 assetsReceived = assetsAfter - assetsBefore;
        uint256 sharesBurned = sharesBefore - sharesAfter;

        console.log("Assets after:", assetsAfter / (10 ** assetDecimals), symbol);
        console.log("Shares after:", sharesAfter / oneShare);
        console.log("");
        console.log("Assets received:", assetsReceived / (10 ** assetDecimals), symbol);
        console.log("Shares burned:", sharesBurned / oneShare);

        // Calculate actual rate
        if (sharesBurned > 0) {
            uint256 actualRate = (assetsReceived * oneShare) / sharesBurned;
            console.log("Actual rate:", actualRate / (10 ** assetDecimals), symbol, "per share");
        }

        console.log("");
        console.log("=== Withdrawal Complete ===");
    }
}
