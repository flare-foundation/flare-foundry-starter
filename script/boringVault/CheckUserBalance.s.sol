// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { BoringVault } from "../../src/boringVault/BoringVault.sol";
import { TellerWithMultiAssetSupport } from "../../src/boringVault/TellerWithMultiAssetSupport.sol";

/**
 * @title CheckUserBalance
 * @notice Shows how to query user-specific data from vault and teller contracts
 *
 * You'll learn:
 * - Reading a user's share balance
 * - Checking share unlock time
 * - Calculating ownership percentage
 * - Working with timestamps
 *
 * Prerequisites: Run DeployBoringVault.s.sol first to create deployment-addresses.json
 *
 * Run with command:
 * forge script script/boringVault/CheckUserBalance.s.sol:CheckUserBalance --rpc-url $COSTON2_RPC_URL
 */
contract CheckUserBalance is Script {
    using stdJson for string;

    function run() external view {
        // Read deployment addresses from JSON file
        string memory json = vm.readFile("deployment-addresses.json");
        address vaultAddress = json.readAddress(".addresses.boringVault");
        address tellerAddress = json.readAddress(".addresses.teller");

        // Get user address from env or use default
        address user = vm.envOr("ACCOUNT", address(0));
        if (user == address(0)) {
            // If no account specified, try to derive from private key
            uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
            if (pk != 0) {
                user = vm.addr(pk);
            }
        }
        require(user != address(0), "Set ACCOUNT or PRIVATE_KEY env var");

        BoringVault vault = BoringVault(payable(vaultAddress));
        TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(tellerAddress);

        console.log("=== Checking User Balance ===");
        console.log("");
        console.log("User Address:", user);
        console.log("Vault Address:", vaultAddress);
        console.log("");

        // Get vault info
        uint8 decimals = vault.decimals();
        string memory symbol = vault.symbol();

        // Get user's share balance
        uint256 balance = vault.balanceOf(user);
        console.log("=== Share Balance ===");
        console.log("Balance (raw):", balance);
        console.log("Balance:", balance / (10 ** decimals), symbol);
        console.log("");

        // Calculate ownership percentage
        uint256 totalSupply = vault.totalSupply();
        if (totalSupply > 0) {
            uint256 basisPoints = (balance * 10000) / totalSupply;
            console.log("=== Ownership ===");
            console.log("Total Supply:", totalSupply / (10 ** decimals), symbol);
            console.log("Ownership (bps):", basisPoints);
            console.log("Ownership (%):", basisPoints / 100);
            console.log("");
        }

        // Check share lock status
        uint256 shareUnlockTime = teller.shareUnlockTime(user);
        uint256 currentTime = block.timestamp;
        bool isUnlocked = currentTime >= shareUnlockTime;

        console.log("=== Share Lock Status ===");
        console.log("Unlock Timestamp:", shareUnlockTime);
        console.log("Current Timestamp:", currentTime);

        if (isUnlocked) {
            console.log("Status: UNLOCKED - User can withdraw");
        } else {
            uint256 remaining = shareUnlockTime - currentTime;
            console.log("Status: LOCKED");
            console.log("Remaining seconds:", remaining);
            console.log("Remaining hours:", remaining / 3600);
        }
        console.log("");

        // Get share lock period configuration
        uint256 shareLockPeriod = teller.shareLockPeriod();
        console.log("=== Lock Configuration ===");
        console.log("Share Lock Period (seconds):", shareLockPeriod);
        console.log("Share Lock Period (hours):", shareLockPeriod / 3600);
        console.log("");

        // Check teller status
        bool isPaused = teller.isPaused();
        console.log("=== Teller Status ===");
        console.log("Is Paused:", isPaused);
        console.log("");

        // Summary
        console.log("=== Summary ===");
        console.log("Balance:", balance / (10 ** decimals), symbol);
        console.log("Unlocked:", isUnlocked);
        console.log("Can Withdraw:", isUnlocked && !isPaused);
    }
}
