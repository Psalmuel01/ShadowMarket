export interface StarknetCall {
  contractAddress: string;
  entrypoint: string;
  calldata: string[];
}

export interface StarknetProviderLike {
  callContract(call: StarknetCall): Promise<unknown>;
}

export interface StarknetExecuteResult {
  transaction_hash?: string;
  transactionHash?: string;
}

export interface StarknetAccountLike {
  address: string;
  provider?: StarknetProviderLike;
  execute(calls: StarknetCall | StarknetCall[]): Promise<StarknetExecuteResult>;
}

export interface StarknetWalletLike {
  id?: string;
  name?: string;
  chainId?: string;
  selectedAddress?: string;
  isConnected?: boolean;
  account?: StarknetAccountLike;
  provider?: StarknetProviderLike;
  enable?(options?: unknown): Promise<string[]>;
}

export interface LiveSession {
  wallet: StarknetWalletLike;
  account: StarknetAccountLike;
  provider: StarknetProviderLike;
}
