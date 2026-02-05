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
 * @title DepositWorkflow
 * @notice Demonstrates the complete deposit workflow for Boring Vault
 *
 * You'll learn:
 * - Token approval (CRITICAL: approve VAULT, not Teller!)
 * - Exchange rate fetching
 * - Slippage calculation
 * - Deposit execution
 *
 * Prerequisites: Run DeployBoringVault.s.sol first to create deployment-addresses.json
 *
 * Run with command:
 * forge script script/boringVault/DepositWorkflow.s.sol:DepositWorkflow --rpc-url $COSTON2_RPC_URL --broadcast
 */
contract DepositWorkflow is Script {
    using stdJson for string;

    // Configuration
    uint256 public constant DEPOSIT_AMOUNT = 100; // In token units (not wei)
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
        uint256 depositAmount = DEPOSIT_AMOUNT * (10 ** assetDecimals);

        console.log("=== Boring Vault Deposit Workflow ===");
        console.log("");
        console.log("Depositor:", user);
        console.log("Asset:", symbol);
        console.log("  Address:", assetAddress);
        console.log("Vault:", vaultAddress);
        console.log("Teller:", tellerAddress);
        console.log("");

        // Check user's asset balance
        uint256 userBalance = asset.balanceOf(user);
        console.log("=== Step 1: Check Balance ===");
        console.log("Your", symbol, "balance:", userBalance / (10 ** assetDecimals));
        console.log("Deposit amount:", DEPOSIT_AMOUNT, symbol);

        require(userBalance >= depositAmount, "Insufficient balance! Get test tokens first.");
        console.log("");

        // Check allowance for VAULT (not Teller!)
        console.log("=== Step 2: Token Approval ===");
        uint256 currentAllowance = asset.allowance(user, vaultAddress);
        console.log("Current allowance (Vault):", currentAllowance / (10 ** assetDecimals));

        // Calculate expected shares
        console.log("");
        console.log("=== Step 3: Calculate Expected Shares ===");
        uint256 rate = accountant.getRateInQuote(ERC20(assetAddress));
        uint256 expectedShares = (depositAmount * oneShare) / rate;
        uint256 minimumShares = (expectedShares * (10000 - SLIPPAGE_BPS)) / 10000;

        console.log("Exchange rate:", rate / (10 ** assetDecimals), symbol, "per share");
        console.log("Expected shares:", expectedShares / oneShare);
        console.log("Minimum shares (with slippage):", minimumShares / oneShare);
        console.log("");

        // Check if teller is paused
        require(!teller.isPaused(), "Teller is paused! Cannot deposit.");

        // Execute deposit
        console.log("=== Step 4: Execute Deposit ===");
        uint256 sharesBefore = vault.balanceOf(user);
        console.log("Shares before:", sharesBefore / oneShare);

        vm.startBroadcast(deployerPrivateKey);

        // Approve vault if needed
        if (currentAllowance < depositAmount) {
            console.log("Approving vault...");
            asset.approve(vaultAddress, depositAmount);
        }

        // Execute deposit
        console.log("Depositing", DEPOSIT_AMOUNT, symbol, "...");
        teller.deposit(ERC20(assetAddress), depositAmount, minimumShares);

        vm.stopBroadcast();

        // Verify result
        console.log("");
        console.log("=== Step 5: Verify Result ===");
        uint256 sharesAfter = vault.balanceOf(user);
        uint256 sharesReceived = sharesAfter - sharesBefore;

        console.log("Shares after:", sharesAfter / oneShare);
        console.log("Shares received:", sharesReceived / oneShare);

        // Check share lock
        uint256 shareUnlockTime = teller.shareUnlockTime(user);
        console.log("");
        console.log("Share unlock timestamp:", shareUnlockTime);
        console.log("WARNING: Shares are LOCKED until the unlock time!");
        console.log("You cannot withdraw until shares are unlocked.");
        console.log("");
        console.log("=== Deposit Complete ===");
    }
}
