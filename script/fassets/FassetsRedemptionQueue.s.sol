// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { AssetManagerSettings } from "flare-periphery/src/coston2/data/AssetManagerSettings.sol";
import { RedemptionTicketInfo } from "flare-periphery/src/coston2/data/RedemptionTicketInfo.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/fassets/FassetsRedemptionQueue.s.sol:FassetsRedemptionQueue --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL

contract FassetsRedemptionQueue is Script {
    function run() external view {
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();

        AssetManagerSettings.Data memory settings = assetManager.getSettings();

        // Get redemption queue (using maxRedeemedTickets as page size)
        RedemptionTicketInfo.Data[] memory redemptionQueue;
        uint256 nextRedemptionTicketId;
        (redemptionQueue, nextRedemptionTicketId) = assetManager.redemptionQueue(0, settings.maxRedeemedTickets);

        // Sum all ticket values in the redemption queue
        uint256 totalValueUBA = 0;
        for (uint256 i = 0; i < redemptionQueue.length; i++) {
            totalValueUBA += redemptionQueue[i].ticketValueUBA;
        }

        //Calculate total lots in the redemption queue
        // solhint-disable-next-line no-unused-vars
        uint256 totalLots = totalValueUBA / settings.lotSizeAMG;
    }
}
