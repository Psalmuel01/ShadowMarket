# Noir Circuits

This folder contains circuit scaffolding for:

- `position_commitment`: prove commitment correctness + insertion transition
- `claim_reward`: prove winner eligibility + nullifier derivation + payout

Notes:

- Hashes use Noir Poseidon pair compression via `std::hash::poseidon::bn254::hash_2`.
- The 5-field commitment hash is derived as a pair-compression tree and matches
  `merkle_tree_lib::commitment_hash` in Cairo.
- On-chain verification is expected through Garaga and the `Verifier` Cairo contract.
