// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {FAssetsRedeem} from "../../src/fassets/FAssetsRedeem.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IAssetManager} from "flare-periphery/src/coston2/IAssetManager.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";

// Run with command
// forge script script/fassets/FAssetsRedeem.s.sol:Redeem --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_RPC_API_KEY --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API --ffi

contract Redeem is Script {
    FAssetsRedeem public fAssetsRedeem;
    
    // Configuration constants
    uint256 constant lotsToRedeem = 1;
    string constant underlyingAddress = "rSHYuiEvsYsKR8uUHhBTuGP5zjRcGt4nm";

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the FAssetsRedeem contract
        fAssetsRedeem = new FAssetsRedeem();
        console.log("FAssetsRedeem deployed to:", address(fAssetsRedeem));

        // Get the lot size and decimals to calculate the amount to redeem
        (uint256 lotSize, uint256 decimals) = fAssetsRedeem.getSettings();
        console.log("Lot size:", lotSize);
        console.log("Asset decimals:", decimals);

        // Calculate the amount to redeem according to the lot size and the number of lots to redeem
        uint256 amountToRedeem = lotSize * lotsToRedeem;
        console.log("Required FXRP amount:", amountToRedeem);
        console.log("Required amount in base units:", amountToRedeem);

        // Get FXRP token address
        address fxrpAddress = fAssetsRedeem.getFXRPAddress();
        IERC20 fxrp = IERC20(fxrpAddress);
        console.log("FXRP token address:", fxrpAddress);

        // Approve FXRP for redemption
        console.log("Approving FAssetsRedeem contract to spend FXRP...");
        fxrp.approve(address(fAssetsRedeem), amountToRedeem);
        console.log("FXRP approval completed");

        // Call redeem function
        console.log("Calling redeem function...");
        uint256 redeemedAmountUBA = fAssetsRedeem.redeem(lotsToRedeem, underlyingAddress);
        console.log("Redeem transaction completed. Redeemed amount UBA:", redeemedAmountUBA);

        vm.stopBroadcast();
    }
}
