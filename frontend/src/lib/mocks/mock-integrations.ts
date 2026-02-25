import type { ContractsAdapter } from "@/lib/integrations/contracts";
import type { IntegrationBundle } from "@/lib/integrations";
import type { WalletAdapter, WalletSession } from "@/lib/integrations/wallet";
import type {
  AddCommitmentRequest,
  ClaimRewardRequest,
  CreateMarketRequest,
  FactorySnapshot,
  MarketSummary,
  ResolveMarketRequest
} from "@/lib/types";
import { mockFactorySnapshot, mockMarkets } from "@/lib/mocks/mock-data";

const sleep = async (ms: number): Promise<void> => {
  await new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
};

class MockWalletAdapter implements WalletAdapter {
  private session: WalletSession | null = null;

  async connect(): Promise<WalletSession> {
    await sleep(260);
    this.session = {
      address: "0x07f4...2ab1",
      chainId: "SN_SEPOLIA",
      connector: "Mock ArgentX"
    };
    return this.session;
  }

  async disconnect(): Promise<void> {
    await sleep(120);
    this.session = null;
  }

  async getActiveSession(): Promise<WalletSession | null> {
    await sleep(70);
    return this.session;
  }
}

class MockContractsAdapter implements ContractsAdapter {
  private markets: MarketSummary[] = structuredClone(mockMarkets);
  private factory: FactorySnapshot = structuredClone(mockFactorySnapshot);

  async getFactorySnapshot(): Promise<FactorySnapshot> {
    await sleep(110);
    return structuredClone(this.factory);
  }

  async listMarkets(): Promise<MarketSummary[]> {
    await sleep(180);
    return structuredClone(this.markets);
  }

  async createMarket(
    request: CreateMarketRequest
  ): Promise<{ txHash: string; marketId: string; marketAddress: string }> {
    await sleep(380);
    const marketId = this.factory.nextMarketId.toString();
    const marketAddress = `0xmarket-${marketId}`;

    this.factory = {
      nextMarketId: this.factory.nextMarketId + 1
    };

    const created: MarketSummary = {
      id: marketId,
      address: marketAddress,
      questionHash: request.questionHash,
      oracle: request.oracle,
      endTimeIso: request.endTimeIso,
      status: "live",
      resolvedOutcome: null,
      merkleRoot: "0x0",
      nextIndex: 0
    };

    this.markets = [created, ...this.markets];
    return { txHash: `0xcreate-market-${marketId}`, marketId, marketAddress };
  }

  async addCommitment(request: AddCommitmentRequest): Promise<{ txHash: string }> {
    await sleep(320);
    this.markets = this.markets.map((market) => {
      if (market.address !== request.marketAddress) {
        return market;
      }
      return {
        ...market,
        nextIndex: market.nextIndex + 1,
        merkleRoot: request.proof.publicInputs[4] ?? market.merkleRoot
      };
    });
    return { txHash: "0xadd-commitment-7c1" };
  }

  async resolveMarket(request: ResolveMarketRequest): Promise<{ txHash: string }> {
    await sleep(290);
    this.markets = this.markets.map((market) => {
      if (market.address !== request.marketAddress) {
        return market;
      }
      return {
        ...market,
        status: "resolved",
        resolvedOutcome: request.outcome
      };
    });
    return { txHash: "0xresolve-market-44b" };
  }

  async claimReward(_request: ClaimRewardRequest): Promise<{ txHash: string }> {
    await sleep(340);
    return { txHash: "0xclaim-reward-2ef" };
  }
}

export const createMockIntegrations = (): IntegrationBundle => {
  return {
    wallet: new MockWalletAdapter(),
    contracts: new MockContractsAdapter()
  };
};
