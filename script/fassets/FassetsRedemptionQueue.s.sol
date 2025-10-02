// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {IAssetManager} from "flare-periphery/src/coston2/IAssetManager.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";
import {AssetManagerSettings} from "flare-periphery/src/coston2/data/AssetManagerSettings.sol";
import {RedemptionTicketInfo} from "flare-periphery/src/coston2/data/RedemptionTicketInfo.sol";

// Run with command
// forge script script/fassets/FassetsRedemptionQueue.s.sol:FassetsRedemptionQueue --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL

contract FassetsRedemptionQueue is Script {
  
    function run() view external {
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();

        console.log("Asset manager:", address(assetManager));

        AssetManagerSettings.Data memory settings = assetManager.getSettings();
        console.log("Lot size (AMG):", settings.lotSizeAMG);
        console.log("Max redeemed tickets:", settings.maxRedeemedTickets);


        // Get redemption queue (using maxRedeemedTickets as page size)
        RedemptionTicketInfo.Data[] memory redemptionQueue;
        uint256 nextRedemptionTicketId;
        (redemptionQueue, nextRedemptionTicketId) = assetManager.redemptionQueue(0, settings.maxRedeemedTickets);
        
        console.log("Number of redemption tickets in queue:", redemptionQueue.length);
        console.log("Next ticket ID (0 if no more tickets):", nextRedemptionTicketId);

        // Sum all ticket values in the redemption queue
        uint256 totalValueUBA = 0;
        for (uint256 i = 0; i < redemptionQueue.length; i++) {
            totalValueUBA += redemptionQueue[i].ticketValueUBA;
        }

        console.log("\nTotal value in redemption queue (UBA):", totalValueUBA);

        //Calculate total lots in the redemption queue
        uint256 totalLots = totalValueUBA / settings.lotSizeAMG;
        console.log("\nTotal lots in redemption queue:", totalLots);
    }
}
