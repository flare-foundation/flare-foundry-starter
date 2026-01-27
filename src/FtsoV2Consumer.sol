// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { TestFtsoV2Interface } from "flare-periphery/src/coston2/TestFtsoV2Interface.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";

/**
 * @title FtsoV2Consumer
 * @notice Example contract for consuming FTSO v2 price feeds
 */
contract FtsoV2Consumer {
    bytes21 public constant FLR_USD_ID = 0x01464c522f55534400000000000000000000000000; // "FLR/USD"

    // Feed IDs, see https://dev.flare.network/ftso/feeds for full list
    bytes21[] public feedIds = [
        bytes21(0x01464c522f55534400000000000000000000000000), // FLR/USD
        bytes21(0x014254432f55534400000000000000000000000000), // BTC/USD
        bytes21(0x014554482f55534400000000000000000000000000) // ETH/USD
    ];

    /**
     * @notice Get FLR/USD price
     * @return value The price value
     * @return decimals The number of decimals
     * @return timestamp The timestamp of the price
     */
    function getFlrUsdPrice() external view returns (uint256 value, int8 decimals, uint64 timestamp) {
        /* THIS IS A TEST METHOD, in production use: ftsoV2 = ContractRegistry.getFtsoV2(); */
        TestFtsoV2Interface ftsoV2 = ContractRegistry.getTestFtsoV2();
        /* Your custom feed consumption logic. In this example the values are just returned. */
        return ftsoV2.getFeedById(FLR_USD_ID);
    }

    /**
     * @notice Get FLR/USD price in wei (18 decimals)
     * @return valueWei The price value in wei
     * @return timestamp The timestamp of the price
     */
    function getFlrUsdPriceWei() external view returns (uint256 valueWei, uint64 timestamp) {
        /* THIS IS A TEST METHOD, in production use: ftsoV2 = ContractRegistry.getFtsoV2(); */
        TestFtsoV2Interface ftsoV2 = ContractRegistry.getTestFtsoV2();
        /* Your custom feed consumption logic. In this example the values are just returned. */
        return ftsoV2.getFeedByIdInWei(FLR_USD_ID);
    }

    /**
     * @notice Get current feed values for multiple feeds (FLR/USD, BTC/USD, ETH/USD)
     * @return _feedValues Array of feed values
     * @return _decimals Array of decimals for each feed
     * @return _timestamp Timestamp of the prices
     */
    function getFtsoV2CurrentFeedValues()
        external
        view
        returns (uint256[] memory _feedValues, int8[] memory _decimals, uint64 _timestamp)
    {
        /* THIS IS A TEST METHOD, in production use: ftsoV2 = ContractRegistry.getFtsoV2(); */
        TestFtsoV2Interface ftsoV2 = ContractRegistry.getTestFtsoV2();
        /* Your custom feed consumption logic. In this example the values are just returned. */
        return ftsoV2.getFeedsById(feedIds);
    }
}
