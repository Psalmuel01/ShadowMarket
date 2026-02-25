import type { IntegrationBundle } from "@/lib/integrations";
import { LiveContractsAdapter } from "@/lib/live/contracts";
import { LiveWalletAdapter } from "@/lib/live/wallet";

export const createLiveIntegrations = (): IntegrationBundle => {
  return {
    wallet: new LiveWalletAdapter(),
    contracts: new LiveContractsAdapter()
  };
};
