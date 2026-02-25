import type {
  ClaimRewardRequest,
  MarketSummary,
  ProofArtifact,
  SubmitPositionRequest,
  VaultSnapshot,
  WithdrawRequest
} from "@/lib/types";

export interface ContractsAdapter {
  listMarkets(): Promise<MarketSummary[]>;
  getVaultSnapshot(userAddress: string): Promise<VaultSnapshot>;
  submitPosition(request: SubmitPositionRequest, proof: ProofArtifact): Promise<{ txHash: string }>;
  resolveMarket(marketId: string, outcome: "yes" | "no"): Promise<{ txHash: string }>;
  claimReward(request: ClaimRewardRequest, proof: ProofArtifact): Promise<{ txHash: string; payoutUsd: number }>;
  deposit(amountUsd: number, noteCommitment: string): Promise<{ txHash: string }>;
  withdraw(request: WithdrawRequest, proof: ProofArtifact): Promise<{ txHash: string }>;
}
