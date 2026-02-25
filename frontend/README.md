# ShadowMarket Frontend (Next.js)

Dark-first UI for the private prediction market stack.

## What is included

- Next.js App Router + TypeScript scaffold
- responsive trading desk layout (market selector, private action panel, settlement, vault, activity)
- theme toggle (dark/light) with CSS variable system
- integration-ready adapter boundaries for:
  - wallet connection
  - Starknet contract calls
  - Noir proof generation
- mock adapters and seeded data for UI-first workflow

## Run locally

```bash
cd frontend
npm install
npm run dev
```

Open <http://localhost:3000>.

## Integration boundaries

- `src/lib/integrations/wallet.ts`
- `src/lib/integrations/contracts.ts`
- `src/lib/integrations/prover.ts`
- `src/lib/integrations/index.ts`

Current UI uses `src/lib/mocks/mock-integrations.ts` through `useShadowMarket()`.

## Swap from mocks to live integrations

1. Implement real adapters (e.g. `starknet-react` + typed contract wrappers + prover service bridge).
2. Replace `createMockIntegrations()` in `src/lib/use-shadow-market.ts` with a live bundle factory.
3. Keep public-input schema and proof flow aligned with Cairo contracts:
   - `Market.add_commitment` PI: `[market_id, leaf_index, commitment, old_root, new_root]`
   - `Market.claim_reward` PI: `[market_id, root, outcome, nullifier, payout_low, payout_high, payout_recipient]`
   - `ShieldVault.withdraw` PI: `[nullifier, amount_low, amount_high, recipient, old_root, new_root]`
