# Custom Feed Contracts

Smart contracts for custom price feeds verified through Flare's Data Connector (FDC) using Web2Json attestations.

## Overview

These contracts enable on-chain verification of off-chain data from Web2 APIs. Data is fetched, attested by the FDC network, and verified on-chain through cryptographic proofs.

## Contracts

| Contract | Data Source | Description |
|----------|-------------|-------------|
| `PriceVerifierCustomFeed.sol` | CoinGecko | Historical cryptocurrency prices |
| `MetalPriceVerifierCustomFeed.sol` | Swissquote | Precious metal prices (XAU, XAG) |
| `InflationCustomFeed.sol` | World Bank | Economic inflation data (CPI) |

## How It Works

1. **Off-chain**: API data is fetched and processed
2. **Attestation**: FDC validators attest to the data
3. **Proof**: Merkle proof is generated from DA Layer
4. **Verification**: Contract verifies proof and stores data

```
Web2 API → FDC Validators → DA Layer → Smart Contract
```

## Usage

```solidity
import { PriceVerifierCustomFeed } from "src/customFeeds/PriceVerifierCustomFeed.sol";
import { IWeb2Json } from "flare-periphery/src/coston2/IWeb2Json.sol";

// Deploy with feed configuration
PriceVerifierCustomFeed feed = new PriceVerifierCustomFeed(feedId, "BTC", 2);

// Verify price with FDC proof
feed.verifyPrice(proof);

// Read verified data
(uint256 value, int8 decimals) = feed.getFeedDataView();
```

## Key Features

- **Cryptographic Verification**: All data verified through Merkle proofs
- **Custom Feed IDs**: 0x21 prefix for custom feed category
- **Flexible Data Sources**: Any Web2 API with JSON responses
- **JQ Processing**: Server-side data transformation with jq

## Feed ID Format

Custom feeds use the format: `0x21 + first20bytes(keccak256(feedName))`

Example for "BTC/USD-HIST":
```solidity
bytes21 feedId = bytes21(abi.encodePacked(
    bytes1(0x21),
    bytes20(keccak256("BTC/USD-HIST"))
));
```

## Verification Scripts

See `script/customFeeds/` for the complete FDC verification workflow.

## Additional Resources

- **FDC Docs**: https://dev.flare.network/fdc/overview
- **Web2Json Guide**: https://dev.flare.network/fdc/guides/web2json
- **Custom Feeds**: https://dev.flare.network/ftso/scaling/custom-feeds
