import type { ContractsAdapter } from "@/lib/integrations/contracts";
import type {
  ClaimProofInput,
  PositionProofInput,
  ProverAdapter,
  WithdrawProofInput
} from "@/lib/integrations/prover";
import type { IntegrationBundle } from "@/lib/integrations";
import type { WalletAdapter, WalletSession } from "@/lib/integrations/wallet";
import type {
  ClaimRewardRequest,
  MarketSummary,
  ProofArtifact,
  SubmitPositionRequest,
  VaultSnapshot,
  WithdrawRequest
} from "@/lib/types";
import { mockMarkets, mockVaultSnapshot } from "@/lib/mocks/mock-data";

const sleep = async (ms: number): Promise<void> => {
  await new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
};

const proofFromSeed = async (seed: string): Promise<ProofArtifact> => {
  await sleep(420);
  return {
    programHash: `0xprogram-${seed}`,
    publicInputs: [`0xpi-${seed}`, `0xroot-${seed}`],
    proof: [`0xproof-${seed}`, `0xproof-end-${seed}`]
  };
};

class MockWalletAdapter implements WalletAdapter {
  private session: WalletSession | null = null;

  async connect(): Promise<WalletSession> {
    await sleep(300);
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
    await sleep(80);
    return this.session;
  }
}

class MockContractsAdapter implements ContractsAdapter {
  private markets: MarketSummary[] = structuredClone(mockMarkets);
  private vault: VaultSnapshot = structuredClone(mockVaultSnapshot);

  async listMarkets(): Promise<MarketSummary[]> {
    await sleep(220);
    return structuredClone(this.markets);
  }

  async getVaultSnapshot(_userAddress: string): Promise<VaultSnapshot> {
    await sleep(180);
    return structuredClone(this.vault);
  }

  async submitPosition(_request: SubmitPositionRequest, _proof: ProofArtifact): Promise<{ txHash: string }> {
    await sleep(500);
    return { txHash: "0xsubmit-position-91b" };
  }

  async resolveMarket(marketId: string, outcome: "yes" | "no"): Promise<{ txHash: string }> {
    await sleep(350);
    this.markets = this.markets.map((market) => {
      if (market.id !== marketId) {
        return market;
      }
      return {
        ...market,
        status: "resolved",
        resolvedOutcome: outcome
      };
    });
    return { txHash: "0xresolve-335" };
  }

  async claimReward(_request: ClaimRewardRequest, _proof: ProofArtifact): Promise<{ txHash: string; payoutUsd: number }> {
    await sleep(410);
    return {
      txHash: "0xclaim-77aa",
      payoutUsd: 3400
    };
  }

  async deposit(amountUsd: number, _noteCommitment: string): Promise<{ txHash: string }> {
    await sleep(300);
    this.vault = {
      ...this.vault,
      userAvailableUsd: Math.max(0, this.vault.userAvailableUsd - amountUsd),
      totalPoolUsd: this.vault.totalPoolUsd + amountUsd,
      userShieldedNotes: this.vault.userShieldedNotes + 1,
      nextNoteIndex: this.vault.nextNoteIndex + 1
    };
    return { txHash: "0xdeposit-f83" };
  }

  async withdraw(request: WithdrawRequest, _proof: ProofArtifact): Promise<{ txHash: string }> {
    await sleep(320);
    this.vault = {
      ...this.vault,
      userAvailableUsd: this.vault.userAvailableUsd + request.amountUsd,
      totalPoolUsd: Math.max(0, this.vault.totalPoolUsd - request.amountUsd)
    };
    return { txHash: "0xwithdraw-44de" };
  }
}

class MockProverAdapter implements ProverAdapter {
  async generatePositionProof(input: PositionProofInput): Promise<ProofArtifact> {
    return proofFromSeed(`position-${input.marketId}-${input.side}`);
  }

  async generateClaimProof(input: ClaimProofInput): Promise<ProofArtifact> {
    return proofFromSeed(`claim-${input.marketId}-${input.expectedOutcome}`);
  }

  async generateWithdrawProof(input: WithdrawProofInput): Promise<ProofArtifact> {
    return proofFromSeed(`withdraw-${input.oldRoot}-${input.amountUsd}`);
  }
}

export const createMockIntegrations = (): IntegrationBundle => {
  return {
    wallet: new MockWalletAdapter(),
    contracts: new MockContractsAdapter(),
    prover: new MockProverAdapter()
  };
};
