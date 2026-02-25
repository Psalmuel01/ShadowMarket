import type { ActivityItem, FactorySnapshot, MarketSummary } from "@/lib/types";

export const mockMarkets: MarketSummary[] = [
  {
    id: "42",
    address: "0x04d3...market-42",
    questionHash: "0x0442daaa9f1",
    oracle: "0x0479...oracle-multisig",
    endTimeIso: "2026-05-30T19:00:00.000Z",
    status: "live",
    resolvedOutcome: null,
    merkleRoot: "0x07fdb2be812f1399c16",
    nextIndex: 1284
  },
  {
    id: "51",
    address: "0x05b7...market-51",
    questionHash: "0x0118ecf7c30",
    oracle: "0x04ac...oracle-multisig",
    endTimeIso: "2026-06-28T20:00:00.000Z",
    status: "live",
    resolvedOutcome: null,
    merkleRoot: "0x03d133f21f027eb8a73",
    nextIndex: 932
  },
  {
    id: "34",
    address: "0x03e1...market-34",
    questionHash: "0x0999c134001",
    oracle: "0x051b...oracle-multisig",
    endTimeIso: "2026-03-31T23:00:00.000Z",
    status: "resolved",
    resolvedOutcome: "no",
    merkleRoot: "0x08906afee02bb88ec11",
    nextIndex: 2013
  }
];

export const mockFactorySnapshot: FactorySnapshot = {
  nextMarketId: 52
};

export const mockActivity: ActivityItem[] = [
  {
    id: "a1",
    title: "Position commitment accepted",
    detail: "Market #42 commitment inserted at leaf 1328.",
    atIso: "2026-02-25T15:01:00.000Z",
    severity: "success"
  },
  {
    id: "a2",
    title: "Claim prevented",
    detail: "Nullifier replay attempt rejected by Market contract.",
    atIso: "2026-02-25T14:13:00.000Z",
    severity: "warning"
  },
  {
    id: "a3",
    title: "Market deployed",
    detail: "Market #51 deployed by factory owner.",
    atIso: "2026-02-25T13:40:00.000Z",
    severity: "info"
  }
];
