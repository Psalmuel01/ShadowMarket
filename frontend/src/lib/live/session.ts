import type { LiveSession } from "@/lib/live/types";

let currentSession: LiveSession | null = null;

export const setLiveSession = (session: LiveSession): void => {
  currentSession = session;
};

export const clearLiveSession = (): void => {
  currentSession = null;
};

export const getLiveSession = (): LiveSession | null => {
  return currentSession;
};
