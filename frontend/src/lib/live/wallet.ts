import type { WalletAdapter, WalletSession } from "@/lib/integrations/wallet";
import { clearLiveSession, getLiveSession, setLiveSession } from "@/lib/live/session";
import type { StarknetAccountLike, StarknetProviderLike, StarknetWalletLike } from "@/lib/live/types";

const getInjectedWallet = (): StarknetWalletLike | null => {
  if (typeof window === "undefined") {
    return null;
  }

  const candidates = [window.starknet, window.starknet_argentX, window.starknet_braavos];

  for (const candidate of candidates) {
    if (candidate) {
      return candidate;
    }
  }
  return null;
};

const normalizeSession = (wallet: StarknetWalletLike): WalletSession => {
  const address = wallet.account?.address ?? wallet.selectedAddress ?? "";
  return {
    address,
    chainId: wallet.chainId ?? "SN_UNKNOWN",
    connector: wallet.name ?? wallet.id ?? "Injected Wallet"
  };
};

const resolveAccountAndProvider = (wallet: StarknetWalletLike): { account: StarknetAccountLike; provider: StarknetProviderLike } => {
  const account = wallet.account;
  if (!account) {
    throw new Error("Wallet account not found after connect.");
  }

  const provider = account.provider ?? wallet.provider;
  if (!provider) {
    throw new Error("Wallet provider not available.");
  }

  return { account, provider };
};

export class LiveWalletAdapter implements WalletAdapter {
  async connect(): Promise<WalletSession> {
    const wallet = getInjectedWallet();
    if (!wallet) {
      throw new Error("No Starknet wallet detected. Install ArgentX or Braavos.");
    }

    if (wallet.enable) {
      try {
        await wallet.enable({ showModal: true });
      } catch {
        await wallet.enable();
      }
    }

    const { account, provider } = resolveAccountAndProvider(wallet);
    setLiveSession({ wallet, account, provider });
    return normalizeSession(wallet);
  }

  async disconnect(): Promise<void> {
    clearLiveSession();
  }

  async getActiveSession(): Promise<WalletSession | null> {
    const current = getLiveSession();
    if (current) {
      return normalizeSession(current.wallet);
    }

    const wallet = getInjectedWallet();
    if (!wallet) {
      return null;
    }

    if (!wallet.account) {
      return null;
    }

    const { account, provider } = resolveAccountAndProvider(wallet);
    setLiveSession({ wallet, account, provider });
    return normalizeSession(wallet);
  }
}
