// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { PythNftMinter } from "../../src/adapters/PythExample.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

// Configuration constants
bytes21 constant FTSO_FEED_ID = bytes21(0x014254432f55534400000000000000000000000000);
bytes32 constant PYTH_PRICE_ID = bytes32(0x4254432f55534400000000000000000000000000000000000000000000000001);
string constant DESCRIPTION = "FTSOv2 BTC/USD adapted for Pyth";
string constant DATA_DIR = "data/adapters/pyth/";

// Step 1: Deploy the minter
// Run with command:
// forge script script/adapters/PythExample.s.sol:DeployMinter --rpc-url $COSTON2_RPC_URL --broadcast

contract DeployMinter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== Deploying PythNftMinter (Pyth Adapter Example) ===");
        console.log("");
        console.log("FTSO Feed ID:", vm.toString(FTSO_FEED_ID));
        console.log("Pyth Price ID:", vm.toString(PYTH_PRICE_ID));
        console.log("Description:", DESCRIPTION);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        PythNftMinter minter = new PythNftMinter(FTSO_FEED_ID, PYTH_PRICE_ID, DESCRIPTION);

        vm.stopBroadcast();

        console.log("PythNftMinter deployed to:", address(minter));

        // Write contract address for next steps
        vm.writeFile(string.concat(DATA_DIR, "minter_address.txt"), vm.toString(address(minter)));

        console.log("");
        console.log("Run MintNft to refresh price and mint an NFT.");
    }
}

// Step 2: Refresh price and mint NFT
// Run with command:
// forge script script/adapters/PythExample.s.sol:MintNft --rpc-url $COSTON2_RPC_URL --broadcast

contract MintNft is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "minter_address.txt"));
        address minterAddress = vm.parseAddress(addressStr);

        PythNftMinter minter = PythNftMinter(minterAddress);

        console.log("=== Minting NFT with Pyth Price Feed ===");
        console.log("Minter:", minterAddress);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Refresh the FTSO price
        console.log("Step 1: Refreshing FTSO price...");
        minter.refresh();
        console.log("Price refreshed.");
        console.log("");

        vm.stopBroadcast();

        // Get the latest price data
        console.log("Step 2: Fetching price data...");
        PythStructs.Price memory priceData = minter.getPriceUnsafe(PYTH_PRICE_ID);

        int64 price = priceData.price;
        int32 expo = priceData.expo;
        uint256 publishTime = priceData.publishTime;

        // Calculate human-readable price
        uint256 absoluteExpo = expo < 0 ? uint256(uint32(-expo)) : uint256(uint32(expo));
        // solhint-disable-next-line no-unused-vars
        uint256 decimalPrice = uint256(uint64(price));

        console.log("Raw price:", uint256(uint64(price)));
        console.log("Exponent:", expo);
        console.log("Publish time:", publishTime);
        console.log("");

        // Calculate $1 worth of native token
        console.log("Step 3: Calculating mint fee...");
        uint256 assetPrice18Decimals = (uint256(uint64(price)) * 1e18) / (10 ** absoluteExpo);
        uint256 oneDollarInWei = (1e18 * 1e18) / assetPrice18Decimals;

        console.log("Asset price (18 decimals):", assetPrice18Decimals);
        console.log("$1 in wei:", oneDollarInWei);
        console.log("$1 in tokens:", oneDollarInWei / 1e18);
        console.log("");

        // Mint the NFT
        console.log("Step 4: Minting NFT...");

        vm.startBroadcast(deployerPrivateKey);
        minter.mint{ value: oneDollarInWei }();
        vm.stopBroadcast();

        uint256 tokenCount = minter.getTokenCounter();
        console.log("Mint successful!");
        console.log("");
        console.log("=== Result ===");
        console.log("Total NFTs minted:", tokenCount);
    }
}

// Read minter state (no transaction)
// Run with command:
// forge script script/adapters/PythExample.s.sol:ReadMinterState --rpc-url $COSTON2_RPC_URL

contract ReadMinterState is Script {
    function run() external view {
        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "minter_address.txt"));
        address minterAddress = vm.parseAddress(addressStr);

        PythNftMinter minter = PythNftMinter(minterAddress);

        console.log("=== PythNftMinter State ===");
        console.log("Address:", minterAddress);
        console.log("Description:", minter.descriptionText());
        console.log("");

        console.log("=== Configuration ===");
        console.log("FTSO Feed ID:", vm.toString(minter.ftsoFeedId()));
        console.log("Pyth Price ID:", vm.toString(minter.pythPriceId()));
        console.log("");

        console.log("=== Price Data ===");
        PythStructs.Price memory priceData = minter.getPriceUnsafe(PYTH_PRICE_ID);

        console.log("Raw price:", uint256(uint64(priceData.price)));
        console.log("Exponent:", priceData.expo);
        console.log("Publish time:", priceData.publishTime);

        // Calculate human-readable price
        int32 expo = priceData.expo;
        uint256 absoluteExpo = expo < 0 ? uint256(uint32(-expo)) : uint256(uint32(expo));
        uint256 adjustedPrice = (uint256(uint64(priceData.price)) * 1e18) / (10 ** absoluteExpo);
        console.log("Price (18 decimals):", adjustedPrice);
        console.log("");

        console.log("=== NFT Stats ===");
        console.log("Total minted:", minter.getTokenCounter());
    }
}
