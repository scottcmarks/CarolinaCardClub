import { useState, useEffect } from "react";
import { Clock } from "lucide-react";
import { theme } from "../constants.js";
import { computeTimeCharge, isTimeRake } from "../lib/rake.js";

const fmt = (ms) => {
  const mins = Math.max(0, Math.floor(ms / 60000));
  return `${Math.floor(mins / 60)}:${String(mins % 60).padStart(2, "0")}`;
};

// Small tappable pill showing the current sitting's elapsed time (live), plus
// the running metered charge for a time-rake venue. Ticks on its own so it
// doesn't re-render the rest of the app.
export default function SessionClock({ startedAt, endedAt, prepaid, profile, onClick }) {
  const [now, setNow] = useState(() => (endedAt || (startedAt ?? 0)));
  useEffect(() => {
    if (!startedAt || endedAt) {
      setNow(endedAt || startedAt || 0);
      return;
    }
    const tick = () => setNow(new Date().getTime());
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [startedAt, endedAt]);

  if (!startedAt) return null;
  const elapsedMs = (endedAt || now) - startedAt;
  const time = isTimeRake(profile);
  const charge = time
    ? computeTimeCharge({ elapsedHours: elapsedMs / 3600000, prepaid, profile }).charge
    : null;

  return (
    <button
      onClick={onClick}
      className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg shrink-0"
      style={{
        background: endedAt ? "rgba(138,31,31,0.35)" : "rgba(255,255,255,0.06)",
        color: theme.textLight,
        fontSize: 12,
      }}
    >
      <Clock size={12} color={endedAt ? "#ff9a9a" : theme.gold} />
      {fmt(elapsedMs)}
      {time && <span style={{ color: theme.gold, fontWeight: 700 }}>${charge}</span>}
    </button>
  );
}
