// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title LayerZeroOptionsLib
 * @notice Library for building LayerZero executor options
 * @dev Translates the Options.newOptions().addExecutorLzReceiveOption().addExecutorComposeOption()
 *      pattern from LayerZero lz-v2-utilities to pure Solidity
 *
 * Options format (Type 3 - Executor options):
 * - uint16: OPTIONS_TYPE (3 for executor options)
 * - For each option:
 *   - uint8: worker ID (1 = executor)
 *   - uint16: option size (size of option data)
 *   - bytes: option data
 *
 * LzReceive option (type 1) when value=0:
 * - uint8: option type (1)
 * - uint128: gas limit
 * Total: 17 bytes
 *
 * LzReceive option (type 1) when value>0:
 * - uint8: option type (1)
 * - uint128: gas limit
 * - uint128: native drop value
 * Total: 33 bytes
 *
 * Compose option (type 3):
 * - uint8: option type (3)
 * - uint16: compose index
 * - uint128: gas limit
 * Total: 19 bytes (when value=0)
 */
library LayerZeroOptionsLib {
    uint16 private constant OPTIONS_TYPE_3 = 3;
    uint8 private constant WORKER_ID_EXECUTOR = 1;

    uint8 private constant OPTION_TYPE_LZRECEIVE = 1;
    uint8 private constant OPTION_TYPE_COMPOSE = 3;

    /**
     * @notice Builds LayerZero options with lzReceive and compose options
     * @param _executorGas Gas limit for the lzReceive execution
     * @param _composeIndex Index of the compose message (usually 0)
     * @param _composeGas Gas limit for the compose execution
     * @return options The encoded options bytes
     */
    function buildOptions(
        uint128 _executorGas,
        uint16 _composeIndex,
        uint128 _composeGas
    ) internal pure returns (bytes memory options) {
        // Build lzReceive option (17 bytes when value=0)
        // Format: [workerId:1][size:2][type:1][gas:16]
        bytes memory lzReceiveOption = abi.encodePacked(
            WORKER_ID_EXECUTOR,
            uint16(17), // option size: 1 (type) + 16 (gas)
            OPTION_TYPE_LZRECEIVE,
            _executorGas
        );

        // Build compose option (19 bytes when value=0)
        // Format: [workerId:1][size:2][type:1][index:2][gas:16]
        bytes memory composeOption = abi.encodePacked(
            WORKER_ID_EXECUTOR,
            uint16(19), // option size: 1 (type) + 2 (index) + 16 (gas)
            OPTION_TYPE_COMPOSE,
            _composeIndex,
            _composeGas
        );

        // Combine with options type header
        options = abi.encodePacked(OPTIONS_TYPE_3, lzReceiveOption, composeOption);
    }

    /**
     * @notice Builds LayerZero options with only lzReceive option (no compose)
     * @param _executorGas Gas limit for the lzReceive execution
     * @return options The encoded options bytes
     */
    function buildLzReceiveOptions(uint128 _executorGas) internal pure returns (bytes memory options) {
        // Build lzReceive option (17 bytes when value=0)
        // Format: [workerId:1][size:2][type:1][gas:16]
        bytes memory lzReceiveOption = abi.encodePacked(
            WORKER_ID_EXECUTOR,
            uint16(17), // option size: 1 (type) + 16 (gas)
            OPTION_TYPE_LZRECEIVE,
            _executorGas
        );

        options = abi.encodePacked(OPTIONS_TYPE_3, lzReceiveOption);
    }
}
