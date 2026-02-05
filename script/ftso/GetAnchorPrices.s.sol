// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { Surl } from "dependencies/surl-0.0.0/src/Surl.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/ftso/GetAnchorPrices.s.sol:GetAnchorPrices --rpc-url $COSTON2_RPC_URL --ffi
contract GetAnchorPrices is Script {
    using Surl for *;

    // Feed IDs to check
    bytes21[] public feedIds = [
        bytes21(0x01464c522f55534400000000000000000000000000), // FLR/USD
        bytes21(0x014254432f55534400000000000000000000000000), // BTC/USD
        bytes21(0x014554482f55534400000000000000000000000000) // ETH/USD
    ];

    string[] public feedNames = ["FLR/USD", "BTC/USD", "ETH/USD"];

    function run() external {
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL");
        string memory apiKey = vm.envString("X_API_KEY");

        console.log("=== FTSO Anchor Prices ===");
        console.log("DA Layer URL:", daLayerUrl);

        // Get TestFtsoV2 contract for reference
        console.log("TestFtsoV2 address:", address(ContractRegistry.getTestFtsoV2()));
        console.log("");

        // Process each feed
        for (uint256 i = 0; i < feedIds.length; i++) {
            _processFeed(daLayerUrl, apiKey, feedIds[i], feedNames[i]);
        }

        console.log("");
        console.log("=== Complete ===");
    }

    function _processFeed(
        string memory daLayerUrl,
        string memory apiKey,
        bytes21 feedId,
        string memory feedName
    ) internal {
        console.log("--- Processing", feedName, "---");

        // Convert feedId to hex string for API call
        string memory feedIdHex = _bytes21ToHexString(feedId);

        // Prepare API request
        string memory url = string.concat(daLayerUrl, "/api/v0/ftso/anchor-feeds-with-proof");
        string[] memory headers = new string[](2);
        headers[0] = string.concat("x-apikey: ", apiKey);
        headers[1] = "Content-Type: application/json";
        // solhint-disable-next-line quotes
        string memory body = string.concat('{"feed_ids": ["', feedIdHex, '"]}');

        // Make API call
        (uint256 status, bytes memory response) = url.post(headers, body);

        if (status != 200) {
            console.log("  Error: HTTP status", status);
            return;
        }

        // Parse response and verify on-chain
        // Note: In a real implementation, you would parse the JSON response
        // and extract the proof data. For simplicity, we log the raw response.
        console.log("  API Response received (length):", response.length);

        // Try to verify using the contract (this would need proper proof parsing)
        // For now, just log that we got a response
        console.log("  Feed ID:", feedIdHex);
        console.log("");
    }

    function _bytes21ToHexString(bytes21 value) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(44); // 0x + 42 hex chars
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 21; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i] & 0x0f)];
        }
        return string(str);
    }
}
