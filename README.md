# ShadowMarket (Starknet, Cairo 1.x)

Private prediction market core stack:

- `MarketFactory`: deploys and indexes market instances.
- `Market`: commitment insertion, oracle resolution, claim execution.
- `Verifier`: policy gate + Garaga-compatible verifier dispatch.
- `NullifierRegistry`: global nullifier anti-double-claim state.
- `ShieldVault`: optional collateral pool with proof-gated withdraw/payout.
- `MerkleTreeLib`: Pedersen-based hash, commitment/nullifier helpers, path checks.

## Build

```bash
scarb build
```

## Noir Toolchain

This repo is currently pinned by convention to:

- `nargo version = 1.0.0-beta.18`

Run:

```bash
./scripts/check_noir.sh
```

This validates local `nargo` version and compiles both circuits.

Generate circuit artifacts + program hashes:

```bash
./scripts/compile_circuits.sh
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

`Market` now enforces strict public input binding before verifier calls, so calldata cannot diverge from proved public values.

## ZK circuits

Noir circuits are in `circuits/`:

- `/Users/sam/Desktop/Starknet/ShadowMarket/circuits/position_commitment`
- `/Users/sam/Desktop/Starknet/ShadowMarket/circuits/claim_reward`

Both circuits now enforce:

- commitment hash correctness
- Merkle path-based root constraints
- strict public input ordering
- nullifier derivation and payout rule checks (`claim_reward`)

## Program Hash Registration

Register accepted program hashes:

```bash
./scripts/register_program_hashes.sh <verifier_address>
```

`register_program_hashes.sh` auto-loads hashes from `circuits/program_hashes.env`.
If your Garaga deployment uses different identifiers, override that file before registration.

See:

- `/Users/sam/Desktop/Starknet/ShadowMarket/docs/garaga_pipeline.md`
- `/Users/sam/Desktop/Starknet/ShadowMarket/docs/shield_vault_tongo.md`
