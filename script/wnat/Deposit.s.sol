// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { IWNat } from "flare-periphery/src/coston2/IWNat.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/wnat/Deposit.s.sol:Deposit --rpc-url $COSTON2_RPC_URL --broadcast --private-key $PRIVATE_KEY
contract Deposit is Script {
    uint256 public constant DEPOSIT_AMOUNT = 0.1 ether;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address account = vm.addr(deployerPrivateKey);

        // Get WNat contract from registry
        IWNat wnat = ContractRegistry.getWNat();
        address wnatAddress = address(wnat);

        console.log("=== WNAT Deposit ===");
        console.log("WNat address:", wnatAddress);
        console.log("Account:", account);

        // Get initial balance
        uint256 initialBalance = IERC20(wnatAddress).balanceOf(account);
        console.log("Initial WNAT balance:", initialBalance);

        // Deposit native token
        vm.startBroadcast(deployerPrivateKey);
        wnat.deposit{ value: DEPOSIT_AMOUNT }();
        vm.stopBroadcast();

        // Get final balance
        uint256 finalBalance = IERC20(wnatAddress).balanceOf(account);

        console.log("Deposit amount:", DEPOSIT_AMOUNT);
        console.log("Final WNAT balance:", finalBalance);
        console.log("Balance change:", finalBalance - initialBalance);
    }
}
