// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IOFT
 * @notice Minimal interface for LayerZero OFT (Omnichain Fungible Token) interactions
 * @dev Extracted from LayerZero oft-evm for cross-chain token operations
 */

struct SendParam {
    uint32 dstEid; // Destination endpoint ID
    bytes32 to; // Recipient address (padded to bytes32)
    uint256 amountLD; // Amount in local decimals
    uint256 minAmountLD; // Minimum amount to receive
    bytes extraOptions; // Additional LayerZero options
    bytes composeMsg; // Compose message for destination
    bytes oftCmd; // OFT command bytes
}

struct MessagingFee {
    uint256 nativeFee; // Native token fee
    uint256 lzTokenFee; // LayerZero token fee (if applicable)
}

struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct OFTReceipt {
    uint256 amountSentLD;
    uint256 amountReceivedLD;
}

interface IOFT {
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
     * @notice Quotes the fee for sending tokens to another chain
     * @param _sendParam The send parameters
     * @param _payInLzToken Whether to pay in LZ token
     * @return msgFee The messaging fee quote
     */
    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory msgFee);

    /**
     * @notice Returns the token balance of an account
     * @param account The account address
     * @return The balance
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Returns the token decimals
     * @return The decimals
     */
    function decimals() external view returns (uint8);
}
