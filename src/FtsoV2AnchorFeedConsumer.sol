// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { TestFtsoV2Interface } from "flare-periphery/src/coston2/TestFtsoV2Interface.sol";

/**
 * @title FtsoV2AnchorFeedConsumer
 * @notice Example contract for consuming FTSO v2 anchor feeds with proof verification
 * @dev THIS IS AN EXAMPLE CONTRACT. DO NOT USE THIS CODE IN PRODUCTION.
 */
contract FtsoV2AnchorFeedConsumer {
    bytes21 private constant FLR_USD_ID = 0x01464c522f55534400000000000000000000000000;
    bytes21 private constant BTC_USD_ID = 0x014254432f55534400000000000000000000000000;
    bytes21 private constant ETH_USD_ID = 0x014554482f55534400000000000000000000000000;

    mapping(uint32 => mapping(bytes21 => TestFtsoV2Interface.FeedData)) public provenFeeds;

    // Track which feeds have been proven per round for easy enumeration
    mapping(uint32 => bytes21[]) private _provenFeedIdsByRound;
    mapping(uint32 => mapping(bytes21 => bool)) private _isProven;

    event FeedProven(uint32 indexed votingRoundId, bytes21 indexed id, int32 value, uint16 turnoutBIPS, int8 decimals);

    /**
     * @notice Saves a price with proof verification
     * @param data The feed data with proof
     */
    function savePrice(TestFtsoV2Interface.FeedDataWithProof calldata data) external {
        /* THIS IS A TEST METHOD, in production use: ftsoV2 = ContractRegistry.getFtsoV2(); */
        TestFtsoV2Interface ftsoV2 = ContractRegistry.getTestFtsoV2();

        // Step 1: Verify the proof
        require(ftsoV2.verifyFeedData(data), "Invalid proof");

        // Step 2: Ensure the proof is for the desired feedId to avoid manipulation
        require(
            data.body.id == FLR_USD_ID || data.body.id == BTC_USD_ID || data.body.id == ETH_USD_ID,
            "Proof is not for desired feedId"
        );

        // Step 3: Use the feed data with app specific logic
        // Here the feed data is saved
        uint32 roundId = data.body.votingRoundId;
        bytes21 id = data.body.id;
        provenFeeds[roundId][id] = data.body;

        // Record id for enumeration if first time proven in this round
        if (!_isProven[roundId][id]) {
            _isProven[roundId][id] = true;
            _provenFeedIdsByRound[roundId].push(id);
        }

        emit FeedProven(roundId, id, data.body.value, data.body.turnoutBIPS, data.body.decimals);
    }

    /**
     * @notice Returns whether a given feed id has been proven for the round
     * @param votingRoundId The voting round ID
     * @param id The feed ID
     * @return True if the feed has been proven
     */
    function isProven(uint32 votingRoundId, bytes21 id) external view returns (bool) {
        return _isProven[votingRoundId][id];
    }

    /**
     * @notice Returns all feed ids proven for a voting round
     * @param votingRoundId The voting round ID
     * @return Array of proven feed IDs
     */
    function getProvenFeedIds(uint32 votingRoundId) external view returns (bytes21[] memory) {
        return _provenFeedIdsByRound[votingRoundId];
    }

    /**
     * @notice Returns all proven feeds (full FeedData) for a voting round
     * @param votingRoundId The voting round ID
     * @return Array of FeedData structs
     */
    function getProvenFeeds(uint32 votingRoundId) external view returns (TestFtsoV2Interface.FeedData[] memory) {
        bytes21[] memory ids = _provenFeedIdsByRound[votingRoundId];
        TestFtsoV2Interface.FeedData[] memory out = new TestFtsoV2Interface.FeedData[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            out[i] = provenFeeds[votingRoundId][ids[i]];
        }
        return out;
    }
}
