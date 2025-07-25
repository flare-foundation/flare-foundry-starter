# Cross-Chain Payment Scripts

This directory contains Foundry scripts for implementing cross-chain payment functionality using Flare's Data Connector (FDC) protocol.

## Overview

This project implements a cross-chain payment system where a user makes a payment of an appropriate amount to the owner address on another chain and an NFT is minted to the user on the Flare chain.

## Deployment

### Deploy Contracts (First Time Only)
Before running the cross-chain payment workflow, you need to deploy the NFT and Minter contracts:

```bash
source .env && forge script script/crossChainPayment/Deploy.s.sol:DeployCrossChainPayment --rpc-url $COSTON2_RPC_URL --broadcast --verify --verifier blockscout --verifier-url https://coston2-explorer.flare.network/api/ -vvvv
```

**What it does:**
- Deploys the MyNFT contract
- Deploys the NFTMinter contract
- Grants MINTER_ROLE to the NFTMinter contract
- Revokes MINTER_ROLE from the deployer for security

### Contract Configuration
Update `Config.s.sol` with your deployed contract addresses:
- `MINTER_ADDRESS`: Address of the deployed NFTMinter contract
- `NFT_ADDRESS`: Address of the deployed NFT contract

## Scripts

### 1. PrepareAttestationRequest
Prepares the FDC request by calling the verifier API.

```bash
source .env && forge script script/crossChainPayment/crossChainPayment.s.sol:PrepareAttestationRequest --rpc-url $COSTON2_RPC_URL --ffi -vvvv
```

**What it does:**
- Calls the verifier API with transaction details
- Creates `EVMTransaction_abiEncodedRequest.txt` in `data/crossChainPayment/`

### 2. SubmitAttestationRequest
Submits the prepared request to the FDC Hub on Flare.

```bash
source .env && forge script script/crossChainPayment/crossChainPayment.s.sol:SubmitAttestationRequest --rpc-url $COSTON2_RPC_URL --ffi --broadcast -vvvv
```

**What it does:**
- Reads the prepared request from file
- Submits to FDC Hub on-chain (requires `--broadcast`)
- Calculates and saves voting round ID to `EVMTransaction_votingRoundId.txt`

### 3. RetrieveProof
Retrieves the proof from the DA Layer after the voting round is finalized.

```bash
source .env && forge script script/crossChainPayment/crossChainPayment.s.sol:RetrieveProof --rpc-url $COSTON2_RPC_URL --ffi -vvvv
```

**What it does:**
- Waits for voting round finalization (may need to retry)
- Retrieves proof from Data Availability Layer
- Saves proof to `EVMTransaction_proof.txt`

**Note:** You may need to wait several minutes for the voting round to finalize before this step succeeds.

### 4. MintNFT
Sends the final proof to the NFTMinter contract to mint the NFT.

```bash
source .env && forge script script/crossChainPayment/crossChainPayment.s.sol:MintNFT --rpc-url $COSTON2_RPC_URL --broadcast -vvvv
```

**What it does:**
- Reads the proof from file
- Calls the NFTMinter contract to mint NFT using the proof
- Requires `--broadcast` to execute the transaction

## Complete Workflow

Run the scripts in this exact order:

```bash
# 1. Deploy contracts (first time only) and update Config.s.sol
source .env && forge script script/crossChainPayment/Deploy.s.sol:DeployCrossChainPayment --rpc-url $COSTON2_RPC_URL --broadcast --verify --verifier blockscout --verifier-url https://coston2-explorer.flare.network/api/ -vvvv

# 2. Prepare the attestation request
source .env && forge script script/crossChainPayment/crossChainPayment.s.sol:PrepareAttestationRequest --rpc-url $COSTON2_RPC_URL --ffi -vvvv

# 3. Submit to FDC Hub (requires --broadcast)
source .env && forge script script/crossChainPayment/crossChainPayment.s.sol:SubmitAttestationRequest --rpc-url $COSTON2_RPC_URL --ffi --broadcast -vvvv

# 4. Wait for voting round finalization, then retrieve proof
source .env && forge script script/crossChainPayment/crossChainPayment.s.sol:RetrieveProof --rpc-url $COSTON2_RPC_URL --ffi -vvvv

# 5. Mint NFT using the proof (requires --broadcast)
source .env && forge script script/crossChainPayment/crossChainPayment.s.sol:MintNFT --rpc-url $COSTON2_RPC_URL --broadcast -vvvv
```

## Data Files

The scripts create and use files in `data/crossChainPayment/`:
- `EVMTransaction_abiEncodedRequest.txt`: Prepared attestation request
- `EVMTransaction_votingRoundId.txt`: Voting round ID from FDC Hub
- `EVMTransaction_proof.txt`: Final proof for NFT minting

## Troubleshooting

### Common Issues

1. **"No such file or directory"**: Ensure you're using lowercase `crossChainPayment.s.sol` in commands

2. **"attestation request not found"**: 
   - Ensure you used `--broadcast` with SubmitAttestationRequest
   - Wait for voting round finalization before running RetrieveProof
   - Verify your API keys are valid (not placeholder values)

3. **"Minter address not set"**: Update `MINTER_ADDRESS` in `Config.s.sol`

4. **API authentication errors**: Verify your `X_API_KEY` is valid and not a placeholder

### Transaction Hash Configuration

The scripts use a hardcoded Sepolia transaction hash. To use a different transaction:
1. Update `TRANSACTION_HASH` in the `PrepareAttestationRequest` contract
2. Ensure the transaction exists on the specified network
3. Verify the transaction contains the expected events/data

## Network Support

Currently configured for:
- **Source Network**: Sepolia (testETH)
- **Target Network**: Coston2 (Flare testnet)

To use different networks, update the constants in the script contracts and ensure your RPC URLs and API endpoints match the target networks.
