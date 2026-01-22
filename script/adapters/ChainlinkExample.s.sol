// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { AssetVault } from "../../src/adapters/ChainlinkExample.sol";

// Configuration constants
bytes21 constant FTSO_FEED_ID = bytes21(0x01464c522f55534400000000000000000000000000);
uint8 constant CHAINLINK_DECIMALS = 8;
string constant DESCRIPTION = "FTSOv2 FLR/USD adapted for Chainlink";
uint256 constant MAX_AGE_SECONDS = 3600;
string constant DATA_DIR = "data/adapters/chainlink/";

// Step 1: Deploy and deposit collateral
// Run with command:
// forge script script/adapters/ChainlinkExample.s.sol:DeployAndDeposit --rpc-url $COSTON2_RPC_URL --broadcast

contract DeployAndDeposit is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        uint256 depositAmount = 100 ether;

        console.log("=== Deploying AssetVault (Chainlink Adapter Example) ===");
        console.log("");
        console.log("FTSO Feed ID:", vm.toString(FTSO_FEED_ID));
        console.log("Chainlink Decimals:", uint256(CHAINLINK_DECIMALS));
        console.log("Description:", DESCRIPTION);
        console.log("Max Age (seconds):", MAX_AGE_SECONDS);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the vault
        AssetVault vault = new AssetVault(FTSO_FEED_ID, CHAINLINK_DECIMALS, DESCRIPTION, MAX_AGE_SECONDS);
        console.log("AssetVault deployed to:", address(vault));
        console.log("");

        // Deposit collateral
        console.log("=== Depositing Collateral ===");
        console.log("User:", user);
        console.log("Depositing", depositAmount / 1e18, "native tokens as collateral...");
        vault.deposit{ value: depositAmount }();
        console.log("Deposit successful.");

        // Refresh price feed
        console.log("");
        console.log("Refreshing FTSO price on adapter...");
        vault.refresh();
        console.log("Price feed refreshed.");

        vm.stopBroadcast();

        // Check collateral value
        uint256 collateralValue = vault.getCollateralValueInUsd(user);
        console.log("");
        console.log("=== Collateral Value ===");
        console.log("User collateral:", vault.collateral(user) / 1e18, "tokens");
        console.log("Collateral value:", collateralValue / 1e18, "USD");

        // Write contract address for next steps
        vm.writeFile(string.concat(DATA_DIR, "vault_address.txt"), vm.toString(address(vault)));

        console.log("");
        console.log("Run BorrowMUSD to borrow against your collateral.");
    }
}

// Step 2: Borrow MUSD against collateral
// Run with command:
// forge script script/adapters/ChainlinkExample.s.sol:BorrowMUSD --rpc-url $COSTON2_RPC_URL --broadcast

contract BorrowMUSD is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "vault_address.txt"));
        address vaultAddress = vm.parseAddress(addressStr);

        AssetVault vault = AssetVault(vaultAddress);

        console.log("=== Borrowing MUSD ===");
        console.log("Vault:", vaultAddress);
        console.log("User:", user);
        console.log("");

        // Refresh price first
        vm.startBroadcast(deployerPrivateKey);
        console.log("Refreshing price feed...");
        vault.refresh();
        vm.stopBroadcast();

        // Get collateral value
        uint256 collateralValue = vault.getCollateralValueInUsd(user);
        uint256 ltvRatio = vault.LOAN_TO_VALUE_RATIO();
        uint256 maxBorrow = (collateralValue * ltvRatio) / 100;
        uint256 borrowAmount = (collateralValue * 40) / 100; // Borrow 40% of value

        console.log("Collateral value:", collateralValue / 1e18, "USD");
        console.log("LTV Ratio:", ltvRatio, "%");
        console.log("Max borrowable:", maxBorrow / 1e18, "MUSD");
        console.log("Borrowing:", borrowAmount / 1e18, "MUSD (40% of collateral)");
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        vault.borrow(borrowAmount);
        console.log("Borrow successful.");

        vm.stopBroadcast();

        uint256 musdBalance = vault.balanceOf(user);
        console.log("");
        console.log("=== Result ===");
        console.log("Your MUSD balance:", musdBalance / 1e18, "MUSD");
        console.log("");
        console.log("Run RepayAndWithdraw to repay loan and withdraw collateral.");
    }
}

// Step 3: Repay loan and withdraw collateral
// Run with command:
// forge script script/adapters/ChainlinkExample.s.sol:RepayAndWithdraw --rpc-url $COSTON2_RPC_URL --broadcast

contract RepayAndWithdraw is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "vault_address.txt"));
        address vaultAddress = vm.parseAddress(addressStr);

        AssetVault vault = AssetVault(vaultAddress);

        console.log("=== Repay and Withdraw ===");
        console.log("Vault:", vaultAddress);
        console.log("User:", user);
        console.log("");

        uint256 musdBalance = vault.balanceOf(user);
        uint256 collateral = vault.collateral(user);

        console.log("Current MUSD balance:", musdBalance / 1e18, "MUSD");
        console.log("Current collateral:", collateral / 1e18, "tokens");
        console.log("");

        if (musdBalance == 0 && collateral == 0) {
            console.log("No loan or collateral to process.");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        // Repay loan if exists
        if (musdBalance > 0) {
            console.log("Repaying", musdBalance / 1e18, "MUSD loan...");
            // Approve vault to spend MUSD
            vault.approve(vaultAddress, musdBalance);
            console.log("Approval granted.");
            vault.repay(musdBalance);
            console.log("Repayment successful.");
            console.log("");
        }

        // Withdraw collateral
        if (collateral > 0) {
            console.log("Withdrawing", collateral / 1e18, "tokens collateral...");
            vault.withdraw(collateral);
            console.log("Withdrawal successful.");
        }

        vm.stopBroadcast();

        console.log("");
        console.log("=== Final State ===");
        console.log("MUSD balance:", vault.balanceOf(user) / 1e18, "MUSD");
        console.log("Collateral in vault:", vault.collateral(user) / 1e18, "tokens");
    }
}

// Read vault state (no transaction)
// Run with command:
// forge script script/adapters/ChainlinkExample.s.sol:ReadVaultState --rpc-url $COSTON2_RPC_URL

contract ReadVaultState is Script {
    function run() external view {
        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "vault_address.txt"));
        address vaultAddress = vm.parseAddress(addressStr);

        AssetVault vault = AssetVault(vaultAddress);

        address user = vm.envOr("ACCOUNT", address(0));
        if (user == address(0)) {
            user = vm.addr(vm.envUint("PRIVATE_KEY"));
        }

        console.log("=== AssetVault State ===");
        console.log("Vault:", vaultAddress);
        console.log("User:", user);
        console.log("");

        console.log("Token Name:", vault.name());
        console.log("Token Symbol:", vault.symbol());
        console.log("LTV Ratio:", vault.LOAN_TO_VALUE_RATIO(), "%");
        console.log("");

        console.log("=== User Position ===");
        console.log("Collateral:", vault.collateral(user) / 1e18, "tokens");
        console.log("MUSD Balance:", vault.balanceOf(user) / 1e18, "MUSD");

        uint256 collateralValue = vault.getCollateralValueInUsd(user);
        console.log("Collateral Value:", collateralValue / 1e18, "USD");
    }
}
