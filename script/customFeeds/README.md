# Custom Feeds FDC Verification Scripts

This directory contains scripts demonstrating the complete FDC (Flare Data Connector) verification workflow for custom price feeds using Web2Json attestations.

## Prerequisites

```bash
forge install
```

Ensure you have:

- Access to Coston2 testnet RPC
- `PRIVATE_KEY` set in your environment
- `VERIFIER_URL_TESTNET` for attestation preparation
- `COSTON2_DA_LAYER_URL` for proof retrieval
- `X_API_KEY` for DA Layer access

## FDC Verification Workflow

Each verification workflow follows 5 steps:

1. **PrepareAttestationRequest** - Prepare request to verifier
2. **SubmitAttestationRequest** - Submit to FdcHub on-chain
3. **RetrieveDataAndProof** - Get proof from DA Layer
4. **DeployContract** - Deploy custom feed contract
5. **InteractWithContract** - Submit proof to verify data

## Running Scripts

Run each step sequentially:

```bash
# Step 1: Prepare attestation
forge script script/customFeeds/PriceVerification.s.sol:PrepareAttestationRequest \
  --rpc-url $COSTON2_RPC_URL --ffi

# Step 2: Submit to FdcHub (requires broadcast)
forge script script/customFeeds/PriceVerification.s.sol:SubmitAttestationRequest \
  --rpc-url $COSTON2_RPC_URL --broadcast --ffi

# Step 3: Wait ~5 minutes, then retrieve proof
forge script script/customFeeds/PriceVerification.s.sol:RetrieveDataAndProof \
  --rpc-url $COSTON2_RPC_URL --broadcast --ffi

# Step 4: Deploy contract
forge script script/customFeeds/PriceVerification.s.sol:DeployContract \
  --rpc-url $COSTON2_RPC_URL --broadcast --verify \
  --verifier-url $COSTON2_FLARE_EXPLORER_API --ffi

# Step 5: Verify price with proof
forge script script/customFeeds/PriceVerification.s.sol:InteractWithContract \
  --rpc-url $COSTON2_RPC_URL --broadcast --ffi
```

## Available Verification Workflows

| Script                            | Data Source | Description                           |
| --------------------------------- | ----------- | ------------------------------------- |
| `PriceVerification.s.sol`         | CoinGecko   | Historical BTC/USD price verification |
| `MetalPriceVerification.s.sol`    | Swissquote  | Gold (XAU) price verification         |
| `InflationDataVerification.s.sol` | World Bank  | US CPI inflation data verification    |

## Read Scripts

After deployment, read feed data:

| Script                     | Description                            |
| -------------------------- | -------------------------------------- |
| `ReadPriceFeed.s.sol`      | Read from PriceVerifierCustomFeed      |
| `ReadMetalPriceFeed.s.sol` | Read from MetalPriceVerifierCustomFeed |
| `ReadInflationFeed.s.sol`  | Read from InflationCustomFeed          |

```bash
forge script script/customFeeds/ReadPriceFeed.s.sol:ReadPriceFeed \
  --rpc-url $COSTON2_RPC_URL
```

## Data Files

Intermediate data is stored in `data/customFeeds/`:

- `price/` - BTC price verification data
- `metal/` - Metal price verification data
- `inflation/` - Inflation data verification data

## Additional Resources

- **FDC Docs**: https://dev.flare.network/fdc/overview
- **Web2Json Guide**: https://dev.flare.network/fdc/guides/web2json
- **Contract Source**: `src/customFeeds/`
