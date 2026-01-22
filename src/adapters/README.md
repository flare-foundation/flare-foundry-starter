# FTSO Adapter Contracts

Smart contracts that bridge third-party oracle protocols to Flare's native FTSO (Flare Time Series Oracle) system.

## Overview

These adapters allow protocols built on other oracle standards to seamlessly integrate with Flare's FTSO. Each adapter implements the `IFtsoFeedIdConverter` interface to provide FTSO-compatible price feeds.

## Contracts

| Contract | Protocol | Description |
|----------|----------|-------------|
| `Api3FtsoAdapter.sol` | API3 | Bridges API3 dAPI feeds to FTSO format |
| `BandFtsoAdapter.sol` | Band Protocol | Bridges Band reference data to FTSO format |
| `ChainlinkFtsoAdapter.sol` | Chainlink | Bridges Chainlink price feeds to FTSO format |
| `ChronicleFtsoAdapter.sol` | Chronicle | Bridges Chronicle oracles to FTSO format |
| `PythFtsoAdapter.sol` | Pyth Network | Bridges Pyth price feeds to FTSO format |

## Usage

Each adapter follows the same pattern:

```solidity
import { Api3FtsoAdapter } from "src/adapters/Api3FtsoAdapter.sol";

// Deploy with FTSO feed ID and third-party oracle proxy
Api3FtsoAdapter adapter = new Api3FtsoAdapter(feedId, api3ProxyAddress);

// Get price in FTSO-compatible format
(uint256 value, int8 decimals, uint64 timestamp) = adapter.getFeedById(feedId);
```

## Key Features

- **Standard Interface**: All adapters implement a common interface
- **Feed ID Mapping**: Maps FTSO feed IDs to third-party oracle identifiers
- **Decimal Normalization**: Handles decimal precision differences between oracles
- **Timestamp Handling**: Preserves data freshness information

## Dependencies

These contracts use:
- `@flarenetwork/flare-periphery-contracts` for FTSO interfaces
- `@flarenetwork/ftso-adapters` for adapter base contracts
- Third-party oracle SDKs (API3, Band, Chainlink, Chronicle, Pyth)

## Deployment

See `script/adapters/` for deployment scripts.

## Additional Resources

- **FTSO Docs**: https://dev.flare.network/ftso/overview
- **Flare Periphery**: https://github.com/flare-foundation/flare-periphery-contracts
