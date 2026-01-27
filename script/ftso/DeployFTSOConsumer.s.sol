// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { FtsoV2Consumer } from "src/FtsoV2Consumer.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/ftso/DeployFTSOConsumer.s.sol:DeployFTSOConsumer --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast
// With verification:
// solhint-disable-next-line max-line-length
// forge script script/ftso/DeployFTSOConsumer.s.sol:DeployFTSOConsumer --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API
contract DeployFTSOConsumer is Script {
    FtsoV2Consumer public ftsoV2Consumer;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== FTSO V2 Consumer Deployment ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);

        ftsoV2Consumer = new FtsoV2Consumer();

        vm.stopBroadcast();

        console.log("FtsoV2Consumer deployed to:", address(ftsoV2Consumer));

        // Call the contract functions to verify deployment
        _callContractFunctions();

        console.log("");
        console.log("Deployment and verification complete.");
    }

    function _callContractFunctions() internal view {
        // Call getFlrUsdPrice
        console.log("");
        console.log("=== Calling getFlrUsdPrice ===");
        try ftsoV2Consumer.getFlrUsdPrice() returns (uint256 price, int8 decimals, uint64 timestamp) {
            console.log("FLR/USD Price Data:");
            console.log("  Price:", price);
            console.log("  Decimals:", decimals);
            console.log("  Timestamp:", timestamp);
        } catch {
            console.log("Error calling getFlrUsdPrice");
        }
        // Call getFlrUsdPriceWei
        console.log("");
        console.log("=== Calling getFlrUsdPriceWei ===");
        try ftsoV2Consumer.getFlrUsdPriceWei() returns (uint256 priceWei, uint64 timestamp) {
            console.log("FLR/USD Price Data (Wei):");
            console.log("  Price (Wei):", priceWei);
            console.log("  Timestamp:", timestamp);
        } catch {
            console.log("Error calling getFlrUsdPriceWei");
        }
        // Call getFtsoV2CurrentFeedValues
        console.log("");
        console.log("=== Calling getFtsoV2CurrentFeedValues ===");
        try ftsoV2Consumer.getFtsoV2CurrentFeedValues() returns (
            uint256[] memory feedValues,
            int8[] memory decimals,
            uint64 timestamp
        ) {
            string[3] memory feedNames = ["FLR/USD", "BTC/USD", "ETH/USD"];
            console.log("Current Feed Values:");
            for (uint256 i = 0; i < feedValues.length; i++) {
                console.log("  Feed:", feedNames[i]);
                console.log("    Price:", feedValues[i]);
                console.log("    Decimals:", decimals[i]);
            }
            console.log("  Timestamp:", timestamp);
        } catch {
            console.log("Error calling getFtsoV2CurrentFeedValues");
        }
    }
}
