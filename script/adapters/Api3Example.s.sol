// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { PriceGuesser } from "../../src/adapters/Api3Example.sol";

// Configuration constants
bytes21 constant FTSO_FEED_ID = bytes21(0x01464c522f55534400000000000000000000000000);
string constant DESCRIPTION = "FTSOv2 FLR/USD adapted for API3";
uint256 constant MAX_AGE_SECONDS = 3600;
uint256 constant STRIKE_PRICE_USD = 0.025 ether;
uint256 constant ROUND_DURATION_SECONDS = 300;
string constant DATA_DIR = "data/adapters/api3/";

// Step 1: Deploy and place bets
// Run with command:
// forge script script/adapters/Api3Example.s.sol:DeployAndBet --rpc-url $COSTON2_RPC_URL --broadcast

contract DeployAndBet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying PriceGuesser (API3 Adapter Example) ===");
        console.log("");
        console.log("FTSO Feed ID:", vm.toString(FTSO_FEED_ID));
        console.log("Description:", DESCRIPTION);
        console.log("Max Age (seconds):", MAX_AGE_SECONDS);
        console.log("Strike Price (USD):", STRIKE_PRICE_USD / 1e18);
        console.log("Strike Price (wei):", STRIKE_PRICE_USD);
        console.log("Round Duration (seconds):", ROUND_DURATION_SECONDS);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the PriceGuesser
        PriceGuesser guesser = new PriceGuesser(
            FTSO_FEED_ID,
            DESCRIPTION,
            MAX_AGE_SECONDS,
            STRIKE_PRICE_USD,
            ROUND_DURATION_SECONDS
        );

        console.log("PriceGuesser deployed to:", address(guesser));
        console.log("");

        // Place bets
        uint256 betAmountAbove = 10 ether;
        uint256 betAmountBelow = 20 ether;

        console.log("=== Placing Bets ===");
        console.log("Deployer/Bettor:", deployer);

        console.log("Placing bet ABOVE strike price:", betAmountAbove / 1e18, "tokens");
        guesser.betAbove{ value: betAmountAbove }();

        console.log("Placing bet BELOW strike price:", betAmountBelow / 1e18, "tokens");
        guesser.betBelow{ value: betAmountBelow }();

        vm.stopBroadcast();

        console.log("");
        console.log("Total bets above:", guesser.totalBetsAbove() / 1e18, "tokens");
        console.log("Total bets below:", guesser.totalBetsBelow() / 1e18, "tokens");
        console.log("Expiry timestamp:", guesser.expiryTimestamp());
        console.log("");
        console.log("=== Wait", ROUND_DURATION_SECONDS, "seconds before running SettleMarket ===");

        // Write contract address to file for next steps
        vm.writeFile(string.concat(DATA_DIR, "guesser_address.txt"), vm.toString(address(guesser)));
    }
}

// Step 2: Settle the market after expiry
// Run with command:
// forge script script/adapters/Api3Example.s.sol:SettleMarket --rpc-url $COSTON2_RPC_URL --broadcast

contract SettleMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "guesser_address.txt"));
        address guesserAddress = vm.parseAddress(addressStr);

        PriceGuesser guesser = PriceGuesser(guesserAddress);

        console.log("=== Settling PriceGuesser Market ===");
        console.log("Contract:", guesserAddress);
        console.log("");

        // Check if round has expired
        uint256 expiryTime = guesser.expiryTimestamp();
        uint256 currentTime = block.timestamp;

        console.log("Expiry timestamp:", expiryTime);
        console.log("Current timestamp:", currentTime);

        if (currentTime < expiryTime) {
            uint256 waitTime = expiryTime - currentTime;
            console.log("");
            console.log("Round not yet expired. Wait", waitTime, "more seconds.");
            return;
        }

        console.log("Round has expired. Proceeding with settlement...");
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Refresh the price
        console.log("Refreshing FTSO price...");
        guesser.refresh();

        // Settle the market
        console.log("Settling market...");
        guesser.settle();

        vm.stopBroadcast();

        // Log outcome
        PriceGuesser.Outcome outcome = guesser.outcome();
        string memory outcomeStr = outcome == PriceGuesser.Outcome.Above ? "ABOVE" : "BELOW";

        console.log("");
        console.log("=== Market Settled ===");
        console.log("Outcome: Price was", outcomeStr, "the strike price");
        console.log("");
        console.log("Run ClaimWinnings to claim your rewards.");
    }
}

// Step 3: Claim winnings
// Run with command:
// forge script script/adapters/Api3Example.s.sol:ClaimWinnings --rpc-url $COSTON2_RPC_URL --broadcast

contract ClaimWinnings is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address claimer = vm.addr(deployerPrivateKey);

        // Read contract address from file
        string memory addressStr = vm.readLine(string.concat(DATA_DIR, "guesser_address.txt"));
        address guesserAddress = vm.parseAddress(addressStr);

        PriceGuesser guesser = PriceGuesser(guesserAddress);

        console.log("=== Claiming Winnings ===");
        console.log("Contract:", guesserAddress);
        console.log("Claimer:", claimer);
        console.log("");

        // Check outcome
        PriceGuesser.Outcome outcome = guesser.outcome();
        if (outcome == PriceGuesser.Outcome.Unsettled) {
            console.log("Market not yet settled. Run SettleMarket first.");
            return;
        }

        string memory outcomeStr = outcome == PriceGuesser.Outcome.Above ? "ABOVE" : "BELOW";
        console.log("Market outcome:", outcomeStr);

        // Check user's bets
        uint256 betsAbove = guesser.betsAbove(claimer);
        uint256 betsBelow = guesser.betsBelow(claimer);
        console.log("Your bets above:", betsAbove / 1e18, "tokens");
        console.log("Your bets below:", betsBelow / 1e18, "tokens");

        // Check if already claimed
        if (guesser.hasClaimed(claimer)) {
            console.log("");
            console.log("You have already claimed your winnings.");
            return;
        }

        uint256 balanceBefore = claimer.balance;

        vm.startBroadcast(deployerPrivateKey);

        console.log("");
        console.log("Claiming winnings...");
        guesser.claimWinnings();

        vm.stopBroadcast();

        uint256 balanceAfter = claimer.balance;
        uint256 winnings = balanceAfter - balanceBefore;

        console.log("");
        console.log("=== Winnings Claimed ===");
        console.log("Received:", winnings / 1e18, "tokens");
    }
}
