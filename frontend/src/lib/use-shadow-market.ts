"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { IntegrationBundle } from "@/lib/integrations";
import { createMockIntegrations } from "@/lib/mocks/mock-integrations";
import { mockActivity } from "@/lib/mocks/mock-data";
import type { ActivityItem, MarketSummary, PositionSide, VaultSnapshot } from "@/lib/types";
import type { WalletSession } from "@/lib/integrations/wallet";

export type AsyncStatus = "idle" | "running" | "success" | "error";

interface AsyncStates {
  boot: AsyncStatus;
  connect: AsyncStatus;
  position: AsyncStatus;
  claim: AsyncStatus;
  resolve: AsyncStatus;
  deposit: AsyncStatus;
  withdraw: AsyncStatus;
}

const defaultStates: AsyncStates = {
  boot: "idle",
  connect: "idle",
  position: "idle",
  claim: "idle",
  resolve: "idle",
  deposit: "idle",
  withdraw: "idle"
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
  ].slice(0, 12);
};

export interface ShadowMarketState {
  integrations: IntegrationBundle;
  wallet: WalletSession | null;
  markets: MarketSummary[];
  selectedMarket: MarketSummary | null;
  vault: VaultSnapshot | null;
  activity: ActivityItem[];
  status: AsyncStates;
  error: string | null;
  setSelectedMarketId: (marketId: string) => void;
  connectWallet: () => Promise<void>;
  disconnectWallet: () => Promise<void>;
  placePrivatePosition: (side: PositionSide, amountUsd: number) => Promise<void>;
  resolveMarket: (outcome: PositionSide) => Promise<void>;
  claimReward: () => Promise<void>;
  depositCollateral: (amountUsd: number) => Promise<void>;
  withdrawCollateral: (amountUsd: number) => Promise<void>;
  refresh: () => Promise<void>;
}

export const useShadowMarket = (): ShadowMarketState => {
  const integrations = useMemo<IntegrationBundle>(() => createMockIntegrations(), []);
  const [wallet, setWallet] = useState<WalletSession | null>(null);
  const [markets, setMarkets] = useState<MarketSummary[]>([]);
  const [selectedMarketId, setSelectedMarketId] = useState<string | null>(null);
  const [vault, setVault] = useState<VaultSnapshot | null>(null);
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
      const nextMarkets = await integrations.contracts.listMarkets();
      setMarkets(nextMarkets);
      if (!selectedMarketId && nextMarkets[0]) {
        setSelectedMarketId(nextMarkets[0].id);
      }

      const activeSession = await integrations.wallet.getActiveSession();
      setWallet(activeSession);
      if (activeSession) {
        const snapshot = await integrations.contracts.getVaultSnapshot(activeSession.address);
        setVault(snapshot);
      }
    });
  }, [integrations, selectedMarketId, withStatus]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const connectWallet = useCallback(async (): Promise<void> => {
    await withStatus("connect", async () => {
      const session = await integrations.wallet.connect();
      setWallet(session);
      const snapshot = await integrations.contracts.getVaultSnapshot(session.address);
      setVault(snapshot);
      setActivity((previous) =>
        prependActivity(previous, "Wallet connected", `${session.connector} on ${session.chainId}`, "success")
      );
    });
  }, [integrations, withStatus]);

  const disconnectWallet = useCallback(async (): Promise<void> => {
    await integrations.wallet.disconnect();
    setWallet(null);
    setVault(null);
    setActivity((previous) => prependActivity(previous, "Wallet disconnected", "Session cleared", "info"));
  }, [integrations]);

  const placePrivatePosition = useCallback(
    async (side: PositionSide, amountUsd: number): Promise<void> => {
      if (!selectedMarket) {
        return;
      }
      await withStatus("position", async () => {
        const commitment = `0xcommit-${selectedMarket.id}-${Date.now().toString(16)}`;
        const proof = await integrations.prover.generatePositionProof({
          marketId: selectedMarket.id,
          side,
          amountUsd,
          commitment,
          previousRoot: selectedMarket.currentMerkleRoot
        });

        const receipt = await integrations.contracts.submitPosition(
          {
            marketId: selectedMarket.id,
            side,
            amountUsd,
            collateralCommitment: commitment
          },
          proof
        );

        setActivity((previous) =>
          prependActivity(
            previous,
            "Private position submitted",
            `Market #${selectedMarket.id} ${side.toUpperCase()} $${amountUsd.toLocaleString()} | ${receipt.txHash}`,
            "success"
          )
        );
      });
      await refresh();
    },
    [integrations, refresh, selectedMarket, withStatus]
  );

  const resolveMarket = useCallback(
    async (outcome: PositionSide): Promise<void> => {
      if (!selectedMarket) {
        return;
      }
      await withStatus("resolve", async () => {
        const receipt = await integrations.contracts.resolveMarket(selectedMarket.id, outcome);
        setActivity((previous) =>
          prependActivity(
            previous,
            "Market resolved",
            `Market #${selectedMarket.id} resolved to ${outcome.toUpperCase()} | ${receipt.txHash}`,
            "warning"
          )
        );
      });
      await refresh();
    },
    [integrations, refresh, selectedMarket, withStatus]
  );

  const claimReward = useCallback(async (): Promise<void> => {
    if (!selectedMarket || !wallet) {
      return;
    }
    await withStatus("claim", async () => {
      const expectedOutcome = selectedMarket.resolvedOutcome ?? "yes";
      const proof = await integrations.prover.generateClaimProof({
        marketId: selectedMarket.id,
        expectedOutcome,
        payoutRecipient: wallet.address
      });

      const receipt = await integrations.contracts.claimReward(
        {
          marketId: selectedMarket.id,
          payoutRecipient: wallet.address
        },
        proof
      );

      setActivity((previous) =>
        prependActivity(
          previous,
          "Reward claimed",
          `Payout $${receipt.payoutUsd.toLocaleString()} sent to ${wallet.address} | ${receipt.txHash}`,
          "success"
        )
      );
    });
    await refresh();
  }, [integrations, refresh, selectedMarket, wallet, withStatus]);

  const depositCollateral = useCallback(
    async (amountUsd: number): Promise<void> => {
      await withStatus("deposit", async () => {
        const receipt = await integrations.contracts.deposit(amountUsd, `0xnote-${Date.now().toString(16)}`);
        setActivity((previous) =>
          prependActivity(
            previous,
            "Collateral shielded",
            `$${amountUsd.toLocaleString()} deposited into ShieldVault | ${receipt.txHash}`,
            "info"
          )
        );
      });
      if (wallet) {
        const snapshot = await integrations.contracts.getVaultSnapshot(wallet.address);
        setVault(snapshot);
      }
    },
    [integrations, wallet, withStatus]
  );

  const withdrawCollateral = useCallback(
    async (amountUsd: number): Promise<void> => {
      if (!wallet || !vault) {
        return;
      }
      await withStatus("withdraw", async () => {
        const proof = await integrations.prover.generateWithdrawProof({
          amountUsd,
          recipient: wallet.address,
          oldRoot: vault.noteRoot
        });
        const receipt = await integrations.contracts.withdraw(
          {
            amountUsd,
            recipient: wallet.address
          },
          proof
        );

        setActivity((previous) =>
          prependActivity(
            previous,
            "Collateral withdrawn",
            `$${amountUsd.toLocaleString()} unlocked to ${wallet.address} | ${receipt.txHash}`,
            "info"
          )
        );
      });
      const snapshot = await integrations.contracts.getVaultSnapshot(wallet.address);
      setVault(snapshot);
    },
    [integrations, vault, wallet, withStatus]
  );

  return {
    integrations,
    wallet,
    markets,
    selectedMarket,
    vault,
    activity,
    status,
    error,
    setSelectedMarketId,
    connectWallet,
    disconnectWallet,
    placePrivatePosition,
    resolveMarket,
    claimReward,
    depositCollateral,
    withdrawCollateral,
    refresh
  };
};
