"use client";

import { useMemo, useState } from "react";
import { ThemeToggle } from "@/components/theme-toggle";
import { StatusPill } from "@/components/status-pill";
import type { PositionSide } from "@/lib/types";
import { useShadowMarket } from "@/lib/use-shadow-market";

const formatUsd = (value: number): string => {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0
  }).format(value);
};

const formatDateTime = (iso: string): string => {
  return new Date(iso).toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  });
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
    markets,
    selectedMarket,
    vault,
    activity,
    status,
    error,
    setSelectedMarketId,
    connectWallet,
    disconnectWallet,
    placePrivatePosition,
    resolveMarket,
    claimReward,
    depositCollateral,
    withdrawCollateral
  } = useShadowMarket();

  const [positionSide, setPositionSide] = useState<PositionSide>("yes");
  const [positionAmount, setPositionAmount] = useState<number>(1000);
  const [vaultAmount, setVaultAmount] = useState<number>(500);

  const canClaim = Boolean(wallet && selectedMarket?.status === "resolved");

  const executionStatuses = useMemo(() => {
    return [
      { label: "Wallet", status: status.connect },
      { label: "Position", status: status.position },
      { label: "Claim", status: status.claim },
      { label: "Vault", status: status.deposit === "running" || status.withdraw === "running" ? "running" : "idle" }
    ] as const;
  }, [status]);

  return (
    <div className="page-shell">
      <div className="ambient-orb orb-a" />
      <div className="ambient-orb orb-b" />
      <div className="ambient-orb orb-c" />

      <header className="topbar glass">
        <div className="brand-wrap">
          <p className="eyebrow">ShadowMarket</p>
          <h1>Private Prediction Desk</h1>
        </div>
        <div className="topbar-actions">
          <ThemeToggle />
          {wallet ? (
            <button className="button secondary" type="button" onClick={() => void disconnectWallet()}>
              {wallet.address}
            </button>
          ) : (
            <button className="button primary" type="button" onClick={() => void connectWallet()}>
              Connect Starknet Wallet
            </button>
          )}
        </div>
      </header>

      <section className="hero-grid">
        <article className="glass hero-card reveal">
          <p className="eyebrow">Selected Market</p>
          <h2>{selectedMarket?.question ?? "Loading markets..."}</h2>
          <div className="market-meta-row">
            <span>{selectedMarket?.category ?? "-"}</span>
            <span>Oracle {selectedMarket?.oracle ?? "-"}</span>
            <span>Ends {selectedMarket ? formatDateTime(selectedMarket.endTimeIso) : "-"}</span>
          </div>
          <div className="odds-wrap">
            <div>
              <p>YES</p>
              <strong>{selectedMarket?.yesOdds ?? 0}%</strong>
            </div>
            <div>
              <p>NO</p>
              <strong>{selectedMarket?.noOdds ?? 0}%</strong>
            </div>
          </div>
        </article>

        <article className="glass metric-card reveal delay-1">
          <p>Total Volume</p>
          <h3>{formatUsd(selectedMarket?.volumeUsd ?? 0)}</h3>
          <small>{selectedMarket?.totalCommitments ?? 0} private commitments</small>
        </article>

        <article className="glass metric-card reveal delay-2">
          <p>Merkle Root</p>
          <h3 className="mono truncate">{selectedMarket?.currentMerkleRoot ?? "0x0"}</h3>
          <small>Bound to Noir public inputs</small>
        </article>

        <article className="glass metric-card reveal delay-3">
          <p>ShieldVault Root</p>
          <h3 className="mono truncate">{vault?.noteRoot ?? "Connect wallet"}</h3>
          <small>Next note #{vault?.nextNoteIndex ?? "-"}</small>
        </article>
      </section>

      <section className="content-grid">
        <aside className="glass panel markets-panel reveal">
          <div className="panel-head">
            <h4>Markets</h4>
            <span>{markets.length} loaded</span>
          </div>
          <div className="markets-list">
            {markets.map((market) => (
              <button
                key={market.id}
                type="button"
                className={`market-item ${selectedMarket?.id === market.id ? "active" : ""}`}
                onClick={() => setSelectedMarketId(market.id)}
              >
                <p>{market.question}</p>
                <div>
                  <span>{market.status.toUpperCase()}</span>
                  <span>{formatUsd(market.volumeUsd)}</span>
                </div>
              </button>
            ))}
          </div>
        </aside>

        <main className="panel-stack">
          <article className="glass panel reveal delay-1">
            <div className="panel-head">
              <h4>Private Position</h4>
              <span>Commitment + proof + insert</span>
            </div>

            <div className="side-toggle" role="tablist" aria-label="Position side">
              <button
                type="button"
                className={positionSide === "yes" ? "active" : ""}
                onClick={() => setPositionSide("yes")}
              >
                Long YES
              </button>
              <button
                type="button"
                className={positionSide === "no" ? "active" : ""}
                onClick={() => setPositionSide("no")}
              >
                Long NO
              </button>
            </div>

            <label className="field">
              <span>Collateral (USD)</span>
              <input
                type="number"
                min={10}
                step={10}
                value={positionAmount}
                onChange={(event) => setPositionAmount(Number(event.target.value))}
              />
            </label>

            <div className="action-row">
              <button
                type="button"
                className="button primary"
                disabled={!wallet || !selectedMarket || status.position === "running"}
                onClick={() => void placePrivatePosition(positionSide, positionAmount)}
              >
                {status.position === "running" ? "Generating proof..." : "Submit Private Position"}
              </button>
            </div>
          </article>

          <article className="glass panel reveal delay-2">
            <div className="panel-head">
              <h4>Settlement</h4>
              <span>Resolve then claim</span>
            </div>

            <div className="action-row settlement-actions">
              <button
                type="button"
                className="button secondary"
                disabled={!selectedMarket || selectedMarket.status === "resolved" || status.resolve === "running"}
                onClick={() => void resolveMarket("yes")}
              >
                Resolve YES
              </button>
              <button
                type="button"
                className="button secondary"
                disabled={!selectedMarket || selectedMarket.status === "resolved" || status.resolve === "running"}
                onClick={() => void resolveMarket("no")}
              >
                Resolve NO
              </button>
              <button
                type="button"
                className="button primary"
                disabled={!canClaim || status.claim === "running"}
                onClick={() => void claimReward()}
              >
                {status.claim === "running" ? "Claiming..." : "Claim Reward"}
              </button>
            </div>
          </article>

          <article className="glass panel reveal delay-3">
            <div className="panel-head">
              <h4>Proof Pipeline</h4>
              <span>Client intent -> Noir proof -> Garaga verify</span>
            </div>
            <div className="status-grid">
              {executionStatuses.map((entry) => (
                <StatusPill key={entry.label} label={entry.label} status={entry.status} />
              ))}
            </div>
            <div className="integration-map">
              <div>
                <h5>Position Entry</h5>
                <p>`position_commitment.nr` -> `Market.add_commitment` -> root update.</p>
              </div>
              <div>
                <h5>Claim Flow</h5>
                <p>`claim_reward.nr` -> `Market.claim_reward` -> nullifier mark + payout.</p>
              </div>
              <div>
                <h5>Vault Flow</h5>
                <p>`withdraw` proof -> `ShieldVault.withdraw` with strict root continuity.</p>
              </div>
            </div>
            {error ? <p className="error-banner">{error}</p> : null}
          </article>
        </main>

        <aside className="panel-stack">
          <article className="glass panel reveal delay-1">
            <div className="panel-head">
              <h4>ShieldVault</h4>
              <span>Encrypted note lifecycle</span>
            </div>

            <div className="vault-stats">
              <div>
                <p>Pool</p>
                <strong>{formatUsd(vault?.totalPoolUsd ?? 0)}</strong>
              </div>
              <div>
                <p>Available</p>
                <strong>{formatUsd(vault?.userAvailableUsd ?? 0)}</strong>
              </div>
              <div>
                <p>Your Notes</p>
                <strong>{vault?.userShieldedNotes ?? 0}</strong>
              </div>
            </div>

            <label className="field">
              <span>Amount (USD)</span>
              <input
                type="number"
                min={10}
                step={10}
                value={vaultAmount}
                onChange={(event) => setVaultAmount(Number(event.target.value))}
              />
            </label>

            <div className="action-row settlement-actions">
              <button
                type="button"
                className="button secondary"
                disabled={!wallet || status.deposit === "running"}
                onClick={() => void depositCollateral(vaultAmount)}
              >
                {status.deposit === "running" ? "Depositing..." : "Deposit"}
              </button>
              <button
                type="button"
                className="button secondary"
                disabled={!wallet || status.withdraw === "running"}
                onClick={() => void withdrawCollateral(vaultAmount)}
              >
                {status.withdraw === "running" ? "Withdrawing..." : "Withdraw"}
              </button>
            </div>
          </article>

          <article className="glass panel reveal delay-2">
            <div className="panel-head">
              <h4>Recent Activity</h4>
              <span>on-chain + prover events</span>
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
