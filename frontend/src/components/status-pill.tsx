import type { AsyncStatus } from "@/lib/use-shadow-market";

interface StatusPillProps {
  label: string;
  status: AsyncStatus;
}

export function StatusPill({ label, status }: StatusPillProps): JSX.Element {
  return (
    <div className={`status-pill ${status}`}>
      <span className="status-dot" />
      <span>{label}</span>
    </div>
  );
}
