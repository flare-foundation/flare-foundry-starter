// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";

/**
 * @title IFAssetOFTAdapter
 * @notice Interface for the FAsset OFT Adapter on Coston2
 * @dev Used for bridging FAssets cross-chain via LayerZero
 */
interface IFAssetOFTAdapter {
    /**
     * @notice Sends tokens to another chain
     * @param _sendParam The send parameters
     * @param _fee The messaging fee (obtained from quoteSend)
     * @param _refundAddress Address to refund excess native fee
     * @return msgReceipt The messaging receipt
     * @return oftReceipt The OFT receipt with amounts
     */
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);

    /**
     * @notice Returns the underlying token address
     * @return The token address
     */
    function token() external view returns (address);

    /**
     * @notice Quotes the fee for sending tokens to another chain
     * @param _sendParam The send parameters
     * @param _payInLzToken Whether to pay in LZ token
     * @return msgFee The messaging fee quote
     */
    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory msgFee);
}
