import type { ContractsAdapter } from "@/lib/integrations/contracts";
import type { ProverAdapter } from "@/lib/integrations/prover";
import type { WalletAdapter } from "@/lib/integrations/wallet";

export interface IntegrationBundle {
  wallet: WalletAdapter;
  contracts: ContractsAdapter;
  prover: ProverAdapter;
}
