export type PositionSide = "yes" | "no";
export type MarketStatus = "live" | "resolved";

export interface MarketSummary {
  id: string;
  question: string;
  category: string;
  endTimeIso: string;
  oracle: string;
  status: MarketStatus;
  yesOdds: number;
  noOdds: number;
  volumeUsd: number;
  totalCommitments: number;
  currentMerkleRoot: string;
  resolvedOutcome: PositionSide | null;
}

export interface VaultSnapshot {
  totalPoolUsd: number;
  userAvailableUsd: number;
  userShieldedNotes: number;
  noteRoot: string;
  nextNoteIndex: number;
}

export interface ProofArtifact {
  programHash: string;
  publicInputs: string[];
  proof: string[];
}

export interface SubmitPositionRequest {
  marketId: string;
  side: PositionSide;
  amountUsd: number;
  collateralCommitment: string;
}

export interface ClaimRewardRequest {
  marketId: string;
  payoutRecipient: string;
}

export interface WithdrawRequest {
  amountUsd: number;
  recipient: string;
}

export interface ActivityItem {
  id: string;
  title: string;
  detail: string;
  atIso: string;
  severity: "info" | "success" | "warning";
}
