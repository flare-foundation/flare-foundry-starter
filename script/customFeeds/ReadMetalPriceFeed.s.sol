// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { MetalPriceVerifierCustomFeed } from "../../src/customFeeds/MetalPriceVerifierCustomFeed.sol";

/**
 * @title ReadMetalPriceFeed
 * @notice Reads data from a deployed MetalPriceVerifierCustomFeed contract
 *
 * Run with command:
 * forge script script/customFeeds/ReadMetalPriceFeed.s.sol:ReadMetalPriceFeed --rpc-url $COSTON2_RPC_URL
 */
contract ReadMetalPriceFeed is Script {
    // Set this address after deployment
    address public constant FEED_ADDRESS = address(0);

    function run() external view {
        require(FEED_ADDRESS != address(0), "Set FEED_ADDRESS before running");

        MetalPriceVerifierCustomFeed feed = MetalPriceVerifierCustomFeed(FEED_ADDRESS);

        console.log("=== Metal Price Custom Feed Info ===");
        console.log("");
        console.log("Feed Address:", FEED_ADDRESS);
        console.log("Feed ID:", vm.toString(feed.feedIdentifier()));
        console.log("Metal Symbol:", feed.expectedSymbol());
        console.log("");

        // Get the current feed data
        (uint256 value, int8 decimals) = feed.getFeedDataView();

        console.log("=== Feed Data ===");
        console.log("Value (raw):", value);
        console.log("Decimals:", uint8(decimals));

        if (value > 0 && decimals > 0) {
            uint256 price = value / (10 ** uint8(decimals));
            console.log("Price (USD):", price);
        }

        // Get timestamp
        uint64 timestamp = feed.latestVerifiedTimestamp();
        if (timestamp > 0) {
            uint256 age = block.timestamp - timestamp;
            console.log("");
            console.log("=== Data Freshness ===");
            console.log("Timestamp:", timestamp);
            console.log("Data age (seconds):", age);
            console.log("Data age (hours):", age / 3600);
        }
    }
}
