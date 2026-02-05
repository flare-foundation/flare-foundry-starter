// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { DynamicNftMinter } from "../../src/adapters/ChronicleExample.sol";

// Configuration constants
bytes21 constant FTSO_FEED_ID = bytes21(0x01464c522f55534400000000000000000000000000);
string constant DESCRIPTION = "FTSO FLR/USD";
string constant DATA_DIR = "data/adapters/chronicle/";

// Step 1: Deploy the minter
// Run with command:
// forge script script/adapters/ChronicleExample.s.sol:DeployMinter --rpc-url $COSTON2_RPC_URL --broadcast

contract DeployMinter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== Deploying DynamicNftMinter (Chronicle Adapter Example) ===");
        console.log("");
        console.log("FTSO Feed ID:", vm.toString(FTSO_FEED_ID));
        console.log("Description:", DESCRIPTION);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        DynamicNftMinter minter = new DynamicNftMinter(FTSO_FEED_ID, DESCRIPTION);

        vm.stopBroadcast();

        console.log("DynamicNftMinter deployed to:", address(minter));
        console.log("");
        console.log("Tier thresholds:");
        console.log("  Bronze: < $0.02");
        console.log("  Silver: >= $0.02");
        console.log("  Gold:   >= $0.03");
        console.log("");
        console.log("Mint fee:", minter.MINT_FEE() / 1e18, "tokens");

        // Write contract address for next steps
        vm.writeFile(string.concat(DATA_DIR, "minter_address.txt"), vm.toString(address(minter)));

        console.log("");
        console.log("Run MintNft to refresh price and mint an NFT.");
    }
}

// Step 2: Refresh price and mint NFT
// Run with command:
// forge script script/adapters/ChronicleExample.s.sol:MintNft --rpc-url $COSTON2_RPC_URL --broadcast

contract MintNft is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "minter_address.txt"));
        address minterAddress = vm.parseAddress(addressStr);

        DynamicNftMinter minter = DynamicNftMinter(minterAddress);

        console.log("=== Minting Dynamic NFT ===");
        console.log("Minter:", minterAddress);
        console.log("User:", user);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Refresh the FTSO price
        console.log("Step 1: Refreshing FTSO price...");
        minter.refresh();
        console.log("Price refreshed.");
        console.log("");

        vm.stopBroadcast();

        // Read the current price
        console.log("Step 2: Reading current price...");
        (bool isValid, uint256 currentPrice) = minter.tryRead();

        if (!isValid) {
            console.log("Price feed is not valid. Try refreshing again.");
            return;
        }

        console.log("Current price (USD):", currentPrice / 1e18);
        console.log("Current price (raw):", currentPrice);
        console.log("");

        // Determine expected tier
        string memory expectedTier;
        if (currentPrice >= minter.GOLD_TIER_PRICE()) {
            expectedTier = "Gold";
        } else if (currentPrice >= minter.SILVER_TIER_PRICE()) {
            expectedTier = "Silver";
        } else {
            expectedTier = "Bronze";
        }
        console.log("Expected tier:", expectedTier);
        console.log("");

        // Mint the NFT
        uint256 mintFee = minter.MINT_FEE();
        console.log("Step 3: Minting NFT with fee of", mintFee / 1e18, "tokens...");

        vm.startBroadcast(deployerPrivateKey);
        minter.mint{ value: mintFee }();
        vm.stopBroadcast();

        console.log("Mint successful!");
        console.log("");
        console.log("=== Result ===");
        console.log("NFT minted with tier:", expectedTier);
    }
}

// Read minter state (no transaction)
// Run with command:
// forge script script/adapters/ChronicleExample.s.sol:ReadMinterState --rpc-url $COSTON2_RPC_URL

contract ReadMinterState is Script {
    function run() external view {
        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "minter_address.txt"));
        address minterAddress = vm.parseAddress(addressStr);

        DynamicNftMinter minter = DynamicNftMinter(minterAddress);

        console.log("=== DynamicNftMinter State ===");
        console.log("Address:", minterAddress);
        console.log("");

        console.log("NFT Name:", minter.name());
        console.log("NFT Symbol:", minter.symbol());
        console.log("Mint Fee:", minter.MINT_FEE() / 1e18, "tokens");
        console.log("");

        console.log("=== Tier Thresholds ===");
        console.log("Silver Tier Price:", minter.SILVER_TIER_PRICE() / 1e18, "USD");
        console.log("Gold Tier Price:", minter.GOLD_TIER_PRICE() / 1e18, "USD");
        console.log("");

        console.log("=== Current Price ===");
        (bool isValid, uint256 price) = minter.tryRead();
        if (isValid) {
            console.log("Price (USD):", price / 1e18);
            console.log("Price (raw):", price);

            string memory currentTier;
            if (price >= minter.GOLD_TIER_PRICE()) {
                currentTier = "Gold";
            } else if (price >= minter.SILVER_TIER_PRICE()) {
                currentTier = "Silver";
            } else {
                currentTier = "Bronze";
            }
            console.log("Current tier for minting:", currentTier);
        } else {
            console.log("Price not available. Run refresh first.");
        }
    }
}
