// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { FAssetRedeemComposer } from "../../src/fassets/FAssetRedeemComposer.sol";

// Run with command:
// solhint-disable-next-line max-line-length
// forge script script/fassets/DeployFAssetRedeemComposer.s.sol:DeployFAssetRedeemComposer --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --verify --verifier blockscout --verifier-url $COSTON2_EXPLORER_API

contract DeployFAssetRedeemComposer is Script {
    // LayerZero Endpoint V2 on Coston2
    address public constant LZ_ENDPOINT_COSTON2 = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // solhint-disable-next-line no-unused-vars
        FAssetRedeemComposer composer = new FAssetRedeemComposer(LZ_ENDPOINT_COSTON2);

        vm.stopBroadcast();
    }
}
