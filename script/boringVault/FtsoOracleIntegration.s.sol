// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { IFlareContractRegistry } from "flare-periphery/src/coston2/IFlareContractRegistry.sol";
import { IFtsoRegistry } from "flare-periphery/src/coston2/IFtsoRegistry.sol";

/**
 * @title FtsoOracleIntegration
 * @notice Demonstrates how to use Flare's FTSO for Boring Vault price feeds
 *
 * You'll learn:
 * - How FTSO provides decentralized price feeds
 * - Fetching prices from FTSO
 * - Understanding rate providers for the vault
 * - Real-world exchange rate calculations
 *
 * Run with command:
 * forge script script/boringVault/FtsoOracleIntegration.s.sol:FtsoOracleIntegration --rpc-url $COSTON2_RPC_URL
 */
contract FtsoOracleIntegration is Script {
    // Flare Contract Registry address (same on all Flare networks)
    address public constant FLARE_CONTRACT_REGISTRY = 0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019;

    function run() external view {
        console.log("=== FTSO Oracle Integration Example ===");
        console.log("");

        // Get FTSO Registry from Flare Contract Registry
        IFlareContractRegistry registry = IFlareContractRegistry(FLARE_CONTRACT_REGISTRY);
        address ftsoRegistryAddress = registry.getContractAddressByName("FtsoRegistry");

        console.log("Flare Contract Registry:", FLARE_CONTRACT_REGISTRY);
        console.log("FTSO Registry:", ftsoRegistryAddress);
        console.log("");

        IFtsoRegistry ftsoRegistry = IFtsoRegistry(ftsoRegistryAddress);

        // Fetch prices for common symbols
        console.log("=== Step 1: Fetch Prices from FTSO ===");
        console.log("");

        _fetchPrice(ftsoRegistry, "FLR");
        _fetchPrice(ftsoRegistry, "BTC");
        _fetchPrice(ftsoRegistry, "ETH");
        _fetchPrice(ftsoRegistry, "XRP");

        // Explain pegged vs oracle-based rates
        console.log("=== Step 2: Pegged vs Oracle-Based Rates ===");
        console.log("");
        console.log("Scenario: User wants to deposit 1 WETH");
        console.log("Base Asset: TUSD (USD-pegged stablecoin)");
        console.log("");
        console.log("Pegged Approach (1:1):");
        console.log("  1 WETH = 1 TUSD = $1.00");
        console.log("  Problem: Ignores real ETH market price!");
        console.log("");
        console.log("Oracle Approach (FTSO):");
        console.log("  1 WETH = $X (live market price from FTSO)");
        console.log("  Benefit: Accurate pricing based on real markets!");
        console.log("");

        // Show deployment guide
        console.log("=== Step 3: Deploy FTSO Rate Provider ===");
        console.log("");
        console.log("To deploy a rate provider for WETH using FTSOv2:");
        console.log("");
        console.log("1. Get FTSOv2 feed ID:");
        console.log('   bytes21 feedId = ftsoFeedIdConverter.getFeedId(1, "ETH");');
        console.log("");
        console.log("2. Deploy rate provider:");
        console.log("   FTSOv2RateProvider provider = new FTSOv2RateProvider(");
        console.log("       feedId,     // Feed ID (bytes21)");
        console.log("       18,         // Rate decimals");
        console.log("       300         // Staleness check (5 min)");
        console.log("   );");
        console.log("");

        // Show configuration guide
        console.log("=== Step 4: Configure Accountant ===");
        console.log("");
        console.log("After deploying rate providers, configure them:");
        console.log("");
        console.log("accountant.setRateProviderData(");
        console.log("    WETH_ADDRESS,");
        console.log("    false,                    // NOT pegged to base");
        console.log("    wethRateProvider.address  // Use FTSO oracle");
        console.log(");");
        console.log("");

        // Show exchange rate calculation
        console.log("=== Step 5: Exchange Rate Calculation ===");
        console.log("");
        console.log("With Oracle Integration:");
        console.log("1. User deposits 1 WETH");
        console.log("2. Accountant calls wethRateProvider.getRate()");
        console.log("3. Rate provider queries FTSO for ETH/USD price");
        console.log("4. FTSO returns: $3,500 (example)");
        console.log("5. Formula: shares = (1 WETH * 3500 USD/ETH) / (1 USD/share)");
        console.log("6. User receives: 3,500 shares");
        console.log("");

        // Show FTSO advantages
        console.log("=== Step 6: Why Flare FTSO? ===");
        console.log("");
        console.log("Compared to other oracles:");
        console.log("");
        console.log("Chainlink:");
        console.log("  - Centralized data providers");
        console.log("  - May not be available on all networks");
        console.log("  - Requires LINK token fees");
        console.log("");
        console.log("Flare FTSO:");
        console.log("  - Decentralized (70+ independent providers)");
        console.log("  - Native to Flare/Coston2");
        console.log("  - NO fees - completely free!");
        console.log("  - Block update frequency");
        console.log("  - Covers major pairs: BTC, ETH, FLR, XRP, etc.");
        console.log("");

        // Production checklist
        console.log("=== Step 7: Production Checklist ===");
        console.log("");
        console.log("[ ] 1. Deploy FTSO rate providers for each asset");
        console.log("[ ] 2. Configure Accountant with rate providers");
        console.log("[ ] 3. Test rate fetching works correctly");
        console.log("[ ] 4. Verify staleness checks trigger appropriately");
        console.log("[ ] 5. Set up monitoring for price feed health");
        console.log("[ ] 6. Test with small deposits first");
        console.log("");
        console.log("=== Success! ===");
        console.log("You now understand how to integrate FTSO oracles!");
    }

    function _fetchPrice(IFtsoRegistry ftsoRegistry, string memory symbol) internal view {
        try ftsoRegistry.getCurrentPriceWithDecimals(symbol) returns (
            uint256 price,
            uint256 timestamp,
            uint256 decimals
        ) {
            uint256 priceAge = block.timestamp - timestamp;
            console.log(symbol, "/USD:");
            console.log("  Price:", price / (10 ** decimals));
            console.log("  Decimals:", decimals);
            console.log("  Age (seconds):", priceAge);
            if (priceAge < 300) {
                console.log("  Status: Fresh");
            } else {
                console.log("  Status: Stale (> 5 min)");
            }
            console.log("");
        } catch {
            console.log(symbol, "/USD: Not available on this network");
            console.log("");
        }
    }
}
