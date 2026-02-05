// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { IFastUpdater } from "flare-periphery/src/coston2/IFastUpdater.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/ftso/FastUpdates.s.sol:FastUpdates --rpc-url $COSTON2_RPC_URL
contract FastUpdates is Script {
    uint256 public constant HISTORY_SIZE = 10;

    function run() external view {
        // Get FastUpdater contract from registry
        IFastUpdater fastUpdater = ContractRegistry.getFastUpdater();

        console.log("=== FTSO Fast Updates ===");
        console.log("FastUpdater address:", address(fastUpdater));

        // Get submission window
        uint8 submissionWindow = fastUpdater.submissionWindow();
        console.log("Submission window:", uint256(submissionWindow), "blocks");

        // Get current score cutoff
        uint256 scoreCutoff = fastUpdater.currentScoreCutoff();
        console.log("Current score cutoff:", scoreCutoff);

        // Get current reward epoch
        uint24 rewardEpochId = fastUpdater.currentRewardEpochId();
        console.log("Current reward epoch ID:", uint256(rewardEpochId));

        // Get update history
        console.log("");
        console.log("=== Update History (last", HISTORY_SIZE, "blocks) ===");
        uint256[] memory updates = fastUpdater.numberOfUpdates(HISTORY_SIZE);
        for (uint256 i = 0; i < updates.length; i++) {
            console.log("Block -", i);
            console.log("  Updates:", updates[i]);
        }
    }
}
