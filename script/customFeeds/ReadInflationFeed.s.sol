// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { InflationCustomFeed } from "../../src/customFeeds/InflationCustomFeed.sol";

/**
 * @title ReadInflationFeed
 * @notice Reads data from a deployed InflationCustomFeed contract
 *
 * Run with command:
 * forge script script/customFeeds/ReadInflationFeed.s.sol:ReadInflationFeed --rpc-url $COSTON2_RPC_URL
 */
contract ReadInflationFeed is Script {
    // Set this address after deployment
    address public constant FEED_ADDRESS = address(0);

    function run() external view {
        require(FEED_ADDRESS != address(0), "Set FEED_ADDRESS before running");

        InflationCustomFeed feed = InflationCustomFeed(FEED_ADDRESS);

        console.log("=== Inflation Custom Feed Info ===");
        console.log("");
        console.log("Feed Address:", FEED_ADDRESS);
        console.log("Feed ID:", vm.toString(feed.feedIdentifier()));
        console.log("Feed Name:", feed.name());
        console.log("");

        // Get the current feed data
        (uint256 value, int8 decimals, uint256 observationYear, uint64 timestamp) = feed.getFeedDataView();

        console.log("=== Feed Data ===");
        console.log("Value (raw):", value);
        console.log("Decimals:", uint8(decimals));
        console.log("Observation Year:", observationYear);
        console.log("Timestamp:", timestamp);

        if (decimals > 0) {
            uint256 rate = value / (10 ** uint8(decimals));
            console.log("Inflation Rate:", rate, "% (scaled)");
        }

        // Calculate data age
        if (timestamp > 0) {
            uint256 age = block.timestamp - timestamp;
            console.log("");
            console.log("=== Data Freshness ===");
            console.log("Data age (seconds):", age);
            console.log("Data age (hours):", age / 3600);
        }
    }
}
