// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
/* solhint-disable ordering */
import { Script, console } from "forge-std/Script.sol";
import { Surl } from "dependencies/surl-0.0.0/src/Surl.sol";
// solhint-disable-next-line no-unused-import
import { Strings } from "@openzeppelin-contracts/utils/Strings.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { TestFtsoV2Interface } from "flare-periphery/src/coston2/TestFtsoV2Interface.sol";
import { FtsoV2AnchorFeedConsumer } from "src/FtsoV2AnchorFeedConsumer.sol";
import { Base as StringsBase } from "src/utils/fdcStrings/Base.sol";

// Configuration
string constant ANCHOR_DIR_PATH = "data/anchor/";
string constant FEED_DATA_FILE = "anchor_feed_data";

// Feed IDs for reference
bytes21 constant FLR_USD_ID = 0x01464c522f55534400000000000000000000000000;
bytes21 constant BTC_USD_ID = 0x014254432f55534400000000000000000000000000;
bytes21 constant ETH_USD_ID = 0x014554482f55534400000000000000000000000000;

// =============================================================================
// Step 1: Fetch anchor feeds from DA Layer and save to file
// =============================================================================
// Run with command:
// solhint-disable-next-line max-line-length
// forge script script/ftso/FetchAndVerifyAnchorFeed.s.sol:FetchAnchorFeeds --rpc-url $COSTON2_RPC_URL --ffi
contract FetchAnchorFeeds is Script {
    using Surl for *;

    bytes21[] public feedIds = [FLR_USD_ID, BTC_USD_ID, ETH_USD_ID];

    function run() external {
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL");
        string memory apiKey = vm.envString("X_API_KEY");

        console.log("=== Fetching Anchor Feeds from DA Layer ===");
        console.log("DA Layer URL:", daLayerUrl);

        // Prepare API request
        string memory url = string.concat(daLayerUrl, "/api/v0/ftso/anchor-feeds-with-proof");
        string[] memory headers = new string[](2);
        headers[0] = string.concat("x-apikey: ", apiKey);
        headers[1] = "Content-Type: application/json";

        // Build feed_ids array
        string memory feedIdsJson = _buildFeedIdsJson();
        // solhint-disable-next-line quotes
        string memory body = string.concat('{"feed_ids": [', feedIdsJson, "]}");

        console.log("Requesting feeds...");

        // Make API call
        (uint256 status, bytes memory response) = url.post(headers, body);

        if (status != 200) {
            console.log("Error: HTTP status", status);
            revert("Failed to fetch anchor feeds");
        }

        console.log("Response received (length):", response.length);

        // Save raw response to file for next step
        _ensureDirectoryExists();
        string memory filePath = string.concat(ANCHOR_DIR_PATH, FEED_DATA_FILE, ".txt");
        vm.writeFile(filePath, string(response));
        console.log("Saved response to:", filePath);

        console.log("");
        console.log("=== Step 1 Complete ===");
        console.log("Next: Run DeployAnchorFeedConsumer to deploy the contract");
    }

    function _buildFeedIdsJson() internal view returns (string memory) {
        string memory result = "";
        for (uint256 i = 0; i < feedIds.length; i++) {
            if (i > 0) result = string.concat(result, ", ");
            // solhint-disable-next-line quotes
            result = string.concat(result, '"', _bytes21ToHexString(feedIds[i]), '"');
        }
        return result;
    }

    function _ensureDirectoryExists() internal view {
        if (!vm.isDir(ANCHOR_DIR_PATH)) {
            revert(string.concat("Please create directory: ", ANCHOR_DIR_PATH));
        }
    }

    function _bytes21ToHexString(bytes21 value) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(44);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 21; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i] & 0x0f)];
        }
        return string(str);
    }
}

// =============================================================================
// Step 2: Deploy the FtsoV2AnchorFeedConsumer contract
// =============================================================================
// Run with command:
// solhint-disable-next-line max-line-length
// forge script script/ftso/FetchAndVerifyAnchorFeed.s.sol:DeployAnchorFeedConsumer --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API
contract DeployAnchorFeedConsumer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== Deploying FtsoV2AnchorFeedConsumer ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);

        FtsoV2AnchorFeedConsumer consumer = new FtsoV2AnchorFeedConsumer();

        vm.stopBroadcast();

        address consumerAddress = address(consumer);
        console.log("FtsoV2AnchorFeedConsumer deployed to:", consumerAddress);

        // Save address to file
        _ensureDirectoryExists();
        string memory filePath = string.concat(ANCHOR_DIR_PATH, "consumer_address.txt");
        vm.writeFile(filePath, StringsBase.toHexString(abi.encodePacked(consumerAddress)));
        console.log("Saved address to:", filePath);

        console.log("");
        console.log("=== Step 2 Complete ===");
        console.log("Next: Run VerifyAndSaveAnchorFeeds to verify and save feeds");
    }

    function _ensureDirectoryExists() internal view {
        if (!vm.isDir(ANCHOR_DIR_PATH)) {
            revert(string.concat("Please create directory: ", ANCHOR_DIR_PATH));
        }
    }
}

// =============================================================================
// Step 3: Parse feed data, verify proofs, and save to contract
// =============================================================================
// Note: This step requires proper JSON parsing which is complex in Solidity.
// In practice, you would use off-chain tooling or FFI with jq to parse the response.
//
// Run with command:
// solhint-disable-next-line max-line-length
// forge script script/ftso/FetchAndVerifyAnchorFeed.s.sol:VerifyAndSaveAnchorFeeds --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --ffi
contract VerifyAndSaveAnchorFeeds is Script {
    function run() external view {
        console.log("=== Verifying and Saving Anchor Feeds ===");

        // Read consumer address from file
        string memory addressPath = string.concat(ANCHOR_DIR_PATH, "consumer_address.txt");
        string memory addressStr = vm.readLine(addressPath);
        address consumerAddress = vm.parseAddress(addressStr);
        console.log("Consumer contract:", consumerAddress);

        // Read feed data from file
        string memory dataPath = string.concat(ANCHOR_DIR_PATH, FEED_DATA_FILE, ".txt");
        string memory feedDataJson = vm.readLine(dataPath);
        console.log("Feed data loaded (length):", bytes(feedDataJson).length);

        // Parse and verify each feed using FFI with jq
        // This is a simplified example - in production you'd parse the full JSON
        console.log("");
        console.log("Note: Full JSON parsing requires FFI with jq.");
        console.log("The feed data has been fetched and the contract deployed.");
        console.log("Use off-chain tooling to parse the JSON and call savePrice().");

        // For demonstration, show the TestFtsoV2 address for manual verification
        TestFtsoV2Interface ftsoV2 = ContractRegistry.getTestFtsoV2();
        console.log("");
        console.log("TestFtsoV2 address:", address(ftsoV2));
        console.log("You can manually verify feed data using ftsoV2.verifyFeedData()");

        console.log("");
        console.log("=== Workflow Complete ===");
    }
}
