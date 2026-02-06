// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { BoringVault } from "../../src/boringVault/BoringVault.sol";
import { AccountantWithRateProviders } from "../../src/boringVault/AccountantWithRateProviders.sol";
import { ERC20 } from "solady/src/tokens/ERC20.sol";

/**
 * @title CalculateExchangeRates
 * @notice Demonstrates how to fetch exchange rates and perform share/asset conversions
 *
 * You'll learn:
 * - Fetching exchange rates from the Accountant
 * - Converting assets to shares (for deposits)
 * - Converting shares to assets (for withdrawals)
 * - The math behind rate calculations
 *
 * Prerequisites: Run DeployBoringVault.s.sol first to create deployment-addresses.json
 *
 * Run with command:
 * forge script script/boringVault/CalculateExchangeRates.s.sol:CalculateExchangeRates --rpc-url $COSTON2_RPC_URL
 */
contract CalculateExchangeRates is Script {
    using stdJson for string;

    function run() external view {
        // Read deployment addresses from JSON file
        string memory json = vm.readFile("deployment-addresses.json");
        address vaultAddress = json.readAddress(".addresses.boringVault");
        address accountantAddress = json.readAddress(".addresses.accountant");

        BoringVault vault = BoringVault(payable(vaultAddress));
        AccountantWithRateProviders accountant = AccountantWithRateProviders(accountantAddress);

        uint8 vaultDecimals = vault.decimals();
        uint256 oneShare = 10 ** vaultDecimals;

        console.log("=== Calculate Exchange Rates ===");
        console.log("");
        console.log("Vault:", vaultAddress);
        console.log("Vault Decimals:", vaultDecimals);
        console.log("oneShare:", oneShare);
        console.log("Accountant:", accountantAddress);
        console.log("");

        // Get base asset info
        ERC20 baseAsset = accountant.base();
        console.log("Base Asset:", address(baseAsset));
        console.log("");

        console.log("=== Understanding oneShare ===");
        console.log("");
        console.log("oneShare represents 1.0 full share in the contract's internal representation.");
        console.log("All rate calculations use oneShare as the base unit.");
        console.log("");
        console.log("Formulas:");
        console.log("- Assets to Shares: shares = (assetAmount * oneShare) / rate");
        console.log("- Shares to Assets: assets = (shareAmount * rate) / oneShare");
        console.log("");
        console.log("Always use integer arithmetic - never floating point!");
    }
}
