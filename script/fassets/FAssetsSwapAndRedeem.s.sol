// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {FAssetsSwapAndRedeem} from "../../src/fassets/FAssetsSwapAndRedeem.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";
import {IAssetManager} from "flare-periphery/src/coston2/IAssetManager.sol";

// Run with command
// forge script script/fassets/FAssetsSwapAndRedeem.s.sol:SwapAndRedeem --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_RPC_API_KEY --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API --ffi

contract SwapAndRedeem is Script {
    FAssetsSwapAndRedeem public swapAndRedeemContract;
    
    // Configuration constants
    uint256 constant LOTS_TO_REDEEM = 1;
    string constant UNDERLYING_ADDRESS = "rSHYuiEvsYsKR8uUHhBTuGP5zjRcGt4nm";

    // BlazeSwap router address on Flare Testnet Coston2 network
    address constant SWAP_ROUTER_ADDRESS = 0x8D29b61C41CF318d15d031BE2928F79630e068e6;
    address constant WC2FLR = 0xC67DCE33D7A8efA5FfEB961899C73fe01bCe9273;

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
        console.log("FAssetsSwapAndRedeem deployed to:", address(swapAndRedeemContract));

        // Calculate the amounts needed for redemption
        (uint256 amountIn, uint256 amountOut) = swapAndRedeemContract.calculateRedemptionAmountIn(LOTS_TO_REDEEM);
        console.log("Amount of tokens out (FXRP):", amountOut);
        console.log("Amount of tokens in (WCFLR):", amountIn);

        // Get WCFLR token
        IERC20 wcflr = IERC20(WC2FLR);

        // Approve WCFLR for the swap and redeem contract
        console.log("Approving WCFLR for SwapAndRedeem contract...");
        wcflr.approve(address(swapAndRedeemContract), amountIn);
        console.log("WCFLR approval completed");

        // Execute swap and redeem
        console.log("Executing swap and redeem...");
        (
            uint256 amountOutResult,
            uint256 deadline,
            uint256[] memory amountsSent,
            uint256[] memory amountsRecv,
            uint256 redeemedAmountUBA
        ) = swapAndRedeemContract.swapAndRedeem(LOTS_TO_REDEEM, UNDERLYING_ADDRESS);
        
        console.log("Swap and redeem completed!");
        console.log("Amount out (FXRP):", amountOutResult);
        console.log("Deadline:", deadline);
        console.log("Redeemed amount UBA:", redeemedAmountUBA);
        
        // Log amounts sent array
        console.log("Amounts sent array length:", amountsSent.length);
        for (uint i = 0; i < amountsSent.length; i++) {
            console.log("Amount sent [", i, "]:", amountsSent[i]);
        }
        
        // Log amounts received array
        console.log("Amounts received array length:", amountsRecv.length);
        for (uint i = 0; i < amountsRecv.length; i++) {
            console.log("Amount received [", i, "]:", amountsRecv[i]);
        }

        vm.stopBroadcast();
    }
}
