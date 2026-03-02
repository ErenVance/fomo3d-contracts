# Fomo3D Contracts

Solidity smart contracts for Fomo3D — a countdown-based game on BNB Chain (BSC) built with the Diamond Pattern (EIP-2535).

Players burn ERC20 tokens to purchase shares, extending a countdown timer. When the countdown expires, the grand prize pool is distributed to the last 10 buyers.

## Architecture

The contract uses the [Diamond Pattern (EIP-2535)](https://eips.ethereum.org/EIPS/eip-2535) for modular upgradability. A single Diamond proxy delegates calls to multiple Facets:

```
Diamond (Proxy)
├── DiamondCutFacet       — Upgrade management
├── DiamondLoupeFacet     — Contract introspection
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
Purchase shares → Countdown extends → Dividends accrue → Countdown expires → Grand prize distributed → Next round
```

### BNB Distribution

When BNB is sent to the contract and detected during a purchase:

| Pool | Default | Purpose |
|------|---------|---------|
| Injection Pool | 50% | Immediately distributed in current round |
| Pending Pool | 50% | Reserved for next round |

The Injection Pool is further split:

| Sub-pool | Default | Purpose |
|----------|---------|---------|
| Dividend | 50% | Distributed to all share holders (EPS-based) |
| Grand Prize | 50% | Accumulated for end-of-round payout |

### Grand Prize

When the countdown reaches zero, the grand prize pool is distributed:

| Rank | Share |
|------|-------|
| #1 (last buyer) | 55% |
| #2 ~ #10 | 5% each |

### Dividend System (Pull-based EPS)

Dividends use an Earnings-Per-Share accumulator pattern:

```
// On BNB injection
earningsPerShare += dividendAmount * EPS_PRECISION / totalShares

// Player pending earnings
pending = (earningsPerShare - player.earningsPerShare) * player.shares / EPS_PRECISION
```

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
