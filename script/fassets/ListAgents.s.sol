// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { AgentInfo } from "flare-periphery/src/coston2/data/AgentInfo.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/fassets/ListAgents.s.sol:ListAgents --rpc-url $COSTON2_RPC_URL

contract ListAgents is Script {
    // Number of agents to fetch per request
    uint256 public constant CHUNK_SIZE = 10;

    function run() external view {
        // Get FAssets FXRP asset manager on Coston2 network
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();

        console.log("=== FAssets Agents List ===");
        console.log("Chunk size:", CHUNK_SIZE);

        // Fetch first chunk to get total count
        (address[] memory firstAgents, uint256 totalLength) = assetManager.getAvailableAgentsList(0, CHUNK_SIZE);

        console.log("Total agents available:", totalLength);
        console.log("");

        if (totalLength == 0) {
            console.log("No agents available");
            return;
        }

        // Process first chunk
        processAgentChunk(assetManager, firstAgents, 0);

        // Fetch remaining agents in chunks
        for (uint256 offset = CHUNK_SIZE; offset < totalLength; offset += CHUNK_SIZE) {
            uint256 endIndex = offset + CHUNK_SIZE;
            if (endIndex > totalLength) {
                endIndex = totalLength;
            }

            (address[] memory agents, ) = assetManager.getAvailableAgentsList(offset, endIndex);
            processAgentChunk(assetManager, agents, offset);
        }

        console.log("");
        console.log("=== Completed listing all", totalLength, "agents ===");
    }

    function processAgentChunk(IAssetManager assetManager, address[] memory agents, uint256 startIndex) internal view {
        for (uint256 i = 0; i < agents.length; i++) {
            address agentVault = agents[i];
            uint256 agentIndex = startIndex + i;

            console.log("--- Agent", agentIndex, "---");
            console.log("Vault Address:", agentVault);

            // Get detailed agent info
            AgentInfo.Info memory info = assetManager.getAgentInfo(agentVault);

            console.log("Owner Management:", info.ownerManagementAddress);
            console.log("Status:", uint256(info.status));
            console.log("Free Collateral Lots:", info.freeCollateralLots);
            console.log("Minted UBA:", info.mintedUBA);
            console.log("Reserved UBA:", info.reservedUBA);
            console.log("Redeeming UBA:", info.redeemingUBA);
            console.log("Fee (BIPS):", info.feeBIPS);
            console.log("");
        }
    }
}
