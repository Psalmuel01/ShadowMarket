# ShadowMarket (Starknet, Cairo 1.x)

Private prediction market core stack:

- `MarketFactory`: deploys and indexes market instances.
- `Market`: commitment insertion, oracle resolution, claim execution.
- `Verifier`: policy gate + Garaga-compatible verifier dispatch.
- `NullifierRegistry`: global nullifier anti-double-claim state.
- `ShieldVault`: optional collateral pool with proof-gated withdraw/payout.
- `MerkleTreeLib`: Poseidon-based hash, commitment/nullifier helpers, path checks.

## Build

```bash
scarb build
```

## Contract flow

1. Deploy `Verifier`, `NullifierRegistry`, optional `ShieldVault`.
2. Deploy `MarketFactory` with `Market` class hash + dependency addresses.
3. Create market via `MarketFactory.create_market(...)`.
4. Authorize each market in:
   - `NullifierRegistry.set_authorized_caller(market, true)`
   - `ShieldVault.set_authorized_market(market, true)` (if vault-enabled)
5. Users submit commitments with proof via `Market.add_commitment(...)`.
6. Oracle resolves via `Market.resolve_market(outcome)`.
7. Winners claim via `Market.claim_reward(...)` with nullifier and proof.

## ZK circuits

Noir circuit templates are in `circuits/`:

- `circuits/position_commitment`
- `circuits/claim_reward`

The current circuit hash functions are placeholders for scaffolding. Replace with Noir Poseidon primitives before production.
