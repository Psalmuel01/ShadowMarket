import type { ActivityItem, MarketSummary, VaultSnapshot } from "@/lib/types";

export const mockMarkets: MarketSummary[] = [
  {
    id: "42",
    question: "Will Starknet exceed 25M weekly transactions before June 2026?",
    category: "L2 Usage",
    endTimeIso: "2026-05-30T19:00:00.000Z",
    oracle: "0x0479...oracle-multisig",
    status: "live",
    yesOdds: 61,
    noOdds: 39,
    volumeUsd: 1_820_400,
    totalCommitments: 1284,
    currentMerkleRoot: "0x07fdb2be812f1399c16",
    resolvedOutcome: null
  },
  {
    id: "51",
    question: "Will ETH average gas stay under 20 gwei in Q2 2026?",
    category: "Ethereum",
    endTimeIso: "2026-06-28T20:00:00.000Z",
    oracle: "0x04ac...oracle-multisig",
    status: "live",
    yesOdds: 44,
    noOdds: 56,
    volumeUsd: 1_142_220,
    totalCommitments: 932,
    currentMerkleRoot: "0x03d133f21f027eb8a73",
    resolvedOutcome: null
  },
  {
    id: "34",
    question: "Will BTC close above $120k by March 31, 2026?",
    category: "Crypto Macro",
    endTimeIso: "2026-03-31T23:00:00.000Z",
    oracle: "0x051b...oracle-multisig",
    status: "resolved",
    yesOdds: 28,
    noOdds: 72,
    volumeUsd: 2_901_800,
    totalCommitments: 2013,
    currentMerkleRoot: "0x08906afee02bb88ec11",
    resolvedOutcome: "no"
  }
];

export const mockVaultSnapshot: VaultSnapshot = {
  totalPoolUsd: 8_100_550,
  userAvailableUsd: 24_500,
  userShieldedNotes: 7,
  noteRoot: "0x03a1f24eb109abef90",
  nextNoteIndex: 4821
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
    title: "Vault note appended",
    detail: "Deposit added note index 4820 with updated vault root.",
    atIso: "2026-02-25T13:40:00.000Z",
    severity: "info"
  }
];
