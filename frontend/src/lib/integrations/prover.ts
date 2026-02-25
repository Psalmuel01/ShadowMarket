import type { PositionSide, ProofArtifact } from "@/lib/types";

export interface PositionProofInput {
  marketId: string;
  side: PositionSide;
  amountUsd: number;
  commitment: string;
  previousRoot: string;
}

export interface ClaimProofInput {
  marketId: string;
  expectedOutcome: PositionSide;
  payoutRecipient: string;
}

export interface WithdrawProofInput {
  amountUsd: number;
  recipient: string;
  oldRoot: string;
}

export interface ProverAdapter {
  generatePositionProof(input: PositionProofInput): Promise<ProofArtifact>;
  generateClaimProof(input: ClaimProofInput): Promise<ProofArtifact>;
  generateWithdrawProof(input: WithdrawProofInput): Promise<ProofArtifact>;
}
