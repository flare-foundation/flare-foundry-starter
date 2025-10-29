// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { FAssetsSwapAndRedeem } from "../../src/fassets/FAssetsSwapAndRedeem.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/fassets/FAssetsSwapAndRedeem.s.sol:SwapAndRedeem --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_RPC_API_KEY --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API --ffi

contract SwapAndRedeem is Script {
    FAssetsSwapAndRedeem public swapAndRedeemContract;

    // Configuration constants
    uint256 public constant LOTS_TO_REDEEM = 1;
    string public constant UNDERLYING_ADDRESS = "rSHYuiEvsYsKR8uUHhBTuGP5zjRcGt4nm";

    // BlazeSwap router address on Flare Testnet Coston2 network
    address public constant SWAP_ROUTER_ADDRESS = 0x8D29b61C41CF318d15d031BE2928F79630e068e6;
    address public constant WC2FLR = 0xC67DCE33D7A8efA5FfEB961899C73fe01bCe9273;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Get the asset manager to get the FXRP address
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();
        address fassetAddress = address(assetManager.fAsset());

        // Create swap path: WC2FLR -> FXRP
        address[] memory swapPath = new address[](2);
        swapPath[0] = WC2FLR;
        swapPath[1] = fassetAddress;

        // Deploy the SwapAndRedeem contract
        swapAndRedeemContract = new FAssetsSwapAndRedeem(SWAP_ROUTER_ADDRESS, swapPath);

        // Calculate the amounts needed for redemption
        // solhint-disable-next-line no-unused-vars
        (uint256 amountIn, uint256 amountOut) = swapAndRedeemContract.calculateRedemptionAmountIn(LOTS_TO_REDEEM);

        // Get WCFLR token
        IERC20 wcflr = IERC20(WC2FLR);

        // Approve WCFLR for the swap and redeem contract

        wcflr.approve(address(swapAndRedeemContract), amountIn);

        // Execute swap and redeem

        (
            // solhint-disable-next-line no-unused-vars
            uint256 amountOutResult,
            // solhint-disable-next-line no-unused-vars
            uint256 deadline,
            uint256[] memory amountsSent,
            uint256[] memory amountsRecv,
            // solhint-disable-next-line no-unused-vars
            uint256 redeemedAmountUBA
        ) = swapAndRedeemContract.swapAndRedeem(LOTS_TO_REDEEM, UNDERLYING_ADDRESS);

        // Log amounts sent array

        for (uint256 i = 0; i < amountsSent.length; i++) {}

        // Log amounts received array

        for (uint256 i = 0; i < amountsRecv.length; i++) {}

        vm.stopBroadcast();
    }
}
