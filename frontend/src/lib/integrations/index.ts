import type { ContractsAdapter } from "@/lib/integrations/contracts";
import type { WalletAdapter } from "@/lib/integrations/wallet";

export interface IntegrationBundle {
  wallet: WalletAdapter;
  contracts: ContractsAdapter;
}
