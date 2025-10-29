// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { FAssetsRedeem } from "../../src/fassets/FAssetsRedeem.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/fassets/FAssetsRedeem.s.sol:Redeem --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_RPC_API_KEY --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API --ffi

contract Redeem is Script {
    FAssetsRedeem public fAssetsRedeem;

    // Configuration constants
    uint256 public constant LOTS_TO_REDEEM = 1;
    string public constant UNDERLYING_ADDRESS = "rSHYuiEvsYsKR8uUHhBTuGP5zjRcGt4nm";

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the FAssetsRedeem contract
        fAssetsRedeem = new FAssetsRedeem();

        // Get the lot size and decimals to calculate the amount to redeem
        // solhint-disable-next-line no-unused-vars
        (uint256 lotSize, uint256 decimals) = fAssetsRedeem.getSettings();

        // Calculate the amount to redeem according to the lot size and the number of lots to redeem
        uint256 amountToRedeem = lotSize * LOTS_TO_REDEEM;

        // Get FXRP token address
        address fxrpAddress = fAssetsRedeem.getFXRPAddress();
        IERC20 fxrp = IERC20(fxrpAddress);

        // Approve FXRP for redemption

        fxrp.approve(address(fAssetsRedeem), amountToRedeem);

        // Call redeem function

        // solhint-disable-next-line no-unused-vars
        uint256 redeemedAmountUBA = fAssetsRedeem.redeem(LOTS_TO_REDEEM, UNDERLYING_ADDRESS);

        vm.stopBroadcast();
    }
}
