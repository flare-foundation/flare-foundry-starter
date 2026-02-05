// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { InflationCustomFeed } from "../../src/customFeeds/InflationCustomFeed.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/customFeeds/DeployInflationFeed.s.sol:DeployInflationFeed --rpc-url $COSTON2_RPC_URL --broadcast --private-key $PRIVATE_KEY
contract DeployInflationFeed is Script {
    string public constant FEED_NAME = "US-CPI";

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Create feed ID: 0x21 (custom feed category) + first 20 bytes of keccak256(feedName)
        bytes32 feedNameHash = keccak256(abi.encodePacked(FEED_NAME));
        bytes21 feedId = bytes21(abi.encodePacked(bytes1(0x21), bytes20(feedNameHash)));

        console.log("=== Deploying InflationCustomFeed ===");
        console.log("Feed Name:", FEED_NAME);
        console.log("Feed ID:", vm.toString(feedId));

        vm.startBroadcast(deployerPrivateKey);

        InflationCustomFeed customFeed = new InflationCustomFeed(feedId, FEED_NAME);

        vm.stopBroadcast();

        console.log("InflationCustomFeed deployed to:", address(customFeed));
    }
}
