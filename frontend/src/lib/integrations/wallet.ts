export interface WalletSession {
  address: string;
  chainId: string;
  connector: string;
}

export interface WalletAdapter {
  connect(): Promise<WalletSession>;
  disconnect(): Promise<void>;
  getActiveSession(): Promise<WalletSession | null>;
}
