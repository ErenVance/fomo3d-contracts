# Fomo3D Contracts

A countdown-based grand prize game where players burn ERC20 tokens to purchase shares and compete for the prize pool, built on **BNB Smart Chain (BSC)** and compatible with other EVM networks.

## Technology Stack

- **Blockchain**: BNB Smart Chain + EVM-compatible chains
- **Smart Contracts**: Solidity ^0.8.33, Diamond Pattern (EIP-2535)
- **Development**: Foundry, OpenZeppelin Contracts

## Supported Networks

- **BNB Smart Chain Mainnet** (Chain ID: 56)
- **BNB Smart Chain Testnet** (Chain ID: 97)

## Contract Addresses

| Network | Diamond (Proxy) |
|---------|-----------------|
| BNB Testnet | `0x...` |
| BNB Mainnet | `0x...` |

## Features

- **Countdown Grand Prize**: Last 10 buyers split the prize pool when the timer expires (55% to #1, 5% each to #2–#10)
- **Token Burn Mechanism**: Players burn ERC20 tokens to purchase shares, creating deflationary pressure
- **Pull-based Dividend System**: Real-time earnings distribution via Earnings-Per-Share (EPS) accumulator
- **Diamond Pattern (EIP-2535)**: Modular upgradability with 8 independent facets sharing unified storage
- **Security-first Design**: EOA-only restriction, reentrancy guards, emergency pause, and BNB balance tracking

## Architecture

```
Diamond (Proxy)
├── DiamondCutFacet       — Upgrade management
├── DiamondLoupeFacet     — Contract introspection (ERC-2535)
├── OwnershipFacet        — Owner management (ERC-173)
├── PurchaseFacet         — Buy shares by burning tokens
├── ExitFacet             — Exit game / settle after round ends
├── LifecycleFacet        — End round & distribute grand prize
├── AdminFacet            — Configuration management
└── ViewFacet             — Read-only queries
```

All facets share state through a unified `AppStorage` struct via `LibAppStorage`.

## Game Mechanics

### Core Loop

```
Purchase shares → Countdown extends → Dividends accrue → Countdown expires → Grand prize → Next round
```

### BNB Distribution

| Pool | Default | Purpose |
|------|---------|---------|
| Injection Pool | 50% | Immediately distributed in current round |
| Pending Pool | 50% | Reserved for next round |

The Injection Pool is further split:

| Sub-pool | Default | Purpose |
|----------|---------|---------|
| Dividend | 50% | Distributed to all share holders (EPS-based) |
| Grand Prize | 50% | Accumulated for end-of-round payout |

### Grand Prize Distribution

| Rank | Share |
|------|-------|
| #1 (last buyer) | 55% |
| #2 ~ #10 | 5% each |

## Security

- **`onlyEOA`** — `purchase`, `exitGame`, `settleUnexited` restrict to EOA (`msg.sender == tx.origin`) to prevent flash loan and MEV attacks
- **`nonReentrant`** — All state-changing functions use reentrancy guards
- **`whenNotPaused`** — Emergency pause capability (except `settleUnexited` and `endRoundAndDistribute`)
- **Pull-based withdrawals** — Grand prizes credited to `pendingWithdrawals`, claimed separately
- **BNB tracking** — `trackedBalance` detects incoming BNB via balance diff, preventing manipulation

## Build

```bash
forge build
```

## Dependencies

- [forge-std](https://github.com/foundry-rs/forge-std)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) (IERC20, ReentrancyGuard)

## License

[MIT](LICENSE)
