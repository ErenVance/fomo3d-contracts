# BNB Chain Compliance

## Deployment Target

This project is built for and deployed on **BNB Smart Chain (BSC)**.

## BNB Chain Evidence

### Configuration

- `foundry.toml` — Solidity ^0.8.33, optimized for BSC deployment
- RPC endpoints target BSC Mainnet (Chain ID: 56) and BSC Testnet (Chain ID: 97)

### Contract Design

- Diamond proxy receives **BNB** (native token) via `receive() external payable`
- `detectAndDistributeBNB()` — detects incoming BNB and distributes to prize/dividend pools
- `transferBNB()` — handles BNB payouts to players
- `trackedBalance` — tracks BNB balance for deposit detection
- All fund flows denominated in **BNB** (not ETH or other native tokens)

### BNB-Specific References in Code

- `AppStorage.trackedBalance` — BNB balance tracking
- `LibGame.detectAndDistributeBNB()` — BNB detection and distribution
- `LibGame.transferBNB()` — BNB transfer utility
- Events: `BNBDetected(uint256 amount, ...)` — emitted on BNB deposit detection

### Documentation

- README explicitly states deployment on **BNB Smart Chain**
- Contract addresses table includes BSC Mainnet and BSC Testnet entries

## Repository Info

- **Public repository**: https://github.com/ErenVance/fomo3d-contracts
- **License**: MIT
- **Official source code**: Yes — this is the sole contract repository for the Fomo3D project
