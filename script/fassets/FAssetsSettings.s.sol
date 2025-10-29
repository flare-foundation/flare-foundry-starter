// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { FAssetsSettings } from "../../src/fassets/FAssetsSettings.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/fassets/FAssetsSettings.s.sol:Deploy --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_RPC_API_KEY --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API --ffi

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the FAssetsSettings contract
        FAssetsSettings fAssetsSettings = new FAssetsSettings();

        // Get lot size and decimals
        // solhint-disable-next-line no-unused-vars
        (uint64 lotSizeAMG, uint8 assetDecimals) = fAssetsSettings.getLotSize();

        vm.stopBroadcast();
    }
}
