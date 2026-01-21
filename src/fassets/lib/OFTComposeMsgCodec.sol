// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title OFTComposeMsgCodec
 * @notice Library for encoding and decoding OFT compose messages
 * @dev Extracted from @layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol
 *
 * The compose message format is:
 * - nonce (8 bytes)
 * - srcEid (4 bytes)
 * - amountLD (32 bytes) - amount in local decimals
 * - composeMsg (variable) - the custom compose message
 */
library OFTComposeMsgCodec {
    uint8 private constant NONCE_OFFSET = 8;
    uint8 private constant SRC_EID_OFFSET = 12;
    uint8 private constant AMOUNT_LD_OFFSET = 44;
    uint8 private constant COMPOSE_MSG_OFFSET = 44;

    /**
     * @notice Extracts the nonce from the compose message
     * @param _msg The compose message
     * @return The nonce
     */
    function nonce(bytes calldata _msg) internal pure returns (uint64) {
        return uint64(bytes8(_msg[:NONCE_OFFSET]));
    }

    /**
     * @notice Extracts the source endpoint ID from the compose message
     * @param _msg The compose message
     * @return The source endpoint ID
     */
    function srcEid(bytes calldata _msg) internal pure returns (uint32) {
        return uint32(bytes4(_msg[NONCE_OFFSET:SRC_EID_OFFSET]));
    }

    /**
     * @notice Extracts the amount in local decimals from the compose message
     * @param _msg The compose message
     * @return The amount in local decimals
     */
    function amountLD(bytes calldata _msg) internal pure returns (uint256) {
        return uint256(bytes32(_msg[SRC_EID_OFFSET:AMOUNT_LD_OFFSET]));
    }

    /**
     * @notice Extracts the compose message payload
     * @param _msg The full message
     * @return The compose message payload
     */
    function composeMsg(bytes calldata _msg) internal pure returns (bytes memory) {
        return _msg[COMPOSE_MSG_OFFSET:];
    }
}
