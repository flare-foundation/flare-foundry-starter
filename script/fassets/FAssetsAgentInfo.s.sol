// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {FassetsAgentInfo} from "../../src/fassets/FassetsAgentInfo.sol";
import {IAssetManager} from "flare-periphery/src/coston2/IAssetManager.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";
import {AvailableAgentInfo} from "flare-periphery/src/coston2/data/AvailableAgentInfo.sol";

// Run with command
// forge script script/fassets/FAssetsAgentInfo.s.sol:AgentInfo --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL

contract AgentInfo is Script {
    FassetsAgentInfo public fassetsAgentInfo;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract
        fassetsAgentInfo = new FassetsAgentInfo();
        console.log("FassetsAgentInfo deployed to:", address(fassetsAgentInfo));

        vm.stopBroadcast();

        // Get FAssets FXRP asset manager on Songbird Testnet Coston2 network
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();
        
        // Get available agents (first 100 agents)
        (AvailableAgentInfo.Data[] memory agents, uint256 totalLength) = assetManager.getAvailableAgentsDetailedList(0, 100);
        
        console.log("Total agents available:", totalLength);
        console.log("Agents retrieved:", agents.length);
        
        if (agents.length > 0) {
            address agentAddress = agents[0].ownerManagementAddress;
            console.log("Agent management address:", agentAddress);

            // Call getSettings function
            string memory agentName = fassetsAgentInfo.getAgentName(agentAddress);
            console.log("Agent name:", agentName);

            string memory agentDescription = fassetsAgentInfo.getAgentDescription(agentAddress);
            console.log("Agent description:", agentDescription);

            string memory agentIconUrl = fassetsAgentInfo.getAgentIconUrl(agentAddress);
            console.log("Agent icon URL:", agentIconUrl);
        } else {
            console.log("No agents found");
        }
    }
}

// Optional: Separate contract for verification
contract Verify is Script {
    function run() pure external {
        // This can be used to verify the contract after deployment
        // The verification command should be run separately with --verify flag
        console.log("Contract verification should be done with --verify flag");
    }
}
