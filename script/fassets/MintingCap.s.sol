// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { AssetManagerSettings } from "flare-periphery/src/coston2/data/AssetManagerSettings.sol";
import { AgentInfo } from "flare-periphery/src/coston2/data/AgentInfo.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Run with command
// forge script script/fassets/MintingCap.s.sol:MintingCapScript --rpc-url $COSTON2_RPC_URL --ffi

contract MintingCapScript is Script {
    function run() external view {
        // ============================================
        // 1. Fetch the FXRP Asset Manager Settings
        // ============================================
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();
        AssetManagerSettings.Data memory settings = assetManager.getSettings();

        // Calculate lot size in UBA (Underlying Blockchain Amount)
        uint256 lotSizeUBA = uint256(settings.lotSizeAMG) * uint256(settings.assetMintingGranularityUBA);

        // Calculate minting cap in UBA
        uint256 mintingCap = uint256(settings.mintingCapAMG) * uint256(settings.assetMintingGranularityUBA);

        // Get the asset decimals
        uint256 assetDecimals = uint256(settings.assetDecimals);

        // ============================================
        // 2. Get Current Total FXRP Supply
        // ============================================
        IERC20Metadata fxrp = IERC20Metadata(settings.fAsset);
        uint256 fxrpDecimals = fxrp.decimals();
        uint256 totalSupply = fxrp.totalSupply();

        // solhint-disable-next-line no-unused-vars
        uint256 formattedSupply = (totalSupply * 1000000) / (10 ** fxrpDecimals);

        // Calculate how many lots have been minted
        // solhint-disable-next-line no-unused-vars
        uint256 mintedLots = totalSupply / lotSizeUBA;

        // ============================================
        // 3. Calculate Available FXRP Minting Capacity
        // ============================================

        // solhint-disable-next-line no-unused-vars
        (address[] memory agents, uint256 totalLength) = assetManager.getAllAgents(0, 100);

        uint256 availableToMintLots = 0;
        uint256 totalMintedReservedUBA = 0;

        // Loop through all agents to calculate available capacity
        for (uint256 i = 0; i < agents.length; i++) {
            AgentInfo.Info memory info = assetManager.getAgentInfo(agents[i]);

            // Track total minted and reserved amounts across all agents
            totalMintedReservedUBA += info.mintedUBA + info.reservedUBA;

            // Only count agents that are active and publicly available
            // Status NORMAL or LIQUIDATION
            bool isAgentActiveOrLiquidation = (info.status == AgentInfo.Status.NORMAL ||
                info.status == AgentInfo.Status.LIQUIDATION);
            bool isPubliclyAvailable = info.publiclyAvailable == true;

            if (isAgentActiveOrLiquidation && isPubliclyAvailable) {
                availableToMintLots += info.freeCollateralLots;
            }
        }

        // ============================================
        // 4. If FXRP minting cap is set
        // ============================================
        if (mintingCap > 0) {
            // Calculate remaining capacity under the cap
            uint256 remainingCapacityUBA = mintingCap - totalSupply;

            // Convert remaining capacity to lots
            uint256 remainingCapacityLots = remainingCapacityUBA / lotSizeUBA;

            // The actual available lots is the minimum of:
            // * The remaining capacity under the cap
            // * The free collateral available from agents
            if (remainingCapacityLots < availableToMintLots) {
                availableToMintLots = remainingCapacityLots;
            }
        }

        // ============================================
        // 5. Display Results with Progress Bar
        // ============================================

        // solhint-disable-next-line no-unused-vars
        uint256 mintingCapLots = mintingCap / lotSizeUBA;

        // solhint-disable-next-line no-unused-vars
        uint256 formattedMintingCap = (mintingCap * 1000000) / (10 ** assetDecimals);

        // Calculate usage percentage
        if (mintingCap > 0) {
            uint256 usedAmount = totalSupply;
            uint256 remainingAmount = mintingCap - totalSupply;
            uint256 usagePercentage = (usedAmount * 10000) / mintingCap; // In basis points (0.01%)
            // solhint-disable-next-line no-unused-vars
            uint256 remainingPercentage = 10000 - usagePercentage;

            // solhint-disable-next-line no-unused-vars
            uint256 usedFormatted = (usedAmount * 1000000) / (10 ** assetDecimals);
            // solhint-disable-next-line no-unused-vars
            uint256 remainingFormatted = (remainingAmount * 1000000) / (10 ** assetDecimals);

            // Create visual progress bar
            _printProgressBar(usagePercentage);
        } else {}
    }

    function _formatDecimalNumber(
        uint256 value,
        uint256 scaleFactor,
        uint256 decimals
    ) internal pure returns (string memory) {
        uint256 integerPart = value / (10 ** scaleFactor);
        uint256 fractionalPart = value % (10 ** scaleFactor);

        // Adjust fractional part to match decimal precision
        uint256 displayDecimals = decimals < scaleFactor ? decimals : scaleFactor;
        fractionalPart = fractionalPart / (10 ** (scaleFactor - displayDecimals));

        return string(abi.encodePacked(_toString(integerPart), ".", _toStringPadded(fractionalPart, displayDecimals)));
    }

    function _formatPercentage(uint256 basisPoints) internal pure returns (string memory) {
        uint256 integerPart = basisPoints / 100;
        uint256 fractionalPart = basisPoints % 100;

        return string(abi.encodePacked(_toString(integerPart), ".", _toStringPadded(fractionalPart, 2), "%"));
    }

    function _printProgressBar(uint256 usagePercentageBIPS) internal pure {
        uint256 barLength = 50;
        uint256 filledLength = (usagePercentageBIPS * barLength) / 10000;

        bytes memory progressBar = new bytes(barLength);
        for (uint256 i = 0; i < barLength; i++) {
            if (i < filledLength) {
                progressBar[i] = bytes1(0xE2); // Start of UTF-8 full block character
            } else {
                progressBar[i] = bytes1(0xE2); // Start of UTF-8 light shade character
            }
        }
    }

    function _getProgressBarChars(uint256 filled, uint256 empty) internal pure returns (bytes memory) {
        bytes memory result = new bytes(filled + empty);
        uint256 pos = 0;

        // Add filled blocks (using '#' as a simple character)
        for (uint256 i = 0; i < filled; i++) {
            result[pos++] = bytes1(uint8(0x23)); // '#'
        }

        // Add empty blocks (using '-' as a simple character)
        for (uint256 i = 0; i < empty; i++) {
            result[pos++] = bytes1(uint8(0x2D)); // '-'
        }

        return result;
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _toStringPadded(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(length);
        for (uint256 i = length; i > 0; i--) {
            buffer[i - 1] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
