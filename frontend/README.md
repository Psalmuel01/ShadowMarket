# ShadowMarket Frontend (Next.js)

Dark-first UI for the private prediction market stack.

## What is included

- Next.js App Router + TypeScript scaffold
- minimal MVP trading desk layout (factory, markets, add commitment, resolve, claim, activity)
- theme toggle (dark/light) with CSS variable system
- integration-ready adapter boundaries for:
  - wallet connection
  - Starknet contract calls
- mock adapter mode and live adapter mode (injected wallet + on-chain reads/writes)

## Environment

Copy `.env.example` to `.env.local`:

```bash
cp .env.example .env.local
```

Required in live mode:

- `NEXT_PUBLIC_INTEGRATION_MODE=live`
- `NEXT_PUBLIC_FACTORY_ADDRESS=<deployed MarketFactory>`

In live mode, connect an injected Starknet wallet first; reads and writes are performed through the wallet provider/account.

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
- `src/lib/integrations/index.ts`

Runtime bundle selector:

- `src/lib/use-integrations.ts`

Live adapter implementation:

- `src/lib/live/wallet.ts`
- `src/lib/live/contracts.ts`

Mock fallback:

- `src/lib/mocks/mock-integrations.ts`

## ZK input requirements

For MVP simplicity, proof payloads are entered directly in the UI.
Keep these schemas aligned with Cairo contracts:

- `MarketFactory.create_market(question_hash, oracle, end_time)`
- `Market.add_commitment` PI: `[market_id, leaf_index, commitment, old_root, new_root]`
- `Market.claim_reward` PI: `[market_id, root, outcome, nullifier, payout_low, payout_high, payout_recipient]`
