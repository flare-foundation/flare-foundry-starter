# Boring Vault Integration Examples

This directory contains standalone, runnable examples demonstrating how to interact with Boring Vault contracts. Each example focuses on a specific operation or concept.

## Prerequisites

```bash
forge install
```

Ensure you have:
- Access to Coston2 testnet RPC
- A wallet with test tokens (for write operations)

## Running Examples

First, deploy the vault system:

```bash
forge script script/boringVault/DeployBoringVault.s.sol:DeployBoringVault --rpc-url $COSTON2_RPC_URL --broadcast
```

This creates `deployment-addresses.json` which all other scripts read from.

Then run any example:

```bash
# Read-only example
forge script script/boringVault/ReadVaultInfo.s.sol:ReadVaultInfo --rpc-url $COSTON2_RPC_URL

# Write example (requires private key)
forge script script/boringVault/DepositWorkflow.s.sol:DepositWorkflow --rpc-url $COSTON2_RPC_URL --broadcast
```

## Example Overview

### Read Operations (No Wallet Required)

| Example | Description |
|---------|-------------|
| `ReadVaultInfo.s.sol` | Read vault metadata (name, symbol, decimals, supply) |
| `CheckUserBalance.s.sol` | Query user's share balance and unlock status |
| `CalculateExchangeRates.s.sol` | Fetch and use exchange rates for calculations |

### Write Operations (Wallet Required)

| Example | Description |
|---------|-------------|
| `DepositWorkflow.s.sol` | Complete deposit flow with approval and slippage |
| `WithdrawalWorkflow.s.sol` | Complete withdrawal flow with unlock checks |
| `ApprovalManagement.s.sol` | Token approval patterns and best practices |
| `FtsoOracleIntegration.s.sol` | FTSO oracle integration examples |
| `DeployBoringVault.s.sol` | Deploy vault, accountant, and teller contracts |

## Example Details

### ReadVaultInfo.s.sol
Learn the basics of reading from the BoringVault contract.
- Contract initialization with Foundry/forge-std
- Reading ERC20 metadata
- Fetching total supply
- Formatting output

**Key Concepts**: Contract reads, uint handling, formatting

### CheckUserBalance.s.sol
Query user-specific data from Vault and Teller.
- Reading user's share balance
- Checking share unlock time
- Calculating ownership percentage
- Time-based logic

**Key Concepts**: User state, time handling, percentage calculations

### CalculateExchangeRates.s.sol
Work with the Accountant contract to get exchange rates.
- Fetching rates for multiple assets
- Converting shares to assets
- Converting assets to shares
- Handling different decimals

**Key Concepts**: Rate math, decimal precision, multi-asset support

### DepositWorkflow.s.sol
Complete implementation of a deposit transaction.
- Checking asset allowance
- Approving vault (not teller!)
- Calculating minimum shares with slippage
- Executing deposit
- Waiting for confirmation

**Key Concepts**: Token approvals, slippage protection, transaction flow

### WithdrawalWorkflow.s.sol
Complete implementation of a withdrawal transaction.
- Verifying shares are unlocked
- Calculating expected assets
- Setting minimum asset amount
- Executing withdrawal
- Handling recipient addresses

**Key Concepts**: Share locks, slippage protection, safe withdrawals

### ApprovalManagement.s.sol
Advanced approval patterns and gas optimization.
- Checking current allowances
- Infinite vs. exact approvals
- Approval revocation
- Multi-asset approval strategies

**Key Concepts**: Gas optimization, security considerations, UX patterns

### FtsoOracleIntegration.s.sol
Working with Flare's FTSO oracles for price feeds.
- Fetching FTSO prices
- Integrating with rate providers
- Handling different oracle types
- Price feed validation

**Key Concepts**: Oracle integration, price feeds, rate providers

## Code Patterns Used

### Contract Setup
```solidity
import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { BoringVault } from "../../src/boringVault/BoringVault.sol";

using stdJson for string;

string memory json = vm.readFile("deployment-addresses.json");
address vaultAddress = json.readAddress(".addresses.boringVault");
BoringVault vault = BoringVault(payable(vaultAddress));
```

### Reading Contract Data
```solidity
uint256 totalSupply = vault.totalSupply();
uint8 decimals = vault.decimals();
console.log("Total Supply:", totalSupply / (10 ** decimals));
```

### Writing Transactions (with Wallet)
```solidity
uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
vm.startBroadcast(deployerPrivateKey);

teller.deposit(ERC20(assetAddress), depositAmount, minimumMint);

vm.stopBroadcast();
```

### Error Handling
```solidity
try accountant.getRateInQuote(ERC20(asset)) returns (uint256 rate) {
    console.log("Rate:", rate);
} catch {
    console.log("Asset not supported");
}
```

## Configuration

### Environment Variables

Configure your environment variables in `.env`:
- `COSTON2_RPC_URL`: RPC endpoint for Coston2 testnet
- `PRIVATE_KEY`: Your wallet private key (for write operations)

### Deployment Addresses

Contract addresses are automatically managed via `deployment-addresses.json`:

1. Run `DeployBoringVault.s.sol` to deploy contracts and create the JSON file
2. Other scripts automatically read addresses from this file

## Common Issues

### "deployment-addresses.json not found"
- Run the deploy script first: `forge script script/boringVault/DeployBoringVault.s.sol:DeployBoringVault --rpc-url $COSTON2_RPC_URL --broadcast`

### "Insufficient funds"
- Get test tokens from Coston2 faucet
- Check you have enough FLR for gas fees

### "Transfer from failed"
- Verify you're approving the **Vault**, not the Teller
- See `DepositWorkflow.s.sol` for correct pattern

### "Shares are locked"
- Wait for share lock period to expire
- Check `shareLockPeriod` in Teller contract

## Next Steps

1. Deploy contracts using `DeployBoringVault.s.sol`
2. Run read examples to understand contract structure
3. Study the calculation examples for math operations
4. Try write examples on testnet with small amounts
5. Read the source code - it's heavily commented!

## Additional Resources

- **Boring Vault Docs**: https://docs.veda.tech/integrations/boringvault-protocol-integration
- **Foundry Docs**: https://book.getfoundry.sh
- **Contract Source**: https://github.com/Se7en-Seas/boring-vault

## Contributing

Found an issue or want to add an example? Please open a PR!
