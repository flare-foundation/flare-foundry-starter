// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { IFAssetOFTAdapter } from "../../src/fassets/interfaces/IFAssetOFTAdapter.sol";
import { SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

// Run with command:
// solhint-disable-next-line max-line-length
// forge script script/fassets/BridgeToHyperCore.s.sol:BridgeToHyperCore --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast

/**
 * @title BridgeToHyperCore
 * @notice Script to bridge FXRP from Coston2 to Hyperliquid HyperCore (via HyperEVM)
 * @dev Uses LayerZero with compose to trigger HyperliquidComposer on HyperEVM
 */
contract BridgeToHyperCore is Script {
    using OptionsBuilder for bytes;

    // Configuration constants
    address public constant COSTON2_OFT_ADAPTER = 0xCd3d2127935Ae82Af54Fc31cCD9D3440dbF46639;
    uint32 public constant HYPERLIQUID_EID = 40362; // HYPERLIQUID_V2_TESTNET
    uint128 public constant EXECUTOR_GAS = 200_000;
    uint128 public constant COMPOSE_GAS = 300_000;

    // Lot size: 1 lot = 10 FXRP (10_000_000 in 6 decimals)
    uint256 public constant LOT_SIZE = 10_000_000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(deployerPrivateKey);

        // Get HyperliquidComposer address from environment
        address hyperliquidComposer = vm.envAddress("HYPERLIQUID_COMPOSER");
        require(hyperliquidComposer != address(0), "HYPERLIQUID_COMPOSER not set");

        // Get configuration from environment
        uint256 bridgeLots = vm.envOr("BRIDGE_LOTS", uint256(1));

        // Get fAsset address from ContractRegistry
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();
        address fAssetAddress = address(assetManager.fAsset());
        IERC20 fAsset = IERC20(fAssetAddress);

        // Calculate amount with 10% buffer
        uint256 amountToBridge = (LOT_SIZE * bridgeLots * 11) / 10;

        // Check balance
        uint256 balance = fAsset.balanceOf(sender);
        require(balance >= amountToBridge, "Insufficient FTestXRP balance");

        // Connect to OFT Adapter
        IFAssetOFTAdapter oftAdapter = IFAssetOFTAdapter(COSTON2_OFT_ADAPTER);

        // Build compose message: (amount, recipientAddress) for HyperCore transfer
        bytes memory composeMsg = abi.encode(amountToBridge, sender);

        // Build LayerZero options with compose
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(EXECUTOR_GAS, 0)
            .addExecutorLzComposeOption(0, COMPOSE_GAS, 0);

        // Build send parameters - send to HyperliquidComposer with compose message
        SendParam memory sendParam = SendParam({
            dstEid: HYPERLIQUID_EID,
            to: bytes32(uint256(uint160(hyperliquidComposer))),
            amountLD: amountToBridge,
            minAmountLD: amountToBridge,
            extraOptions: options,
            composeMsg: composeMsg,
            oftCmd: ""
        });

        // Quote the fee
        MessagingFee memory fee = oftAdapter.quoteSend(sendParam, false);

        vm.startBroadcast(deployerPrivateKey);

        // Approve OFT Adapter
        fAsset.approve(COSTON2_OFT_ADAPTER, amountToBridge);

        // Execute bridge with compose
        // solhint-disable-next-line no-unused-vars, check-send-result
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = oftAdapter.send{ value: fee.nativeFee }(
            sendParam,
            fee,
            sender
        );

        vm.stopBroadcast();
    }
}
