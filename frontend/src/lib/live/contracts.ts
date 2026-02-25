import type { ContractsAdapter } from "@/lib/integrations/contracts";
import { getLiveSession } from "@/lib/live/session";
import type { StarknetProviderLike, StarknetWalletLike } from "@/lib/live/types";
import type {
  AddCommitmentRequest,
  ClaimRewardRequest,
  CreateMarketRequest,
  FactorySnapshot,
  MarketSummary,
  PositionSide,
  ResolveMarketRequest
} from "@/lib/types";

const factoryAddress = process.env.NEXT_PUBLIC_FACTORY_ADDRESS ?? "";

const requireFactoryAddress = (): string => {
  if (!factoryAddress) {
    throw new Error("Missing NEXT_PUBLIC_FACTORY_ADDRESS in frontend env.");
  }
  return factoryAddress;
};

const requireSession = () => {
  const session = getLiveSession();
  if (!session) {
    throw new Error("Connect wallet first.");
  }
  return session;
};

const tryGetPassiveProvider = (): StarknetProviderLike | null => {
  if (typeof window === "undefined") {
    return null;
  }

  const candidates: Array<StarknetWalletLike | undefined> = [
    window.starknet,
    window.starknet_argentX,
    window.starknet_braavos
  ];

  for (const wallet of candidates) {
    const provider = wallet?.account?.provider ?? wallet?.provider;
    if (provider) {
      return provider;
    }
  }

  return null;
};

const normalizeResult = (raw: unknown): string[] => {
  if (Array.isArray(raw)) {
    return raw.map((item) => String(item));
  }

  if (raw && typeof raw === "object") {
    const maybe = raw as { result?: unknown; response?: unknown; calldata?: unknown };
    if (Array.isArray(maybe.result)) {
      return maybe.result.map((item) => String(item));
    }
    if (Array.isArray(maybe.response)) {
      return maybe.response.map((item) => String(item));
    }
    if (Array.isArray(maybe.calldata)) {
      return maybe.calldata.map((item) => String(item));
    }
  }

  return [];
};

const normalizeTxHash = (raw: unknown): string => {
  if (raw && typeof raw === "object") {
    const tx = raw as { transaction_hash?: unknown; transactionHash?: unknown };
    if (tx.transaction_hash) {
      return String(tx.transaction_hash);
    }
    if (tx.transactionHash) {
      return String(tx.transactionHash);
    }
  }
  return "0x";
};

const call = async (contractAddress: string, entrypoint: string, calldata: string[] = []): Promise<string[]> => {
  const session = getLiveSession();
  const provider = session?.provider ?? tryGetPassiveProvider();
  if (!provider) {
    throw new Error("Wallet provider not available. Connect wallet first.");
  }

  const response = await provider.callContract({
    contractAddress,
    entrypoint,
    calldata
  });
  return normalizeResult(response);
};

const invoke = async (contractAddress: string, entrypoint: string, calldata: string[]): Promise<string> => {
  const session = requireSession();
  const response = await session.account.execute([
    {
      contractAddress,
      entrypoint,
      calldata
    }
  ]);
  return normalizeTxHash(response);
};

const toUnixSeconds = (iso: string): string => {
  const timestamp = new Date(iso).getTime();
  if (Number.isNaN(timestamp) || timestamp <= 0) {
    throw new Error("Invalid end time.");
  }
  return Math.floor(timestamp / 1000).toString();
};

const toIso = (secondsFelt: string): string => {
  const seconds = Number(BigInt(secondsFelt || "0"));
  if (!Number.isFinite(seconds) || seconds <= 0) {
    return new Date(0).toISOString();
  }
  return new Date(seconds * 1000).toISOString();
};

const toBool = (felt: string): boolean => {
  return BigInt(felt || "0") !== 0n;
};

const toSide = (value: string): PositionSide => {
  return value === "1" ? "yes" : "no";
};

const toSpanCalldata = (values: string[]): string[] => {
  return [values.length.toString(), ...values];
};

const normalizeFelt = (value: string): string => {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new Error("Missing felt value.");
  }
  return trimmed;
};

export class LiveContractsAdapter implements ContractsAdapter {
  async getFactorySnapshot(): Promise<FactorySnapshot> {
    const addr = requireFactoryAddress();
    const next = await call(addr, "next_market_id", []);
    return {
      nextMarketId: Number(BigInt(next[0] ?? "0"))
    };
  }

  async listMarkets(): Promise<MarketSummary[]> {
    const addr = requireFactoryAddress();
    const snapshot = await this.getFactorySnapshot();
    const markets: MarketSummary[] = [];

    for (let id = 0; id < snapshot.nextMarketId; id += 1) {
      const idFelt = id.toString();
      try {
        const marketResult = await call(addr, "get_market", [idFelt]);
        const marketAddress = marketResult[0] ?? "0x0";
        if (marketAddress === "0x0" || marketAddress === "0") {
          continue;
        }

        const metadata = await call(addr, "get_market_metadata", [idFelt]);
        const questionHash = metadata[0] ?? "0x0";
        const oracle = metadata[1] ?? "0x0";
        const endTimeIso = toIso(metadata[2] ?? "0");

        const [rootResult, nextIndexResult, resolvedResult] = await Promise.all([
          call(marketAddress, "merkle_root", []),
          call(marketAddress, "next_index", []),
          call(marketAddress, "is_resolved", [])
        ]);

        const isResolved = toBool(resolvedResult[0] ?? "0");
        let resolvedOutcome: PositionSide | null = null;
        if (isResolved) {
          const outcomeResult = await call(marketAddress, "resolution_outcome", []);
          resolvedOutcome = toSide(outcomeResult[0] ?? "0");
        }

        markets.push({
          id: idFelt,
          address: marketAddress,
          questionHash,
          oracle,
          endTimeIso,
          status: isResolved ? "resolved" : "live",
          resolvedOutcome,
          merkleRoot: rootResult[0] ?? "0x0",
          nextIndex: Number(BigInt(nextIndexResult[0] ?? "0"))
        });
      } catch {
        // Skip malformed or temporarily unavailable market entries.
        continue;
      }
    }

    return markets.reverse();
  }

  async createMarket(
    request: CreateMarketRequest
  ): Promise<{ txHash: string; marketId: string; marketAddress: string }> {
    const addr = requireFactoryAddress();
    const before = await this.getFactorySnapshot();

    const txHash = await invoke(addr, "create_market", [
      normalizeFelt(request.questionHash),
      normalizeFelt(request.oracle),
      toUnixSeconds(request.endTimeIso)
    ]);

    const marketId = before.nextMarketId.toString();
    return {
      txHash,
      marketId,
      marketAddress: "pending"
    };
  }

  async addCommitment(request: AddCommitmentRequest): Promise<{ txHash: string }> {
    const txHash = await invoke(request.marketAddress, "add_commitment", [
      normalizeFelt(request.commitment),
      normalizeFelt(request.proof.programHash),
      ...toSpanCalldata(request.proof.publicInputs.map(normalizeFelt)),
      ...toSpanCalldata(request.proof.proof.map(normalizeFelt))
    ]);

    return { txHash };
  }

  async resolveMarket(request: ResolveMarketRequest): Promise<{ txHash: string }> {
    const txHash = await invoke(request.marketAddress, "resolve_market", [request.outcome === "yes" ? "1" : "0"]);
    return { txHash };
  }

  async claimReward(request: ClaimRewardRequest): Promise<{ txHash: string }> {
    const txHash = await invoke(request.marketAddress, "claim_reward", [
      normalizeFelt(request.nullifier),
      normalizeFelt(request.payoutRecipient),
      normalizeFelt(request.payoutAmountLow),
      "0",
      normalizeFelt(request.proof.programHash),
      ...toSpanCalldata(request.proof.publicInputs.map(normalizeFelt)),
      ...toSpanCalldata(request.proof.proof.map(normalizeFelt))
    ]);
    return { txHash };
  }
}
