// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { BoringVault } from "../../src/boringVault/BoringVault.sol";
import { AccountantWithRateProviders } from "../../src/boringVault/AccountantWithRateProviders.sol";
import { TellerWithMultiAssetSupport } from "../../src/boringVault/TellerWithMultiAssetSupport.sol";
import { TestERC20 } from "../../src/boringVault/TestERC20.sol";
import { ERC20 } from "solady/src/tokens/ERC20.sol";

/**
 * @title DeployBoringVault
 * @notice Deploys the complete Boring Vault system with a mock base token
 *
 * Run with command:
 * forge script script/boringVault/DeployBoringVault.s.sol:DeployBoringVault --rpc-url $COSTON2_RPC_URL --broadcast
 */
contract DeployBoringVault is Script {
    string public constant VAULT_NAME = "Boring Vault";
    string public constant VAULT_SYMBOL = "BV";
    uint8 public constant VAULT_DECIMALS = 18;

    // WNAT address on Flare networks (used as native wrapper)
    address public constant WNAT_ADDRESS = 0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d; // Coston2

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying Boring Vault System ===");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy a mock base token
        TestERC20 baseToken = new TestERC20("Test USD", "TUSD", 18, 1_000_000 * 1e18);
        console.log("TestERC20 (base token) deployed to:", address(baseToken));

        // Deploy the vault
        BoringVault vault = new BoringVault(deployer, VAULT_NAME, VAULT_SYMBOL, VAULT_DECIMALS);
        console.log("BoringVault deployed to:", address(vault));

        // Deploy the accountant
        AccountantWithRateProviders accountant = new AccountantWithRateProviders(
            deployer,
            address(vault),
            deployer, // payout address
            1e18, // starting exchange rate (1:1)
            address(baseToken), // base asset (mock TUSD)
            0, // allowed exchange rate change upper
            0, // allowed exchange rate change lower
            0, // minimum update delay
            0, // management fee
            0 // platform fee
        );
        console.log("AccountantWithRateProviders deployed to:", address(accountant));

        // Deploy the teller
        TellerWithMultiAssetSupport teller = new TellerWithMultiAssetSupport(
            deployer,
            address(vault),
            address(accountant),
            WNAT_ADDRESS // WNAT as native wrapper
        );
        console.log("TellerWithMultiAssetSupport deployed to:", address(teller));

        // Configure the teller to accept the base token for deposits and withdrawals
        teller.updateAssetData(
            ERC20(address(baseToken)),
            true, // allowDeposits
            true, // allowWithdraws
            0 // sharePremium (0 = no premium)
        );
        console.log("Teller configured to accept base token");

        // Transfer vault ownership to the Teller so it can mint/burn shares
        vault.transferOwnership(address(teller));
        console.log("Vault ownership transferred to Teller");

        vm.stopBroadcast();

        // Write deployment addresses to JSON file
        string memory json = string.concat(
            '{\n  "addresses": {\n',
            '    "boringVault": "',
            vm.toString(address(vault)),
            '",\n',
            '    "accountant": "',
            vm.toString(address(accountant)),
            '",\n',
            '    "teller": "',
            vm.toString(address(teller)),
            '",\n',
            '    "baseToken": "',
            vm.toString(address(baseToken)),
            '"\n  }\n}'
        );
        vm.writeFile("deployment-addresses.json", json);

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Addresses written to deployment-addresses.json");
    }
}
