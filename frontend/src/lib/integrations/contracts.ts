import type {
  AddCommitmentRequest,
  ClaimRewardRequest,
  CreateMarketRequest,
  FactorySnapshot,
  MarketSummary,
  ResolveMarketRequest
} from "@/lib/types";

export interface ContractsAdapter {
  getFactorySnapshot(): Promise<FactorySnapshot>;
  listMarkets(): Promise<MarketSummary[]>;
  createMarket(request: CreateMarketRequest): Promise<{ txHash: string; marketId: string; marketAddress: string }>;
  addCommitment(request: AddCommitmentRequest): Promise<{ txHash: string }>;
  resolveMarket(request: ResolveMarketRequest): Promise<{ txHash: string }>;
  claimReward(request: ClaimRewardRequest): Promise<{ txHash: string }>;
}
