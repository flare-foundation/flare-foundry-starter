// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { BoringVault } from "../../src/boringVault/BoringVault.sol";
import { AccountantWithRateProviders } from "../../src/boringVault/AccountantWithRateProviders.sol";
import { TellerWithMultiAssetSupport } from "../../src/boringVault/TellerWithMultiAssetSupport.sol";

/**
 * @title ReadVaultInfo
 * @notice Reads basic info from a deployed Boring Vault
 *
 * Prerequisites: Run DeployBoringVault.s.sol first to create deployment-addresses.json
 *
 * Run with command:
 * forge script script/boringVault/ReadVaultInfo.s.sol:ReadVaultInfo --rpc-url $COSTON2_RPC_URL
 */
contract ReadVaultInfo is Script {
    using stdJson for string;

    function run() external view {
        // Read deployment addresses from JSON file
        string memory json = vm.readFile("deployment-addresses.json");
        address vaultAddress = json.readAddress(".addresses.boringVault");

        BoringVault vault = BoringVault(payable(vaultAddress));

        console.log("=== Boring Vault Info ===");
        console.log("Vault address:", vaultAddress);
        console.log("Vault name:", vault.name());
        console.log("Vault symbol:", vault.symbol());
        console.log("Total supply:", vault.totalSupply());

        // Read optional accountant address
        address accountantAddress = json.readAddress(".addresses.accountant");
        if (accountantAddress != address(0)) {
            AccountantWithRateProviders accountant = AccountantWithRateProviders(accountantAddress);
            console.log("");
            console.log("=== Accountant Info ===");
            console.log("Accountant address:", accountantAddress);
            console.log("Vault:", address(accountant.vault()));
        }

        // Read optional teller address
        address tellerAddress = json.readAddress(".addresses.teller");
        if (tellerAddress != address(0)) {
            TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(tellerAddress);
            console.log("");
            console.log("=== Teller Info ===");
            console.log("Teller address:", tellerAddress);
            console.log("Vault:", address(teller.vault()));
            console.log("Is paused:", teller.isPaused());
        }
    }
}
