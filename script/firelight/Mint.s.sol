// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */
import { Script, console } from "forge-std/Script.sol";
import { IFirelightVault } from "../../src/firelight/IFirelightVault.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * FirelightVault Mint Script
 *
 * This script mints vault shares (ERC-4626) by depositing assets into the FirelightVault.
 * It checks max mint capacity, calculates required assets, approves tokens, and mints shares.
 *
 * Usage:
 *   forge script script/firelight/Mint.s.sol:Mint --rpc-url $COSTON2_RPC_URL --broadcast
 */
contract Mint is Script {
    address public constant FIRELIGHT_VAULT_ADDRESS = 0x91Bfe6A68aB035DFebb6A770FFfB748C03C0E40B;
    uint256 public constant SHARES_TO_MINT = 1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address account = vm.addr(deployerPrivateKey);

        IFirelightVault vault = IFirelightVault(FIRELIGHT_VAULT_ADDRESS);

        // Get asset info
        address assetAddress = vault.asset();
        IERC20 assetToken = IERC20(assetAddress);
        IERC20Metadata assetMetadata = IERC20Metadata(assetAddress);
        string memory symbol = assetMetadata.symbol();
        uint8 assetDecimals = assetMetadata.decimals();

        // Calculate shares amount
        uint256 sharesAmount = SHARES_TO_MINT * (10 ** assetDecimals);

        // Log mint info
        logMintInfo(account, assetAddress, symbol, assetDecimals, sharesAmount);

        // Validate mint
        uint256 maxMint = vault.maxMint(account);
        console.log("Max mint:", maxMint);
        require(sharesAmount <= maxMint, "Shares amount exceeds max allowed");

        // Calculate assets needed using previewMint
        uint256 assetsNeeded = vault.previewMint(sharesAmount);
        console.log("Assets needed (from previewMint):", assetsNeeded);

        // Check balance
        uint256 balance = assetToken.balanceOf(account);
        console.log("Account balance:", balance);
        require(balance >= assetsNeeded, "Insufficient balance for mint");

        // Execute transactions
        vm.startBroadcast(deployerPrivateKey);

        // Approve tokens
        assetToken.approve(FIRELIGHT_VAULT_ADDRESS, assetsNeeded);
        console.log("Approved tokens for vault");

        // Mint shares
        uint256 assets = vault.mint(sharesAmount, account);
        console.log("Mint successful!");
        console.log("Assets deposited:", assets);

        vm.stopBroadcast();
    }

    function logMintInfo(
        address account,
        address assetAddress,
        string memory symbol,
        uint8 assetDecimals,
        uint256 sharesAmount
    ) internal pure {
        console.log("=== Mint vault shares (ERC-4626) ===");
        console.log("Sender:", account);
        console.log("Vault:", FIRELIGHT_VAULT_ADDRESS);
        console.log("Asset:", assetAddress);
        console.log("Asset symbol:", symbol);
        console.log("Asset decimals:", uint256(assetDecimals));
        console.log("Shares to mint (raw):", sharesAmount);
        console.log("Shares to mint:", SHARES_TO_MINT);
    }
}
