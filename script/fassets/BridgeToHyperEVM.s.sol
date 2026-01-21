// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { IFAssetOFTAdapter } from "../../src/fassets/interfaces/IFAssetOFTAdapter.sol";
import { SendParam, MessagingFee, MessagingReceipt, OFTReceipt } from "../../src/fassets/interfaces/IOFT.sol";
import { LayerZeroOptionsLib } from "../../src/fassets/lib/LayerZeroOptionsLib.sol";

// Run with command:
// solhint-disable-next-line max-line-length
// forge script script/fassets/BridgeToHyperEVM.s.sol:BridgeToHyperEVM --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast

/**
 * @title BridgeToHyperEVM
 * @notice Script to bridge FXRP from Coston2 to Hyperliquid EVM Testnet
 * @dev Uses LayerZero OFT Adapter for cross-chain transfer
 */
contract BridgeToHyperEVM is Script {
    // Configuration constants
    address public constant COSTON2_OFT_ADAPTER = 0xCd3d2127935Ae82Af54Fc31cCD9D3440dbF46639;
    uint32 public constant HYPERLIQUID_EID = 40362; // HYPERLIQUID_V2_TESTNET
    uint128 public constant EXECUTOR_GAS = 200_000;

    // Lot size: 1 lot = 10 FXRP (10_000_000 in 6 decimals)
    uint256 public constant LOT_SIZE = 10_000_000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(deployerPrivateKey);

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

        // Build LayerZero options (no compose for simple bridge)
        bytes memory options = LayerZeroOptionsLib.buildLzReceiveOptions(EXECUTOR_GAS);

        // Build send parameters - recipient is sender on destination chain
        SendParam memory sendParam = SendParam({
            dstEid: HYPERLIQUID_EID,
            to: bytes32(uint256(uint160(sender))),
            amountLD: amountToBridge,
            minAmountLD: amountToBridge,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        // Quote the fee
        MessagingFee memory fee = oftAdapter.quoteSend(sendParam, false);

        vm.startBroadcast(deployerPrivateKey);

        // Approve OFT Adapter
        fAsset.approve(COSTON2_OFT_ADAPTER, amountToBridge);

        // Execute bridge
        // solhint-disable-next-line no-unused-vars, check-send-result
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = oftAdapter.send{ value: fee.nativeFee }(
            sendParam,
            fee,
            sender
        );

        vm.stopBroadcast();
    }
}
