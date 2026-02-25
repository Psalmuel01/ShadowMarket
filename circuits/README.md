# Noir Circuits

This folder contains production-oriented circuits for:

- `position_commitment`: prove commitment correctness + incremental insertion
- `claim_reward`: prove membership + winner eligibility + nullifier + payout

Notes:

- Hashes use `std::hash::pedersen_hash` to keep Noir (`nargo 1.0.0-beta.18`) and Cairo aligned.
- The 5-field commitment hash is derived as a Pedersen pair-compression tree and matches
  `src/merkle_tree_lib.cairo::commitment_hash`.
- On-chain verification is expected through Garaga and the `Verifier` Cairo contract.
