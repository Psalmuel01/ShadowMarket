import type { IntegrationBundle } from "@/lib/integrations";
import { createLiveIntegrations } from "@/lib/live/integrations";
import { createMockIntegrations } from "@/lib/mocks/mock-integrations";

export const createIntegrations = (): IntegrationBundle => {
  const mode = (process.env.NEXT_PUBLIC_INTEGRATION_MODE ?? "live").toLowerCase();
  if (mode === "mock") {
    return createMockIntegrations();
  }
  return createLiveIntegrations();
};
