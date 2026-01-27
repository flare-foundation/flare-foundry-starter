// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { FtsoExample } from "src/FtsoExample.sol";

// Run with command
// solhint-disable-next-line max-line-length
// forge script script/ftso/TryDeployment.s.sol:TryDeployment --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast
// With verification:
// solhint-disable-next-line max-line-length
// forge script script/ftso/TryDeployment.s.sol:TryDeployment --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --verify --verifier-url $COSTON2_FLARE_EXPLORER_API
contract TryDeployment is Script {
    FtsoExample public ftsoExample;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== FTSO Example Deployment ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);

        ftsoExample = new FtsoExample();

        vm.stopBroadcast();

        console.log("FtsoExample deployed to:", address(ftsoExample));
        console.log("");
        console.log("Deployment complete.");
    }
}
