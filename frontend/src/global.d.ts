import type { StarknetWalletLike } from "@/lib/live/types";

declare global {
  interface Window {
    starknet?: StarknetWalletLike;
    starknet_argentX?: StarknetWalletLike;
    starknet_braavos?: StarknetWalletLike;
  }
}

export {};
