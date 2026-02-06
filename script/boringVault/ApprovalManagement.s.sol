// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

/**
 * @title ApprovalManagement
 * @notice Demonstrates token approval patterns for Boring Vault deposits
 *
 * CRITICAL: For deposits, approve the VAULT address, NOT the Teller!
 * The Teller calls vault.enter() which calls transferFrom(user, vault, amount)
 * The VAULT performs the actual token transfer, so it needs the approval!
 *
 * Prerequisites: Run DeployBoringVault.s.sol first to create deployment-addresses.json
 *
 * Run with command:
 * forge script script/boringVault/ApprovalManagement.s.sol:ApprovalManagement --rpc-url $COSTON2_RPC_URL --broadcast
 */
contract ApprovalManagement is Script {
    using stdJson for string;

    function run() external {
        // Read deployment addresses from JSON file
        string memory json = vm.readFile("deployment-addresses.json");
        address vaultAddress = json.readAddress(".addresses.boringVault");
        address tellerAddress = json.readAddress(".addresses.teller");

        address assetAddress = json.readAddress(".addresses.baseToken");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        IERC20 asset = IERC20(assetAddress);
        uint8 decimals = 18;

        console.log("=== Boring Vault Approval Management ===");
        console.log("");
        console.log("User:", user);
        console.log("Vault (approve THIS):", vaultAddress);
        console.log("Teller (NOT this!):", tellerAddress);
        console.log("");

        // Check current allowances
        console.log("=== Current Allowances ===");
        uint256 vaultAllowance = asset.allowance(user, vaultAddress);
        console.log("Allowance for VAULT:", vaultAllowance);

        uint256 tellerAllowance = asset.allowance(user, tellerAddress);
        console.log("Allowance for TELLER:", tellerAllowance);
        if (tellerAllowance > 0) {
            console.log("");
            console.log("WARNING: You have an allowance set for the Teller!");
            console.log("This is unnecessary and won't work for deposits.");
        }

        console.log("");
        console.log("=== Approval Options ===");
        console.log("");
        console.log("1. Exact Approval (gas efficient for single use):");
        console.log("   asset.approve(vault, exactAmount)");
        console.log("");
        console.log("2. Infinite Approval (convenient for frequent use):");
        console.log("   asset.approve(vault, type(uint256).max)");
        console.log("");
        console.log("3. Revoke Approval (security best practice when done):");
        console.log("   asset.approve(vault, 0)");
        console.log("");

        // Example: Approve 100 tokens (uncomment to execute)
        uint256 approveAmount = 100 * 10 ** decimals;

        vm.startBroadcast(deployerPrivateKey);

        // Approve the vault (NOT the teller!)
        asset.approve(vaultAddress, approveAmount);

        vm.stopBroadcast();

        // Verify
        uint256 newAllowance = asset.allowance(user, vaultAddress);
        console.log("=== Approval Complete ===");
        console.log("New allowance for VAULT:", newAllowance);
        console.log("");
        console.log("=== Architecture Explanation ===");
        console.log("Deposit Flow:");
        console.log("1. User calls: teller.deposit(asset, amount, minShares)");
        console.log("2. Teller calls: vault.enter(from=user, asset, amount, shares)");
        console.log("3. Vault calls: asset.transferFrom(user, vault, amount)");
        console.log("");
        console.log("The VAULT performs the transferFrom(), so it needs approval!");
    }
}
