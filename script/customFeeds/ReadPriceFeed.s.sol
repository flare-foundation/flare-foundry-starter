// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { PriceVerifierCustomFeed } from "../../src/customFeeds/PriceVerifierCustomFeed.sol";

/**
 * @title ReadPriceFeed
 * @notice Reads data from a deployed PriceVerifierCustomFeed contract
 *
 * Run with command:
 * forge script script/customFeeds/ReadPriceFeed.s.sol:ReadPriceFeed --rpc-url $COSTON2_RPC_URL
 */
contract ReadPriceFeed is Script {
    // Set this address after deployment
    address public constant FEED_ADDRESS = address(0);

    function run() external view {
        require(FEED_ADDRESS != address(0), "Set FEED_ADDRESS before running");

        PriceVerifierCustomFeed feed = PriceVerifierCustomFeed(FEED_ADDRESS);

        console.log("=== Price Custom Feed Info ===");
        console.log("");
        console.log("Feed Address:", FEED_ADDRESS);
        console.log("Feed ID:", vm.toString(feed.feedIdentifier()));
        console.log("Price Symbol:", feed.expectedSymbol());
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

        // Note: PriceVerifierCustomFeed doesn't store timestamps
        // The timestamp is always 0 as prices are historical snapshots
    }
}
