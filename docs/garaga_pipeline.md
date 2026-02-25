# Garaga Pipeline Notes

`Verifier.cairo` is wired for Garaga-style proof verification through:

- `verify_proof(program_hash, public_inputs, proof)`
- owner-managed allowed program hashes (`set_program_hash`, `set_program_hashes`)

## Circuit artifact workflow in this repo

1. Compile Noir circuits:
   - `./scripts/compile_circuits.sh`
2. This generates:
   - `circuits/position_commitment/target/position_commitment.json`
   - `circuits/claim_reward/target/claim_reward.json`
   - `circuits/program_hashes.env` (program hashes from Noir artifact `hash` fields)
3. Register hashes:
   - `./scripts/register_program_hashes.sh <verifier_address>`

## Production handoff

If your Garaga flow requires VK/program identifiers different from Noir artifact hashes,
override `circuits/program_hashes.env` before registration and ensure the deployed Garaga verifier contract matches those artifacts.
