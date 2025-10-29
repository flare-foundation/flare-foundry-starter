// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { AvailableAgentInfo } from "flare-periphery/src/coston2/data/AvailableAgentInfo.sol";
import { AgentInfo } from "flare-periphery/src/coston2/data/AgentInfo.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/fassets/ReserveCollateral.s.sol:ReserveCollateral --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --ffi

contract ReserveCollateral is Script {
    // Configuration constants
    uint256 public constant LOTS_TO_MINT = 1;
    address public constant ZERO_ADDRESS = address(0);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Initialize the FAssets FXRP AssetManager contract
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();

        // Find the best agent with enough free collateral lots
        address agentVaultAddress = findBestAgent(assetManager, LOTS_TO_MINT);
        require(agentVaultAddress != address(0), "No suitable agent found with enough free collateral lots");

        // Get the agent info
        AgentInfo.Info memory agentInfo = assetManager.getAgentInfo(agentVaultAddress);

        // Get the collateral reservation fee according to the number of lots to reserve
        uint256 collateralReservationFee = assetManager.collateralReservationFee(LOTS_TO_MINT);

        // Reserve collateral
        assetManager.reserveCollateral{ value: collateralReservationFee }(
            agentVaultAddress,
            LOTS_TO_MINT,
            agentInfo.feeBIPS,
            payable(ZERO_ADDRESS) // Not using the executor
        );

        vm.stopBroadcast();

        // Get asset minting decimals for calculations
        // solhint-disable-next-line no-unused-vars
        uint256 decimals = assetManager.assetMintingDecimals();
    }

    /**
     * @dev Find the best agent with enough free collateral lots
     * @param assetManager The asset manager contract
     * @param minAvailableLots Minimum number of lots required
     * @return The address of the best agent vault, or address(0) if none found
     */
    function findBestAgent(IAssetManager assetManager, uint256 minAvailableLots) internal view returns (address) {
        // Get max 100 agents
        (AvailableAgentInfo.Data[] memory agents, ) = assetManager.getAvailableAgentsDetailedList(0, 100);

        // Find agents with enough free collateral lots
        address[] memory suitableAgents = new address[](agents.length);
        uint256 suitableCount = 0;

        for (uint256 i = 0; i < agents.length; i++) {
            if (agents[i].freeCollateralLots >= minAvailableLots) {
                suitableAgents[suitableCount] = agents[i].agentVault;
                suitableCount++;
            }
        }

        if (suitableCount == 0) {
            return address(0);
        }

        // Sort by lowest fee (simple bubble sort for small arrays)
        for (uint256 i = 0; i < suitableCount - 1; i++) {
            for (uint256 j = 0; j < suitableCount - i - 1; j++) {
                AgentInfo.Info memory info1 = assetManager.getAgentInfo(suitableAgents[j]);
                AgentInfo.Info memory info2 = assetManager.getAgentInfo(suitableAgents[j + 1]);

                if (info1.feeBIPS > info2.feeBIPS) {
                    address temp = suitableAgents[j];
                    suitableAgents[j] = suitableAgents[j + 1];
                    suitableAgents[j + 1] = temp;
                }
            }
        }

        // Find the first agent with NORMAL status (status = 0) among the lowest fee agents
        uint256 lowestFee = assetManager.getAgentInfo(suitableAgents[0]).feeBIPS;

        for (uint256 i = 0; i < suitableCount; i++) {
            AgentInfo.Info memory info = assetManager.getAgentInfo(suitableAgents[i]);

            // If we've moved past the lowest fee agents, break
            if (info.feeBIPS > lowestFee) {
                break;
            }

            // Check if agent has NORMAL status (0)
            if (uint256(info.status) == 0) {
                return suitableAgents[i];
            }
        }

        return address(0);
    }
}
