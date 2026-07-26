import { useState, useEffect } from "react";
import { theme } from "../constants.js";
import { computeTimeCharge, isTimeRake, rakeSummary, blockCharge } from "../lib/rake.js";

const hhmm = (ts) => new Date(ts).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
const dur = (ms) => {
  const mins = Math.max(0, Math.floor(ms / 60000));
  return `${Math.floor(mins / 60)}h ${String(mins % 60).padStart(2, "0")}m`;
};

const Row = ({ label, children }) => (
  <div className="flex items-center justify-between py-1.5">
    <span style={{ color: "rgba(255,255,255,0.6)", fontSize: 13 }}>{label}</span>
    <span style={{ color: theme.textLight, fontSize: 14, fontWeight: 600 }}>{children}</span>
  </div>
);

// Session envelope: elapsed time, hands + per-pot rake this sitting, and — for a
// time venue — the metered vs prepay charge. Start time is editable.
export default function SessionSummary({
  session,
  log,
  profile,
  onSetStart,
  onSetPrepaid,
  onBumpCollections,
  onEndSession,
  onStartNew,
  onClose,
}) {
  const start = session.startedAt;
  const end = session.endedAt;
  const [now, setNow] = useState(() => end || start || new Date().getTime());
  useEffect(() => {
    if (!start || end) {
      setNow(end || start || new Date().getTime());
      return;
    }
    const tick = () => setNow(new Date().getTime());
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [start, end]);
  const elapsedMs = start ? (end || now) - start : 0;

  const handsThis = log.filter((h) => start && h.ts >= start && (!end || h.ts <= end));
  const potRakeTotal = handsThis.reduce((a, h) => a + (h.rake || 0), 0);
  const heroNet = handsThis.reduce((a, h) => a + (h.heroNet || 0), 0);

  const time = isTimeRake(profile);
  const tc = time
    ? computeTimeCharge({ elapsedHours: elapsedMs / 3600000, prepaid: session.prepaid, profile })
    : null;

  // bomb-pot venues (Danville PLO): time is paid per collection — $8 rides
  // into each bomb pot you play (already inside that hand's P&L/rake), and the
  // sit-outs are counted here. The metered figure stays as a cross-check.
  const bombVenue = time && !!profile.bombPot;
  const perBlock = blockCharge(profile);
  const bombsPlayed = bombVenue
    ? handsThis.filter(
        (h) => h.bomb && (h.bomb.participants || []).includes(parseInt(h.seat, 10))
      ).length
    : 0;
  const satOut = session.collections || 0;
  const timePaid = (bombsPlayed + satOut) * perBlock;

  const nudge = (mins) =>
    onSetStart(Math.min((start || now) + mins * 60000, end || new Date().getTime()));

  return (
    <div className="fixed inset-0 z-[75] flex items-end justify-center" style={{ background: "rgba(0,0,0,0.6)" }} onClick={onClose}>
      <div
        className="w-full max-w-sm flex flex-col"
        style={{ background: theme.panel, borderTopLeftRadius: 16, borderTopRightRadius: 16 }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="px-4 py-3 flex items-center justify-between" style={{ borderBottom: "1px solid rgba(255,255,255,0.08)" }}>
          <span style={{ color: theme.textLight, fontSize: 16, fontWeight: 700 }}>
            Session {end ? "· ended" : "· active"}
          </span>
          <button onClick={onClose} style={{ color: "rgba(255,255,255,0.6)", fontSize: 13 }}>Close</button>
        </div>

        <div className="px-4 py-3">
          {!start ? (
            <div style={{ color: "rgba(255,255,255,0.5)", fontSize: 13 }}>No session started yet.</div>
          ) : (
            <>
              <div className="flex items-center justify-between py-1.5">
                <span style={{ color: "rgba(255,255,255,0.6)", fontSize: 13 }}>Started</span>
                <div className="flex items-center gap-1.5">
                  <button onClick={() => nudge(-15)} className="px-2 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.08)", color: theme.textLight, fontSize: 12 }}>−15</button>
                  <span style={{ color: theme.textLight, fontSize: 14, fontWeight: 600, minWidth: 58, textAlign: "center" }}>{hhmm(start)}</span>
                  <button onClick={() => nudge(15)} className="px-2 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.08)", color: theme.textLight, fontSize: 12 }}>+15</button>
                </div>
              </div>
              <Row label={end ? "Ended" : "Now"}>{hhmm(end || now)}</Row>
              <Row label="Elapsed">{dur(elapsedMs)}</Row>
              <div style={{ height: 1, background: "rgba(255,255,255,0.08)", margin: "6px 0" }} />
              <Row label="Hands this session">{handsThis.length}</Row>
              <div className="flex items-center justify-between py-1.5">
                <span style={{ color: "rgba(255,255,255,0.6)", fontSize: 13 }}>Your P&amp;L (stacks)</span>
                <span style={{ color: heroNet >= 0 ? "#7fe0a6" : "#ff9a9a", fontSize: 14, fontWeight: 700 }}>
                  {heroNet >= 0 ? "+" : "−"}${Math.abs(heroNet)}
                </span>
              </div>
              {!time && <Row label="Pot rake paid">${potRakeTotal}</Row>}

              {time && tc && (
                <>
                  <div style={{ height: 1, background: "rgba(255,255,255,0.08)", margin: "6px 0" }} />
                  <div style={{ color: "rgba(255,255,255,0.4)", fontSize: 11, marginBottom: 2 }}>{rakeSummary(profile)}</div>
                  {bombVenue ? (
                    <>
                      <Row label={`Bomb pots played (in the pot)`}>{bombsPlayed} × ${perBlock}</Row>
                      <div className="flex items-center justify-between py-1.5">
                        <span style={{ color: "rgba(255,255,255,0.6)", fontSize: 13 }}>
                          Collections sat out
                        </span>
                        <div className="flex items-center gap-1.5">
                          <button onClick={() => onBumpCollections(-1)} className="px-2.5 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.08)", color: theme.textLight, fontSize: 14 }}>−</button>
                          <span style={{ color: theme.textLight, fontSize: 14, fontWeight: 600, minWidth: 56, textAlign: "center" }}>
                            {satOut} × ${perBlock}
                          </span>
                          <button onClick={() => onBumpCollections(1)} className="px-2.5 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.08)", color: theme.textLight, fontSize: 14 }}>+</button>
                        </div>
                      </div>
                      <div className="flex items-center justify-between py-2">
                        <span style={{ color: theme.textLight, fontSize: 14, fontWeight: 700 }}>Time paid</span>
                        <span style={{ color: theme.gold, fontSize: 18, fontWeight: 800 }}>${timePaid}</span>
                      </div>
                      <div style={{ color: "rgba(255,255,255,0.35)", fontSize: 10.5 }}>
                        Metered cross-check: {tc.hours}h ⇒ ${tc.metered}
                      </div>
                    </>
                  ) : (
                    <>
                      <Row label={`Metered (${tc.hours}h × $${profile.perHour})`}>${tc.metered}</Row>
                      {tc.prepay != null && <Row label="Prepay flat">${tc.prepay}</Row>}
                      <div className="flex items-center justify-between py-2">
                        <span style={{ color: theme.textLight, fontSize: 14, fontWeight: 700 }}>You pay</span>
                        <div className="flex items-center gap-2">
                          <span style={{ color: theme.gold, fontSize: 18, fontWeight: 800 }}>${tc.charge}</span>
                        </div>
                      </div>
                      {tc.prepay != null && (
                        <button
                          onClick={() => onSetPrepaid(!session.prepaid)}
                          className="w-full py-2 rounded-lg font-semibold"
                          style={{ fontSize: 13, background: session.prepaid ? theme.gold : "rgba(255,255,255,0.08)", color: session.prepaid ? theme.ink : theme.textLight }}
                        >
                          {session.prepaid ? `Prepaid $${tc.prepay} ✓` : `Use prepay ($${tc.prepay})`}
                        </button>
                      )}
                    </>
                  )}
                </>
              )}
            </>
          )}
        </div>

        <div className="px-4 py-3 flex gap-2" style={{ borderTop: "1px solid rgba(255,255,255,0.08)" }}>
          {!end && start && (
            <button onClick={onEndSession} className="flex-1 h-11 rounded-xl font-semibold"
              style={{ background: "rgba(138,31,31,0.85)", color: "#fff", fontSize: 14 }}>
              End session
            </button>
          )}
          <button onClick={onStartNew} className="flex-1 h-11 rounded-xl font-semibold"
            style={{ background: theme.gold, color: theme.ink, fontSize: 14 }}>
            {start && !end ? "Restart clock" : "Start new session"}
          </button>
        </div>
      </div>
    </div>
  );
}
