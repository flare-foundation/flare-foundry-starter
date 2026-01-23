// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { HyperliquidComposer } from "../../src/fassets/HyperliquidComposer.sol";

// Run with command:
// solhint-disable-next-line max-line-length
// forge script script/fassets/DeployHyperliquidComposer.s.sol:DeployHyperliquidComposer --private-key $PRIVATE_KEY --rpc-url $HYPERLIQUID_TESTNET_RPC_URL --broadcast

/**
 * @title DeployHyperliquidComposer
 * @notice Deploy HyperliquidComposer contract on HyperEVM
 * @dev This contract receives tokens via LayerZero and forwards them to HyperCore.
 */
contract DeployHyperliquidComposer is Script {
    // LayerZero Endpoint V2 on HyperEVM (same address for testnet and mainnet)
    address public constant LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;

    // FXRP OFT on HyperEVM Testnet
    address public constant HYPERLIQUID_FXRP_OFT = 0x14bfb521e318fc3d5e92A8462C65079BC7d4284c;

    // Hyperliquid system address for FXRP (testnet)
    // Format: 0x20 + zeros + token_index (big-endian)
    // Testnet FXRP: index 1443 = 0x5A3
    address public constant FXRP_SYSTEM_ADDRESS = 0x20000000000000000000000000000000000005A3;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // solhint-disable-next-line no-unused-vars
        HyperliquidComposer composer = new HyperliquidComposer(LZ_ENDPOINT, HYPERLIQUID_FXRP_OFT, FXRP_SYSTEM_ADDRESS);

        vm.stopBroadcast();
    }
}
