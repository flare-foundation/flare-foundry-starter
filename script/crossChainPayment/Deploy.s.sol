// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {MyNFT} from "../../src/crossChainPayment/NFT.sol";
import {NFTMinter} from "../../src/crossChainPayment/Minter.sol";

contract DeployCrossChainPayment is Script {
    function run() external returns (address nftAddr, address minterAddr) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the NFT contract with the deployer as both admin and initial minter.
        MyNFT nft = new MyNFT(deployerAddress, deployerAddress);
        console.log("MyNFT deployed to:", address(nft));

        // 2. Deploy the Minter contract, linking it to the NFT contract.
        NFTMinter minter = new NFTMinter(nft);
        console.log("NFTMinter deployed to:", address(minter));

        // 3. Grant the MINTER_ROLE on the NFT contract to the new Minter contract.
        bytes32 minterRole = nft.MINTER_ROLE();
        nft.grantRole(minterRole, address(minter));
        console.log("MINTER_ROLE granted to NFTMinter contract.");
        
        // 4. Revoke the MINTER_ROLE from the deployer for security.
        nft.revokeRole(minterRole, deployerAddress);
        console.log("MINTER_ROLE revoked from deployer.");

        vm.stopBroadcast();
        
        return (address(nft), address(minter));
    }
}