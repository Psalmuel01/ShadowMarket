"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { createIntegrations } from "@/lib/use-integrations";
import type { IntegrationBundle } from "@/lib/integrations";
import { mockActivity } from "@/lib/mocks/mock-data";
import type {
  ActivityItem,
  CreateMarketRequest,
  FactorySnapshot,
  MarketSummary,
  PositionSide,
  ProofArtifact
} from "@/lib/types";
import type { WalletSession } from "@/lib/integrations/wallet";

export type AsyncStatus = "idle" | "running" | "success" | "error";

interface AsyncStates {
  boot: AsyncStatus;
  connect: AsyncStatus;
  create: AsyncStatus;
  commitment: AsyncStatus;
  resolve: AsyncStatus;
  claim: AsyncStatus;
}

const defaultStates: AsyncStates = {
  boot: "idle",
  connect: "idle",
  create: "idle",
  commitment: "idle",
  resolve: "idle",
  claim: "idle"
};

const formatError = (error: unknown): string => {
  if (error instanceof Error) {
    return error.message;
  }
  return "Unexpected failure";
};

const prependActivity = (
  items: ActivityItem[],
  title: string,
  detail: string,
  severity: ActivityItem["severity"]
): ActivityItem[] => {
  return [
    {
      id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
      title,
      detail,
      atIso: new Date().toISOString(),
      severity
    },
    ...items
  ].slice(0, 15);
};

export interface ShadowMarketState {
  integrations: IntegrationBundle;
  wallet: WalletSession | null;
  factory: FactorySnapshot | null;
  markets: MarketSummary[];
  selectedMarket: MarketSummary | null;
  activity: ActivityItem[];
  status: AsyncStates;
  error: string | null;
  setSelectedMarketId: (marketId: string) => void;
  connectWallet: () => Promise<void>;
  disconnectWallet: () => Promise<void>;
  createMarket: (request: CreateMarketRequest) => Promise<void>;
  addCommitment: (commitment: string, proof: ProofArtifact) => Promise<void>;
  resolveMarket: (outcome: PositionSide) => Promise<void>;
  claimReward: (
    nullifier: string,
    payoutAmountLow: string,
    payoutRecipient: string,
    proof: ProofArtifact
  ) => Promise<void>;
  refresh: () => Promise<void>;
}

export const useShadowMarket = (): ShadowMarketState => {
  const integrations = useMemo<IntegrationBundle>(() => createIntegrations(), []);
  const [wallet, setWallet] = useState<WalletSession | null>(null);
  const [factory, setFactory] = useState<FactorySnapshot | null>(null);
  const [markets, setMarkets] = useState<MarketSummary[]>([]);
  const [selectedMarketId, setSelectedMarketId] = useState<string | null>(null);
  const [activity, setActivity] = useState<ActivityItem[]>(mockActivity);
  const [status, setStatus] = useState<AsyncStates>(defaultStates);
  const [error, setError] = useState<string | null>(null);

  const selectedMarket = useMemo(() => {
    if (!selectedMarketId) {
      return markets[0] ?? null;
    }
    return markets.find((market) => market.id === selectedMarketId) ?? markets[0] ?? null;
  }, [markets, selectedMarketId]);

  const withStatus = useCallback(async <T,>(key: keyof AsyncStates, fn: () => Promise<T>): Promise<T> => {
    setStatus((previous) => ({ ...previous, [key]: "running" }));
    setError(null);
    try {
      const result = await fn();
      setStatus((previous) => ({ ...previous, [key]: "success" }));
      return result;
    } catch (caught) {
      setStatus((previous) => ({ ...previous, [key]: "error" }));
      setError(formatError(caught));
      throw caught;
    }
  }, []);

  const refresh = useCallback(async (): Promise<void> => {
    await withStatus("boot", async () => {
      const activeSession = await integrations.wallet.getActiveSession();
      setWallet(activeSession);

      if (!activeSession) {
        setFactory(null);
        setMarkets([]);
        return;
      }

      const [nextFactory, nextMarkets] = await Promise.all([
        integrations.contracts.getFactorySnapshot(),
        integrations.contracts.listMarkets()
      ]);

      setFactory(nextFactory);
      setMarkets(nextMarkets);
      if (!selectedMarketId && nextMarkets[0]) {
        setSelectedMarketId(nextMarkets[0].id);
      }
    });
  }, [integrations, selectedMarketId, withStatus]);

  useEffect(() => {
    void refresh().catch(() => {
      // status/error state is handled inside withStatus.
    });
  }, [refresh]);

  const connectWallet = useCallback(async (): Promise<void> => {
    await withStatus("connect", async () => {
      const session = await integrations.wallet.connect();
      setWallet(session);
      setActivity((previous) =>
        prependActivity(previous, "Wallet connected", `${session.connector} on ${session.chainId}`, "success")
      );
    });
    await refresh().catch(() => {
      // surfaced via status/error state
    });
  }, [integrations, refresh, withStatus]);

  const disconnectWallet = useCallback(async (): Promise<void> => {
    await integrations.wallet.disconnect();
    setWallet(null);
    setFactory(null);
    setMarkets([]);
    setActivity((previous) => prependActivity(previous, "Wallet disconnected", "Session cleared", "info"));
  }, [integrations]);

  const createMarket = useCallback(
    async (request: CreateMarketRequest): Promise<void> => {
      await withStatus("create", async () => {
        const receipt = await integrations.contracts.createMarket(request);
        setActivity((previous) =>
          prependActivity(
            previous,
            "Market created",
            `Market #${receipt.marketId} deployed at ${receipt.marketAddress} | ${receipt.txHash}`,
            "success"
          )
        );
        setSelectedMarketId(receipt.marketId);
      });
      await refresh().catch(() => {
        // surfaced via status/error state
      });
    },
    [integrations, refresh, withStatus]
  );

  const addCommitment = useCallback(
    async (commitment: string, proof: ProofArtifact): Promise<void> => {
      if (!selectedMarket) {
        return;
      }
      await withStatus("commitment", async () => {
        const receipt = await integrations.contracts.addCommitment({
          marketAddress: selectedMarket.address,
          commitment,
          proof
        });

        setActivity((previous) =>
          prependActivity(
            previous,
            "Commitment added",
            `Market #${selectedMarket.id} commitment inserted | ${receipt.txHash}`,
            "success"
          )
        );
      });
      await refresh().catch(() => {
        // surfaced via status/error state
      });
    },
    [integrations, refresh, selectedMarket, withStatus]
  );

  const resolveMarket = useCallback(
    async (outcome: PositionSide): Promise<void> => {
      if (!selectedMarket) {
        return;
      }
      await withStatus("resolve", async () => {
        const receipt = await integrations.contracts.resolveMarket({
          marketAddress: selectedMarket.address,
          outcome
        });
        setActivity((previous) =>
          prependActivity(
            previous,
            "Market resolved",
            `Market #${selectedMarket.id} -> ${outcome.toUpperCase()} | ${receipt.txHash}`,
            "warning"
          )
        );
      });
      await refresh().catch(() => {
        // surfaced via status/error state
      });
    },
    [integrations, refresh, selectedMarket, withStatus]
  );

  const claimReward = useCallback(
    async (
      nullifier: string,
      payoutAmountLow: string,
      payoutRecipient: string,
      proof: ProofArtifact
    ): Promise<void> => {
      if (!selectedMarket) {
        return;
      }
      await withStatus("claim", async () => {
        const receipt = await integrations.contracts.claimReward({
          marketAddress: selectedMarket.address,
          nullifier,
          payoutRecipient,
          payoutAmountLow,
          proof
        });

        setActivity((previous) =>
          prependActivity(
            previous,
            "Reward claimed",
            `Market #${selectedMarket.id} nullifier ${nullifier} | ${receipt.txHash}`,
            "success"
          )
        );
      });
      await refresh().catch(() => {
        // surfaced via status/error state
      });
    },
    [integrations, refresh, selectedMarket, withStatus]
  );

  return {
    integrations,
    wallet,
    factory,
    markets,
    selectedMarket,
    activity,
    status,
    error,
    setSelectedMarketId,
    connectWallet,
    disconnectWallet,
    createMarket,
    addCommitment,
    resolveMarket,
    claimReward,
    refresh
  };
};
