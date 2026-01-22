// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { PriceVerifierCustomFeed } from "../../src/customFeeds/PriceVerifierCustomFeed.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/customFeeds/DeployPriceVerifier.s.sol:DeployPriceVerifier --rpc-url $COSTON2_RPC_URL --broadcast --private-key $PRIVATE_KEY
contract DeployPriceVerifier is Script {
    string public constant PRICE_SYMBOL = "BTC";
    int8 public constant PRICE_DECIMALS = 2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Create feed ID: 0x21 (custom feed category) + first 20 bytes of keccak256(symbol/USD-HIST)
        string memory feedIdString = string.concat(PRICE_SYMBOL, "/USD-HIST");
        bytes32 feedNameHash = keccak256(abi.encodePacked(feedIdString));
        bytes21 feedId = bytes21(abi.encodePacked(bytes1(0x21), bytes20(feedNameHash)));

        console.log("=== Deploying PriceVerifierCustomFeed ===");
        console.log("Price Symbol:", PRICE_SYMBOL);
        console.log("Price Decimals:", uint256(uint8(PRICE_DECIMALS)));
        console.log("Feed ID:", vm.toString(feedId));

        vm.startBroadcast(deployerPrivateKey);

        PriceVerifierCustomFeed customFeed = new PriceVerifierCustomFeed(feedId, PRICE_SYMBOL, PRICE_DECIMALS);

        vm.stopBroadcast();

        console.log("PriceVerifierCustomFeed deployed to:", address(customFeed));
    }
}
