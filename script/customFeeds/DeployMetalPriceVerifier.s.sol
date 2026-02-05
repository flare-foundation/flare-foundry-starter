// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { MetalPriceVerifierCustomFeed } from "../../src/customFeeds/MetalPriceVerifierCustomFeed.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/customFeeds/DeployMetalPriceVerifier.s.sol:DeployMetalPriceVerifier --rpc-url $COSTON2_RPC_URL --broadcast --private-key $PRIVATE_KEY
contract DeployMetalPriceVerifier is Script {
    string public constant METAL_SYMBOL = "XAU"; // Gold

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Create feed ID: 0x21 (custom feed category) + first 20 bytes of keccak256(symbol/USD)
        string memory feedIdString = string.concat(METAL_SYMBOL, "/USD");
        bytes32 feedNameHash = keccak256(abi.encodePacked(feedIdString));
        bytes21 feedId = bytes21(abi.encodePacked(bytes1(0x21), bytes20(feedNameHash)));

        console.log("=== Deploying MetalPriceVerifierCustomFeed ===");
        console.log("Metal Symbol:", METAL_SYMBOL);
        console.log("Feed ID:", vm.toString(feedId));

        vm.startBroadcast(deployerPrivateKey);

        MetalPriceVerifierCustomFeed customFeed = new MetalPriceVerifierCustomFeed(feedId, METAL_SYMBOL);

        vm.stopBroadcast();

        console.log("MetalPriceVerifierCustomFeed deployed to:", address(customFeed));
    }
}
