// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

// Run with command:
// solhint-disable-next-line max-line-length
// forge script script/fassets/AutoRedeemFromSepolia.s.sol:AutoRedeemFromSepolia --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL --broadcast

/**
 * @title AutoRedeemFromSepolia
 * @notice Script to send FXRP from Sepolia to Coston2 with automatic redemption
 * @dev Uses LayerZero compose to trigger automatic redemption on Coston2
 */
contract AutoRedeemFromSepolia is Script {
    using OptionsBuilder for bytes;

    // Configuration constants
    uint32 public constant COSTON2_EID = 40294; // FLARE_V2_TESTNET
    address public constant SEPOLIA_FXRP_OFT = 0x81672c5d42F3573aD95A0bdfBE824FaaC547d4E6;
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

        // Connect to OFT
        IOFT oft = IOFT(SEPOLIA_FXRP_OFT);

        // Check balance using the underlying token
        uint256 balance = IERC20(oft.token()).balanceOf(sender);
        require(balance >= amountToSend, "Insufficient FXRP balance");

        // Build compose message: (amountToSend, underlyingAddress, redeemer)
        bytes memory composeMsg = abi.encode(amountToSend, xrpAddress, sender);

        // Build LayerZero options with compose
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(EXECUTOR_GAS, 0)
            .addExecutorLzComposeOption(0, COMPOSE_GAS, 0);

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

        // Execute send with auto-redeem (not a low-level send, but an OFT external function)
        // solhint-disable-next-line no-unused-vars, check-send-result
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = oft.send{ value: fee.nativeFee }(
            sendParam,
            fee,
            sender
        );

        vm.stopBroadcast();
    }
}
