# FTSO Adapter Example Scripts

This directory contains example scripts demonstrating how to use FTSO adapters for third-party oracle protocol integration. Each example deploys an application contract that uses an adapter, then demonstrates the full interaction workflow.

## Prerequisites

```bash
forge install
```

Ensure you have:
- Access to Coston2 testnet RPC
- A wallet with test FLR for gas fees
- `PRIVATE_KEY` set in your environment

## Example Overview

| Protocol | Contract | Description |
|----------|----------|-------------|
| API3 | `PriceGuesser` | Prediction market with price-based settlement |
| Band | `PriceTriggeredSafe` | Vault that locks during high volatility |
| Chainlink | `AssetVault` | Collateralized lending with MUSD |
| Chronicle | `DynamicNftMinter` | NFT minting with price-based tiers |
| Pyth | `PythNftMinter` | NFT minting for $1 worth of asset |

## Running Examples

Each example has a multi-step workflow. Run scripts sequentially:

### API3 Example (Prediction Market)

```bash
# Step 1: Deploy and place bets
forge script script/adapters/Api3Example.s.sol:DeployAndBet --rpc-url $COSTON2_RPC_URL --broadcast

# Step 2: Wait 5 minutes, then settle
forge script script/adapters/Api3Example.s.sol:SettleMarket --rpc-url $COSTON2_RPC_URL --broadcast

# Step 3: Claim winnings
forge script script/adapters/Api3Example.s.sol:ClaimWinnings --rpc-url $COSTON2_RPC_URL --broadcast
```

### Band Example (Volatility Safe)

```bash
# Step 1: Deploy and deposit
forge script script/adapters/BandExample.s.sol:DeployAndDeposit --rpc-url $COSTON2_RPC_URL --broadcast

# Step 2: Wait ~3 minutes, then check volatility
forge script script/adapters/BandExample.s.sol:CheckVolatility --rpc-url $COSTON2_RPC_URL --broadcast

# Step 3a: If locked, unlock and withdraw
forge script script/adapters/BandExample.s.sol:UnlockAndWithdraw --rpc-url $COSTON2_RPC_URL --broadcast

# Step 3b: If not locked, withdraw directly
forge script script/adapters/BandExample.s.sol:WithdrawFunds --rpc-url $COSTON2_RPC_URL --broadcast
```

### Chainlink Example (Collateralized Lending)

```bash
# Step 1: Deploy and deposit collateral
forge script script/adapters/ChainlinkExample.s.sol:DeployAndDeposit --rpc-url $COSTON2_RPC_URL --broadcast

# Step 2: Borrow MUSD against collateral
forge script script/adapters/ChainlinkExample.s.sol:BorrowMUSD --rpc-url $COSTON2_RPC_URL --broadcast

# Step 3: Repay and withdraw
forge script script/adapters/ChainlinkExample.s.sol:RepayAndWithdraw --rpc-url $COSTON2_RPC_URL --broadcast

# Read state (no transaction)
forge script script/adapters/ChainlinkExample.s.sol:ReadVaultState --rpc-url $COSTON2_RPC_URL
```

### Chronicle Example (Dynamic NFT)

```bash
# Step 1: Deploy minter
forge script script/adapters/ChronicleExample.s.sol:DeployMinter --rpc-url $COSTON2_RPC_URL --broadcast

# Step 2: Refresh price and mint NFT
forge script script/adapters/ChronicleExample.s.sol:MintNft --rpc-url $COSTON2_RPC_URL --broadcast

# Read state (no transaction)
forge script script/adapters/ChronicleExample.s.sol:ReadMinterState --rpc-url $COSTON2_RPC_URL
```

### Pyth Example (Price-Based NFT)

```bash
# Step 1: Deploy minter
forge script script/adapters/PythExample.s.sol:DeployMinter --rpc-url $COSTON2_RPC_URL --broadcast

# Step 2: Refresh price and mint NFT
forge script script/adapters/PythExample.s.sol:MintNft --rpc-url $COSTON2_RPC_URL --broadcast

# Read state (no transaction)
forge script script/adapters/PythExample.s.sol:ReadMinterState --rpc-url $COSTON2_RPC_URL
```

## Data Files

Each example stores contract addresses in `data/adapters/<protocol>/` for use in subsequent steps.

## Additional Resources

- **FTSO Docs**: https://dev.flare.network/ftso/overview
- **Contract Source**: `src/adapters/`
