<p align="left">
  <a href="https://flare.network/" target="blank"><img src="https://content.flare.network/Flare-2.svg" width="410" height="106" alt="Flare Logo" /></a>
</p>

# Flare Foundry Starter

This is a starter kit for interacting with Flare blockchain using [Foundry](https://getfoundry.sh/).
It provides example code for interacting with the enshrined Flare protocols ([FTSO](https://dev.flare.network/ftso/overview), [FDC](https://dev.flare.network/fdc/overview), [FAssets](https://dev.flare.network/fassets/overview)), and useful deployed contracts.
It also demonstrates how the official Flare smart contract periphery [package](https://www.npmjs.com/package/@flarenetwork/flare-periphery-contracts) can be used in your projects.

## Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- [Node.js](https://nodejs.org/) (for npm dependencies)

### Installation

Install all dependencies with a single command:

```bash
make install
```

This runs `forge soldeer install` for Solidity dependencies, then fetches npm-only packages (e.g., `ftso-adapters`, `pyth-sdk-solidity`) that aren't available on Soldeer.

### Configuration

Copy the `.env.example` to `.env` and fill in your private key:

```bash
cp .env.example .env
```

At minimum, set `PRIVATE_KEY` to a funded wallet on the target network. The `.env.example` file contains all available configuration options including RPC URLs, API keys, verifier URLs, and DA Layer endpoints.

### Running Scripts

Load environment variables and run any script with Foundry:

```bash
source .env && forge script script/HelloWorld.s.sol --rpc-url coston2 --broadcast
```

### Running Tests

```bash
forge test
```

## Project Structure

```
script/
├── fdcExample/          # Flare Data Connector (all attestation types)
├── ftso/                # FTSO price feed examples
├── customFeeds/         # Custom FDC-backed price feeds
├── fassets/             # FAssets minting, bridging, redemption
├── adapters/            # Third-party oracle adapters (Chainlink, Pyth, etc.)
├── boringVault/         # BoringVault DeFi integration
├── firelight/           # Firelight protocol interactions
├── wnat/                # Wrapped native token operations
├── HelloWorld.s.sol     # Simple starter example
└── GuessingGame.s.sol   # Interactive game example
src/                     # Smart contract source files
test/                    # Forge tests
```
