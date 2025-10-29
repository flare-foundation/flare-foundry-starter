// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { FassetsAgentInfo } from "../../src/fassets/FassetsAgentInfo.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { AvailableAgentInfo } from "flare-periphery/src/coston2/data/AvailableAgentInfo.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/fassets/FAssetsAgentInfo.s.sol:AgentInfo --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_RPC_API_KEY --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API --ffi

contract AgentInfo is Script {
    FassetsAgentInfo public fassetsAgentInfo;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract
        fassetsAgentInfo = new FassetsAgentInfo();

        vm.stopBroadcast();

        // Get FAssets FXRP asset manager on Songbird Testnet Coston2 network
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();

        // Get available agents (first 100 agents)
        (
            AvailableAgentInfo.Data[] memory agents,
            // solhint-disable-next-line no-unused-vars
            uint256 totalLength
        ) = assetManager.getAvailableAgentsDetailedList(0, 100);

        if (agents.length <= 0) {
            return;
        }

        address agentAddress = agents[0].ownerManagementAddress;

        // Call getSettings function
        // solhint-disable-next-line no-unused-vars
        string memory agentName = fassetsAgentInfo.getAgentName(agentAddress);

        // solhint-disable-next-line no-unused-vars
        string memory agentDescription = fassetsAgentInfo.getAgentDescription(agentAddress);

        // solhint-disable-next-line no-unused-vars
        string memory agentIconUrl = fassetsAgentInfo.getAgentIconUrl(agentAddress);

        // solhint-disable-next-line no-unused-vars
        string memory agentTermsOfUseUrl = fassetsAgentInfo.getAgentTermsOfUseUrl(agentAddress);

        (
            // solhint-disable-next-line no-unused-vars
            string memory name,
            // solhint-disable-next-line no-unused-vars
            string memory description,
            // solhint-disable-next-line no-unused-vars
            string memory iconUrl,
            // solhint-disable-next-line no-unused-vars
            string memory termsOfUseUrl
        ) = fassetsAgentInfo.getAgentDetails(agentAddress);
    }
}
