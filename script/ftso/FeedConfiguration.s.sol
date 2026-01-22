// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { IFastUpdatesConfiguration } from "flare-periphery/src/coston2/IFastUpdatesConfiguration.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/ftso/FeedConfiguration.s.sol:FeedConfiguration --rpc-url $COSTON2_RPC_URL
contract FeedConfiguration is Script {
    function run() external view {
        // Get FastUpdatesConfiguration contract from registry
        IFastUpdatesConfiguration config = ContractRegistry.getFastUpdatesConfiguration();

        console.log("=== FTSO Feed Configuration ===");
        console.log("FastUpdatesConfiguration address:", address(config));

        // Get number of feeds
        uint256 numFeeds = config.getNumberOfFeeds();
        console.log("Total number of feeds:", numFeeds);

        // Get all feed IDs
        bytes21[] memory feedIds = config.getFeedIds();

        console.log("");
        console.log("=== Configured Feeds ===");
        for (uint256 i = 0; i < feedIds.length; i++) {
            if (feedIds[i] != bytes21(0)) {
                console.log("Index", i, ":", vm.toString(feedIds[i]));
            }
        }

        // Get unused indices
        uint256[] memory unusedIndices = config.getUnusedIndices();
        if (unusedIndices.length > 0) {
            console.log("");
            console.log("=== Unused Indices ===");
            for (uint256 i = 0; i < unusedIndices.length; i++) {
                console.log("Index:", unusedIndices[i]);
            }
        }
    }
}
