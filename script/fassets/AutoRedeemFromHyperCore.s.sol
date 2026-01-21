// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { IOFT, SendParam, MessagingFee, MessagingReceipt, OFTReceipt } from "../../src/fassets/interfaces/IOFT.sol";
import { LayerZeroOptionsLib } from "../../src/fassets/lib/LayerZeroOptionsLib.sol";

// Run with command:
// solhint-disable-next-line max-line-length
// forge script script/fassets/AutoRedeemFromHyperCore.s.sol:AutoRedeemFromHyperCore --private-key $PRIVATE_KEY --rpc-url $HYPERLIQUID_TESTNET_RPC_URL --broadcast

/**
 * @title AutoRedeemFromHyperCore
 * @notice Script to auto-redeem FXRP from Hyperliquid HyperCore to native XRP
 * @dev This script handles the HyperEVM → Coston2 portion of the flow.
 *
 * IMPORTANT: Before running this script, you must transfer FXRP from HyperCore to HyperEVM.
 * This can be done via:
 * 1. Hyperliquid web UI (Spot → Withdraw to HyperEVM)
 * 2. Hyperliquid API spotSend (requires EIP-712 signing with Arbitrum chainId)
 *
 * Full flow:
 * 1. [Manual/External] Transfer FXRP from HyperCore spot to HyperEVM
 * 2. [This Script] Send FXRP from HyperEVM to Coston2 via LayerZero with compose
 * 3. [Automatic] FAssetRedeemComposer on Coston2 redeems to native XRP
 */
contract AutoRedeemFromHyperCore is Script {
    // Configuration constants
    uint32 public constant COSTON2_EID = 40294; // FLARE_V2_TESTNET
    address public constant HYPERLIQUID_FXRP_OFT = 0x14bfb521e318fc3d5e92A8462C65079BC7d4284c;
    address public constant COSTON2_COMPOSER = 0x5051E8db650E9e0E2a3f03010Ee5c60e79CF583E;

    // Gas configuration
    uint128 public constant EXECUTOR_GAS = 1_000_000;
    uint128 public constant COMPOSE_GAS = 1_000_000;

    // Lot size: 1 lot = 10 FXRP (10_000_000 in 6 decimals)
    uint256 public constant LOT_SIZE = 10_000_000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(deployerPrivateKey);

        // Get configuration from environment
        uint256 sendLots = vm.envOr("SEND_LOTS", uint256(1));
        string memory xrpAddress = vm.envString("XRP_ADDRESS");

        // Calculate amount to send
        uint256 amountToSend = LOT_SIZE * sendLots;

        // Connect to OFT on HyperEVM
        IOFT oft = IOFT(HYPERLIQUID_FXRP_OFT);

        // Check HyperEVM balance
        uint256 balance = oft.balanceOf(sender);
        require(balance >= amountToSend, "Insufficient FXRP on HyperEVM. Transfer from HyperCore first via UI or API.");

        // Build compose message: (amountToSend, underlyingAddress, redeemer)
        bytes memory composeMsg = abi.encode(amountToSend, xrpAddress, sender);

        // Build LayerZero options with compose
        bytes memory options = LayerZeroOptionsLib.buildOptions(EXECUTOR_GAS, 0, COMPOSE_GAS);

        // Build send parameters
        SendParam memory sendParam = SendParam({
            dstEid: COSTON2_EID,
            to: bytes32(uint256(uint160(COSTON2_COMPOSER))),
            amountLD: amountToSend,
            minAmountLD: amountToSend,
            extraOptions: options,
            composeMsg: composeMsg,
            oftCmd: ""
        });

        // Quote the fee
        MessagingFee memory fee = oft.quoteSend(sendParam, false);

        vm.startBroadcast(deployerPrivateKey);

        // Execute send with auto-redeem
        // solhint-disable-next-line no-unused-vars, check-send-result
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = oft.send{ value: fee.nativeFee }(
            sendParam,
            fee,
            sender
        );

        vm.stopBroadcast();
    }
}
