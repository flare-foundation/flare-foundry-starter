// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {TestFtsoV2Interface} from "lib/flare-foundry-periphery-package/src/coston2/TestFtsoV2Interface.sol";
import {ContractRegistry} from "lib/flare-foundry-periphery-package/src/coston2/ContractRegistry.sol";
import {IFtsoFeedIdConverter} from "lib/flare-foundry-periphery-package/src/coston2/IFtsoFeedIdConverter.sol";
import {IFastUpdatesConfiguration} from "lib/flare-foundry-periphery-package/src/coston2/IFastUpdatesConfiguration.sol";

contract FtsoV2FeedConsumer {
    TestFtsoV2Interface internal ftsoV2;
    IFtsoFeedIdConverter internal feedIdConverter;
    bytes21 public flrUsdId = 0x01464c522f55534400000000000000000000000000;

    constructor() {
        ftsoV2 = ContractRegistry.getTestFtsoV2();
        feedIdConverter = ContractRegistry.getFtsoFeedIdConverter();
    }

    function getFlrUsdPrice() external view returns (uint256, int8, uint64) {
        (uint256 feedValue, int8 decimals, uint64 timestamp) = ftsoV2
            .getFeedById(flrUsdId);

        return (feedValue, decimals, timestamp);
    }

    function getFeedPrice(
        bytes21 feedId
    ) external view returns (uint256, int8, uint64) {
        (uint256 feedValue, int8 decimals, uint64 timestamp) = ftsoV2
            .getFeedById(feedId);

        return (feedValue, decimals, timestamp);
    }

    function getFeedPriceByName(
        string memory feedName
    ) external view returns (uint256, int8, uint64) {
        // 01 for crypto feeds
        bytes21 feedId = feedIdConverter.getFeedId(1, feedName);
        (uint256 feedValue, int8 decimals, uint64 timestamp) = ftsoV2
            .getFeedById(feedId);

        return (feedValue, decimals, timestamp);
    }
    /*
     * @dev Returns the available price feeds (via their feedIds)
     */
    function getAvailablePriceFeeds() public view returns (bytes21[] memory) {
        IFastUpdatesConfiguration fastUpdatesConfiguration = ContractRegistry
            .getFastUpdatesConfiguration();

        IFastUpdatesConfiguration.FeedConfiguration[]
            memory feedConfigurations = fastUpdatesConfiguration
                .getFeedConfigurations();

        bytes21[] memory rtr = new bytes21[](feedConfigurations.length);
        for (uint256 i = 0; i < feedConfigurations.length; i++) {
            rtr[i] = feedConfigurations[i].feedId;
        }
        return rtr;
    }
    /**
     * @dev Returns the human readable names of the available price feeds
     */
    function getAvailablePriceFeedNames()
        public
        view
        returns (string[] memory feedNames)
    {
        bytes21[] memory feedIds = getAvailablePriceFeeds();
        feedNames = new string[](feedIds.length);
        for (uint256 i = 0; i < feedIds.length; i++) {
            feedNames[i] = string(abi.encodePacked(feedIds[i]));
        }
    }
}
