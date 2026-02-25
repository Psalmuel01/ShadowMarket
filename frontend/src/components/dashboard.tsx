"use client";

import { useEffect, useMemo, useState } from "react";
import { ThemeToggle } from "@/components/theme-toggle";
import { StatusPill } from "@/components/status-pill";
import type { ProofArtifact } from "@/lib/types";
import { useShadowMarket } from "@/lib/use-shadow-market";

const formatDateTime = (iso: string): string => {
  const parsed = new Date(iso);
  if (Number.isNaN(parsed.getTime()) || parsed.getTime() === 0) {
    return "-";
  }
  return parsed.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  });
};

const toLocalDateTimeInput = (date: Date): string => {
  const shifted = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return shifted.toISOString().slice(0, 16);
};

const shorten = (value: string): string => {
  if (value.length < 18) {
    return value;
  }
  return `${value.slice(0, 8)}...${value.slice(-6)}`;
};

const parseFelts = (raw: string): string[] => {
  return raw
    .split(/[\s,\n]+/)
    .map((item) => item.trim())
    .filter(Boolean);
};

const toSeverityLabel = (severity: "info" | "success" | "warning"): string => {
  if (severity === "success") {
    return "ok";
  }
  if (severity === "warning") {
    return "warn";
  }
  return "info";
};

export function Dashboard(): JSX.Element {
  const {
    wallet,
    factory,
    markets,
    selectedMarket,
    activity,
    status,
    error,
    setSelectedMarketId,
    connectWallet,
    disconnectWallet,
    createMarket,
    addCommitment,
    resolveMarket,
    claimReward
  } = useShadowMarket();

  const [createQuestionHash, setCreateQuestionHash] = useState<string>("0x1234");
  const [createOracle, setCreateOracle] = useState<string>("0x0b71");
  const [createEndTimeInput, setCreateEndTimeInput] = useState<string>(() =>
    toLocalDateTimeInput(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000))
  );

  const [commitmentValue, setCommitmentValue] = useState<string>("0xabc");
  const [commitProgramHash, setCommitProgramHash] = useState<string>(process.env.NEXT_PUBLIC_POSITION_PROGRAM_HASH ?? "");
  const [commitPublicInputsRaw, setCommitPublicInputsRaw] = useState<string>("");
  const [commitProofRaw, setCommitProofRaw] = useState<string>("");

  const [claimNullifier, setClaimNullifier] = useState<string>("0x111");
  const [claimPayoutLow, setClaimPayoutLow] = useState<string>("0");
  const [claimRecipient, setClaimRecipient] = useState<string>(wallet?.address ?? "");
  const [claimProgramHash, setClaimProgramHash] = useState<string>(process.env.NEXT_PUBLIC_CLAIM_PROGRAM_HASH ?? "");
  const [claimPublicInputsRaw, setClaimPublicInputsRaw] = useState<string>("");
  const [claimProofRaw, setClaimProofRaw] = useState<string>("");

  const statusEntries = useMemo(() => {
    return [
      { label: "Wallet", status: status.connect },
      { label: "Create", status: status.create },
      { label: "Commit", status: status.commitment },
      { label: "Resolve", status: status.resolve },
      { label: "Claim", status: status.claim }
    ] as const;
  }, [status]);

  useEffect(() => {
    if (wallet?.address && !claimRecipient) {
      setClaimRecipient(wallet.address);
    }
  }, [wallet, claimRecipient]);

  const handleCreateMarket = (): void => {
    if (!createQuestionHash.trim() || !createOracle.trim() || !createEndTimeInput.trim()) {
      return;
    }

    const parsedEnd = new Date(createEndTimeInput);
    if (Number.isNaN(parsedEnd.getTime())) {
      return;
    }

    void createMarket({
      questionHash: createQuestionHash.trim(),
      oracle: createOracle.trim(),
      endTimeIso: parsedEnd.toISOString()
    });
  };

  const handleAddCommitment = (): void => {
    if (!selectedMarket || !commitmentValue.trim() || !commitProgramHash.trim()) {
      return;
    }

    const proof: ProofArtifact = {
      programHash: commitProgramHash.trim(),
      publicInputs: parseFelts(commitPublicInputsRaw),
      proof: parseFelts(commitProofRaw)
    };

    void addCommitment(commitmentValue.trim(), proof);
  };

  const handleClaim = (): void => {
    const recipient = claimRecipient.trim() || wallet?.address || "";
    const payoutLow = claimPayoutLow.trim() || "0";
    if (!selectedMarket || !claimNullifier.trim() || !claimProgramHash.trim() || !recipient) {
      return;
    }

    const proof: ProofArtifact = {
      programHash: claimProgramHash.trim(),
      publicInputs: parseFelts(claimPublicInputsRaw),
      proof: parseFelts(claimProofRaw)
    };

    void claimReward(claimNullifier.trim(), payoutLow, recipient, proof);
  };

  return (
    <div className="page-shell">
      <div className="ambient-orb orb-a" />
      <div className="ambient-orb orb-b" />
      <div className="ambient-orb orb-c" />

      <header className="topbar glass">
        <div className="brand-wrap">
          <p className="eyebrow">ShadowMarket MVP</p>
          <h1>Wallet -> Contracts -> ZK Proof Calls</h1>
        </div>
        <div className="topbar-actions">
          <ThemeToggle />
          {wallet ? (
            <button className="button secondary" type="button" onClick={() => void disconnectWallet()}>
              {shorten(wallet.address)}
            </button>
          ) : (
            <button className="button primary" type="button" onClick={() => void connectWallet()}>
              Connect Wallet
            </button>
          )}
        </div>
      </header>

      <section className="hero-grid minimal">
        <article className="glass hero-card reveal">
          <p className="eyebrow">Selected Market</p>
          <h2>#{selectedMarket?.id ?? "-"}</h2>
          <div className="market-meta-row">
            <span>{selectedMarket ? selectedMarket.status.toUpperCase() : "NO_MARKET"}</span>
            <span>Ends {selectedMarket ? formatDateTime(selectedMarket.endTimeIso) : "-"}</span>
            <span>Next index {selectedMarket?.nextIndex ?? "-"}</span>
          </div>
          <div className="kv-grid">
            <div>
              <p>Address</p>
              <strong className="mono truncate">{selectedMarket?.address ?? "-"}</strong>
            </div>
            <div>
              <p>Question Hash</p>
              <strong className="mono truncate">{selectedMarket?.questionHash ?? "-"}</strong>
            </div>
            <div>
              <p>Oracle</p>
              <strong className="mono truncate">{selectedMarket?.oracle ?? "-"}</strong>
            </div>
            <div>
              <p>Merkle Root</p>
              <strong className="mono truncate">{selectedMarket?.merkleRoot ?? "-"}</strong>
            </div>
          </div>
        </article>

        <article className="glass metric-card reveal delay-1">
          <p>Factory Next ID</p>
          <h3>#{factory?.nextMarketId ?? "-"}</h3>
          <small>Source: `MarketFactory.next_market_id`</small>
        </article>

        <article className="glass metric-card reveal delay-2">
          <p>Total Markets</p>
          <h3>{markets.length}</h3>
          <small>Read via factory index</small>
        </article>
      </section>

      <section className="content-grid">
        <aside className="glass panel markets-panel reveal">
          <div className="panel-head">
            <h4>Markets</h4>
            <span>{markets.length} indexed</span>
          </div>
          <div className="markets-list">
            {markets.map((market) => (
              <button
                key={market.address}
                type="button"
                className={`market-item ${selectedMarket?.address === market.address ? "active" : ""}`}
                onClick={() => setSelectedMarketId(market.id)}
              >
                <p>#{market.id} {market.status.toUpperCase()}</p>
                <div>
                  <span>{formatDateTime(market.endTimeIso)}</span>
                  <span>{shorten(market.address)}</span>
                </div>
              </button>
            ))}
          </div>
        </aside>

        <main className="panel-stack">
          <article className="glass panel reveal delay-1">
            <div className="panel-head">
              <h4>Create Market</h4>
              <span>Factory owner call</span>
            </div>

            <label className="field">
              <span>Question Hash (felt)</span>
              <input value={createQuestionHash} onChange={(event) => setCreateQuestionHash(event.target.value)} />
            </label>

            <label className="field">
              <span>Oracle Address</span>
              <input value={createOracle} onChange={(event) => setCreateOracle(event.target.value)} />
            </label>

            <label className="field">
              <span>End Time</span>
              <input
                type="datetime-local"
                value={createEndTimeInput}
                onChange={(event) => setCreateEndTimeInput(event.target.value)}
              />
            </label>

            <div className="action-row">
              <button
                type="button"
                className="button primary"
                disabled={!wallet || status.create === "running"}
                onClick={handleCreateMarket}
              >
                {status.create === "running" ? "Creating..." : "Create Market"}
              </button>
            </div>
          </article>

          <article className="glass panel reveal delay-2">
            <div className="panel-head">
              <h4>Add Commitment (ZK)</h4>
              <span>`Market.add_commitment`</span>
            </div>

            <label className="field">
              <span>Commitment (felt)</span>
              <input value={commitmentValue} onChange={(event) => setCommitmentValue(event.target.value)} />
            </label>

            <label className="field">
              <span>Program Hash</span>
              <input value={commitProgramHash} onChange={(event) => setCommitProgramHash(event.target.value)} />
            </label>

            <label className="field">
              <span>Public Inputs (felt list, comma/space/newline)</span>
              <textarea
                value={commitPublicInputsRaw}
                onChange={(event) => setCommitPublicInputsRaw(event.target.value)}
                rows={3}
              />
            </label>

            <label className="field">
              <span>Proof (felt list)</span>
              <textarea value={commitProofRaw} onChange={(event) => setCommitProofRaw(event.target.value)} rows={3} />
            </label>

            <div className="action-row">
              <button
                type="button"
                className="button primary"
                disabled={!wallet || !selectedMarket || status.commitment === "running"}
                onClick={handleAddCommitment}
              >
                {status.commitment === "running" ? "Submitting..." : "Submit Commitment"}
              </button>
            </div>
          </article>

          <article className="glass panel reveal delay-3">
            <div className="panel-head">
              <h4>Resolve + Claim</h4>
              <span>`resolve_market` and `claim_reward`</span>
            </div>

            <div className="action-row settlement-actions">
              <button
                type="button"
                className="button secondary"
                disabled={!wallet || !selectedMarket || status.resolve === "running"}
                onClick={() => void resolveMarket("yes")}
              >
                Resolve YES
              </button>
              <button
                type="button"
                className="button secondary"
                disabled={!wallet || !selectedMarket || status.resolve === "running"}
                onClick={() => void resolveMarket("no")}
              >
                Resolve NO
              </button>
            </div>

            <label className="field">
              <span>Nullifier (felt)</span>
              <input value={claimNullifier} onChange={(event) => setClaimNullifier(event.target.value)} />
            </label>

            <label className="field">
              <span>Payout Amount Low (u256.low)</span>
              <input value={claimPayoutLow} onChange={(event) => setClaimPayoutLow(event.target.value)} />
            </label>

            <label className="field">
              <span>Payout Recipient</span>
              <input
                value={claimRecipient}
                onChange={(event) => setClaimRecipient(event.target.value)}
                placeholder={wallet?.address ?? "0x..."}
              />
            </label>

            <label className="field">
              <span>Program Hash</span>
              <input value={claimProgramHash} onChange={(event) => setClaimProgramHash(event.target.value)} />
            </label>

            <label className="field">
              <span>Public Inputs (felt list)</span>
              <textarea
                value={claimPublicInputsRaw}
                onChange={(event) => setClaimPublicInputsRaw(event.target.value)}
                rows={3}
              />
            </label>

            <label className="field">
              <span>Proof (felt list)</span>
              <textarea value={claimProofRaw} onChange={(event) => setClaimProofRaw(event.target.value)} rows={3} />
            </label>

            <div className="action-row">
              <button
                type="button"
                className="button primary"
                disabled={!wallet || !selectedMarket || status.claim === "running"}
                onClick={handleClaim}
              >
                {status.claim === "running" ? "Claiming..." : "Claim Reward"}
              </button>
            </div>
          </article>
        </main>

        <aside className="panel-stack">
          <article className="glass panel reveal delay-1">
            <div className="panel-head">
              <h4>Status</h4>
              <span>integration pipeline</span>
            </div>
            <div className="status-grid">
              {statusEntries.map((entry) => (
                <StatusPill key={entry.label} label={entry.label} status={entry.status} />
              ))}
            </div>
            {error ? <p className="error-banner">{error}</p> : null}
          </article>

          <article className="glass panel reveal delay-2">
            <div className="panel-head">
              <h4>Recent Activity</h4>
              <span>tx + proof operations</span>
            </div>
            <div className="activity-list">
              {activity.map((item) => (
                <div key={item.id} className="activity-item">
                  <div className={`activity-badge ${item.severity}`}>{toSeverityLabel(item.severity)}</div>
                  <div>
                    <p>{item.title}</p>
                    <small>{item.detail}</small>
                  </div>
                  <time dateTime={item.atIso}>{formatDateTime(item.atIso)}</time>
                </div>
              ))}
            </div>
          </article>
        </aside>
      </section>
    </div>
  );
}
