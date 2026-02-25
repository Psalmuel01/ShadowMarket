export type PositionSide = "yes" | "no";
export type MarketStatus = "live" | "resolved";

export interface FactorySnapshot {
  nextMarketId: number;
}

export interface MarketSummary {
  id: string;
  address: string;
  questionHash: string;
  oracle: string;
  endTimeIso: string;
  status: MarketStatus;
  resolvedOutcome: PositionSide | null;
  merkleRoot: string;
  nextIndex: number;
}

export interface ProofArtifact {
  programHash: string;
  publicInputs: string[];
  proof: string[];
}

export interface CreateMarketRequest {
  questionHash: string;
  oracle: string;
  endTimeIso: string;
}

export interface AddCommitmentRequest {
  marketAddress: string;
  commitment: string;
  proof: ProofArtifact;
}

export interface ResolveMarketRequest {
  marketAddress: string;
  outcome: PositionSide;
}

export interface ClaimRewardRequest {
  marketAddress: string;
  nullifier: string;
  payoutRecipient: string;
  payoutAmountLow: string;
  proof: ProofArtifact;
}

export interface ActivityItem {
  id: string;
  title: string;
  detail: string;
  atIso: string;
  severity: "info" | "success" | "warning";
}
