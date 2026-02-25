# ShieldVault / Tongo Integration Notes

Current `ShieldVault` contract provides:

- ERC20 deposits into a shielded pool (`deposit`)
- proof-gated withdrawals (`withdraw`)
- market-authorized payout release (`release_payout`)
- withdrawal nullifier replay protection
- incremental note Merkle root tracking (`note_merkle_root`, `next_note_index`)
- strict note-root continuity on withdraw (`old_root == new_root`)
- strict withdrawal public-input binding:
  - `[nullifier, amount_low, amount_high, recipient, old_root, new_root]`

## Recommended Tongo binding model

1. Treat each deposit as an encrypted note commitment (`encrypted_balance_commitment`).
2. Keep note plaintext off-chain in Tongo relayer/storage.
3. Generate withdrawal proofs over:
   - ownership of unspent notes
   - note nullifier derivation
   - output amount correctness
   - optional fee/output note balancing
4. Pass these as verifier public inputs and bind them in `ShieldVault.withdraw`.
5. Mark note nullifier spent on-chain to prevent replay.

## Gaps to implement for full production privacy

- stateful root-transition support on withdraw (requires proving and passing enough
  metadata to safely update append-state fields, not only root)
- change-output note insertion on partial spends
- encrypted memo / key-derivation conventions for recipient decryption
- relayer fee accounting and anti-front-running strategy
