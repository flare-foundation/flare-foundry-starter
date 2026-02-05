// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { PriceTriggeredSafe } from "../../src/adapters/BandExample.sol";

// Configuration constants
string constant DATA_DIR = "data/adapters/band/";

// Step 1: Deploy and deposit funds
// Run with command:
// forge script script/adapters/BandExample.s.sol:DeployAndDeposit --rpc-url $COSTON2_RPC_URL --broadcast

contract DeployAndDeposit is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        uint256 depositAmount = 2 ether;

        console.log("=== Deploying PriceTriggeredSafe (Band Adapter Example) ===");
        console.log("");
        console.log("User/Owner:", user);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the safe
        PriceTriggeredSafe safe = new PriceTriggeredSafe();
        console.log("PriceTriggeredSafe deployed to:", address(safe));
        console.log("");

        // Deposit funds
        console.log("=== Depositing Funds ===");
        console.log("Depositing", depositAmount / 1e18, "native tokens...");
        safe.deposit{ value: depositAmount }();
        console.log("Deposit successful.");
        console.log("");

        // Set baseline prices
        console.log("=== Setting Baseline Prices ===");
        console.log("Performing initial volatility check to record baseline...");
        safe.checkMarketVolatility();
        console.log("Baseline prices recorded.");

        vm.stopBroadcast();

        // Log recorded prices
        console.log("");
        console.log("=== Recorded Baseline Prices ===");
        _logPrices(safe);

        // Initial withdrawal
        console.log("");
        console.log("=== Initial Withdrawal Test ===");
        uint256 withdrawAmount = 1 ether;

        vm.startBroadcast(deployerPrivateKey);
        console.log("Withdrawing", withdrawAmount / 1e18, "tokens while unlocked...");
        safe.withdraw(withdrawAmount);
        console.log("Withdrawal successful.");
        vm.stopBroadcast();

        console.log("");
        console.log("User balance in safe:", safe.balances(user) / 1e18, "tokens");

        // Write contract address for next steps
        vm.writeFile(string.concat(DATA_DIR, "safe_address.txt"), vm.toString(address(safe)));

        console.log("");
        console.log("=== Wait ~180 seconds for market prices to update, then run CheckVolatility ===");
    }

    function _logPrices(PriceTriggeredSafe safe) internal view {
        string[3] memory assets = ["FLR", "BTC", "ETH"];
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 price = safe.lastCheckedPrices(assets[i]);
            if (price == 0) {
                console.log("  %s/USD: (not yet recorded)", assets[i]);
            } else {
                console.log("  %s/USD: %s (raw: %s)", assets[i], price / 1e18, price);
            }
        }
    }
}

// Step 2: Check volatility after waiting
// Run with command:
// forge script script/adapters/BandExample.s.sol:CheckVolatility --rpc-url $COSTON2_RPC_URL --broadcast

contract CheckVolatility is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "safe_address.txt"));
        address safeAddress = vm.parseAddress(addressStr);

        PriceTriggeredSafe safe = PriceTriggeredSafe(safeAddress);

        console.log("=== Checking Market Volatility ===");
        console.log("Contract:", safeAddress);
        console.log("User:", user);
        console.log("");

        // Log current prices before check
        console.log("=== Prices Before Check ===");
        _logPrices(safe);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        console.log("Performing volatility check...");
        safe.checkMarketVolatility();

        vm.stopBroadcast();

        // Log updated prices
        console.log("");
        console.log("=== Prices After Check ===");
        _logPrices(safe);

        // Check lock status
        bool isLocked = safe.isLocked();
        console.log("");
        if (isLocked) {
            console.log("VOLATILITY DETECTED! The safe is now LOCKED.");
            console.log("Run UnlockAndWithdraw to unlock and withdraw funds.");
        } else {
            console.log("MARKET STABLE. The safe remains unlocked.");
            console.log("Run WithdrawFunds to withdraw your remaining balance.");
        }
    }

    function _logPrices(PriceTriggeredSafe safe) internal view {
        string[3] memory assets = ["FLR", "BTC", "ETH"];
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 price = safe.lastCheckedPrices(assets[i]);
            if (price == 0) {
                console.log("  %s/USD: (not yet recorded)", assets[i]);
            } else {
                console.log("  %s/USD: %s (raw: %s)", assets[i], price / 1e18, price);
            }
        }
    }
}

// Step 3a: Unlock (if locked) and withdraw
// Run with command:
// forge script script/adapters/BandExample.s.sol:UnlockAndWithdraw --rpc-url $COSTON2_RPC_URL --broadcast

contract UnlockAndWithdraw is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "safe_address.txt"));
        address safeAddress = vm.parseAddress(addressStr);

        PriceTriggeredSafe safe = PriceTriggeredSafe(safeAddress);

        console.log("=== Unlock and Withdraw ===");
        console.log("Contract:", safeAddress);
        console.log("User:", user);
        console.log("");

        uint256 balance = safe.balances(user);
        console.log("Your balance in safe:", balance / 1e18, "tokens");

        if (balance == 0) {
            console.log("No balance to withdraw.");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        // Unlock if locked
        if (safe.isLocked()) {
            console.log("");
            console.log("Safe is locked. Unlocking...");
            safe.unlockSafe();
            console.log("Safe unlocked.");
        }

        // Withdraw
        console.log("");
        console.log("Withdrawing", balance / 1e18, "tokens...");
        safe.withdraw(balance);
        console.log("Withdrawal successful.");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Final State ===");
        console.log("Balance in safe:", safe.balances(user) / 1e18, "tokens");
    }
}

// Step 3b: Just withdraw (if not locked)
// Run with command:
// forge script script/adapters/BandExample.s.sol:WithdrawFunds --rpc-url $COSTON2_RPC_URL --broadcast

contract WithdrawFunds is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "safe_address.txt"));
        address safeAddress = vm.parseAddress(addressStr);

        PriceTriggeredSafe safe = PriceTriggeredSafe(safeAddress);

        console.log("=== Withdraw Funds ===");
        console.log("Contract:", safeAddress);
        console.log("User:", user);
        console.log("");

        uint256 balance = safe.balances(user);
        console.log("Your balance in safe:", balance / 1e18, "tokens");

        if (balance == 0) {
            console.log("No balance to withdraw.");
            return;
        }

        if (safe.isLocked()) {
            console.log("");
            console.log("Safe is LOCKED. Run UnlockAndWithdraw instead.");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        console.log("Withdrawing", balance / 1e18, "tokens...");
        safe.withdraw(balance);
        console.log("Withdrawal successful.");

        vm.stopBroadcast();

        console.log("");
        console.log("Final balance in safe:", safe.balances(user) / 1e18, "tokens");
    }
}
