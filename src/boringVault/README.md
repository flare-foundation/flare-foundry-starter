# Boring Vault Contracts

Smart contracts for Veda's Boring Vault protocol - a modular vault architecture for DeFi yield strategies.

## Overview

Boring Vault is a flexible vault system that separates concerns into distinct contracts:
- **BoringVault**: Core ERC20 vault token and asset custody
- **Accountant**: Exchange rate management and fee calculations
- **Teller**: User-facing deposit/withdrawal interface

## Contracts

| Contract | Description |
|----------|-------------|
| `BoringVault.sol` | Core vault contract holding assets and minting shares |
| `AccountantWithRateProviders.sol` | Manages exchange rates with pluggable rate providers |
| `TellerWithMultiAssetSupport.sol` | Handles deposits/withdrawals for multiple assets |
| `FixedPointMathLib.sol` | Safe fixed-point arithmetic library |

### Interfaces

| Interface | Description |
|-----------|-------------|
| `IAccountant.sol` | Accountant interface for rate queries |
| `IRateProvider.sol` | Interface for custom rate provider plugins |
| `ITeller.sol` | Teller interface for deposits/withdrawals |
| `IBoringVault.sol` | Core vault interface |

## Architecture

```
User
  │
  ▼
┌─────────┐     ┌─────────────┐     ┌─────────────┐
│ Teller  │────▶│ Accountant  │────▶│ BoringVault │
└─────────┘     └─────────────┘     └─────────────┘
     │                │                    │
     │                ▼                    ▼
     │         Rate Providers         Asset Custody
     │
     ▼
  User Assets
```

## Key Features

- **Multi-Asset Support**: Accept deposits in multiple tokens
- **Share Locking**: Configurable lock period for minted shares
- **Rate Providers**: Pluggable oracle integration for asset pricing
- **Fee Management**: Flexible fee structure with platform and performance fees
- **Pausable**: Emergency pause functionality

## Usage

```solidity
import { BoringVault } from "src/boringVault/BoringVault.sol";
import { TellerWithMultiAssetSupport } from "src/boringVault/TellerWithMultiAssetSupport.sol";

// Deposit assets
IERC20(asset).approve(address(vault), amount);
teller.deposit(ERC20(asset), amount, minimumShares);

// Withdraw (after unlock period)
teller.bulkWithdraw(ERC20(asset), shares, minimumAssets, recipient);
```

## Deployment

See `script/boringVault/DeployBoringVault.s.sol` for deployment.

## Additional Resources

- **Boring Vault Docs**: https://docs.veda.tech/integrations/boringvault-protocol-integration
- **Original Source**: https://github.com/Se7en-Seas/boring-vault
