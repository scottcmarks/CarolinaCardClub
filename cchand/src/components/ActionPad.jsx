import { useState, useLayoutEffect, useRef } from "react";
import { theme } from "../constants.js";

const PAD_W = 198;
const PAD_H = 312;

// Floating numeric action pad: 7 8 9 / 4 5 6 / 1 2 3 / ✖ 0 ✓, plus "!" all-in.
// Pot-limit games also get a POT button (the max legal raise-to).
// Positions itself so the bottom-row 0 sits just under the actor's seat.
export default function ActionPad({ actorSeat, actorLabel, stack, toCall, currentBet, potMaxTo, onAct, onAllIn }) {
  const [amount, setAmount] = useState("");
  const [err, setErr] = useState("");
  const [pos, setPos] = useState(null);
  const padRef = useRef(null);

  // reset typed amount whenever the actor changes
  useLayoutEffect(() => {
    setAmount("");
    setErr("");
  }, [actorSeat]);

  // anchor the pad to the actor's seat element
  useLayoutEffect(() => {
    const place = () => {
      const el = document.querySelector(`[data-seat="${actorSeat}"]`);
      if (!el) return;
      const r = el.getBoundingClientRect();
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      // want the pad's 0 button (bottom-center) just below the seat center
      let left = r.left + r.width / 2 - PAD_W / 2;
      let top = r.bottom + 6;
      if (top + PAD_H > vh - 6) top = r.top - PAD_H - 6; // flip above
      left = Math.max(6, Math.min(left, vw - PAD_W - 6));
      top = Math.max(6, Math.min(top, vh - PAD_H - 6));
      setPos({ left, top });
    };
    place();
    window.addEventListener("resize", place);
    return () => window.removeEventListener("resize", place);
  }, [actorSeat]);

  const n = parseInt(amount, 10) || 0;
  const press = (d) => {
    setErr("");
    setAmount((a) => (a + d).slice(0, 6));
  };
  const confirm = () => {
    if (amount) {
      // a typed amount is always a bet/raise-to; reject if it isn't a legal raise
      if (n > currentBet) onAct(currentBet > 0 ? "raise" : "bet", n);
      else setErr(`Must exceed $${currentBet}`);
    } else if (toCall > 0) onAct("call");
    else onAct("check");
  };

  const checkLabel = amount ? `→ $${n}` : toCall > 0 ? `Call $${toCall}` : "Check";

  const Btn = ({ children, onClick, bg, color, grow, fontSize = 22 }) => (
    <button
      onClick={onClick}
      className="rounded-xl flex items-center justify-center font-bold active:scale-95"
      style={{
        height: 52,
        background: bg || theme.card,
        color: color || theme.ink,
        fontSize,
        boxShadow: "0 2px 0 rgba(0,0,0,0.35)",
        transition: "transform 80ms",
        flex: grow ? 1 : undefined,
      }}
    >
      {children}
    </button>
  );

  if (!pos) return null;

  return (
    <div
      ref={padRef}
      style={{
        position: "fixed",
        left: pos.left,
        top: pos.top,
        width: PAD_W,
        zIndex: 60,
        padding: 8,
        background: "rgba(16,38,31,0.97)",
        border: "1px solid rgba(201,162,39,0.55)",
        borderRadius: 16,
        boxShadow: "0 10px 30px rgba(0,0,0,0.55)",
      }}
    >
      <div
        className="flex items-center justify-between"
        style={{ marginBottom: 6, padding: "0 2px" }}
      >
        <span style={{ color: theme.gold, fontSize: 11, fontWeight: 700 }}>{actorLabel}</span>
        <span style={{ color: "rgba(255,255,255,0.7)", fontSize: 11 }}>
          {stack != null ? `Stack $${stack}` : ""}
        </span>
      </div>
      <div className="flex items-center gap-1.5" style={{ marginBottom: 6 }}>
        <div
          onClick={() => {
            setErr("");
            setAmount("");
          }}
          className="flex-1 flex items-center justify-center"
          style={{
            height: 30,
            borderRadius: 8,
            background: "rgba(255,255,255,0.06)",
            color: amount ? theme.textLight : "rgba(255,255,255,0.4)",
            fontSize: 16,
            fontWeight: 700,
          }}
        >
          {amount ? `$${amount}` : toCall > 0 ? `to call $${toCall}` : "tap a number to bet"}
        </div>
        {amount && (
          <button
            onClick={() => {
              setErr("");
              setAmount((a) => a.slice(0, -1));
            }}
            className="rounded-lg flex items-center justify-center active:scale-95"
            style={{ width: 42, height: 30, background: "rgba(255,255,255,0.12)", color: theme.textLight, fontSize: 15 }}
          >
            ⌫
          </button>
        )}
      </div>
      <div className="grid gap-1.5" style={{ gridTemplateColumns: "repeat(3, 1fr)" }}>
        {[7, 8, 9, 4, 5, 6, 1, 2, 3].map((d) => (
          <Btn key={d} onClick={() => press(d)}>
            {d}
          </Btn>
        ))}
        <Btn onClick={() => onAct("fold")} bg="#1a1a1a" color="#fff" fontSize={24}>
          ✕
        </Btn>
        <Btn onClick={() => press(0)}>0</Btn>
        <Btn onClick={confirm} bg="#1f8a4c" color="#fff" fontSize={20}>
          ✓
        </Btn>
      </div>
      <div className="flex items-center justify-between" style={{ marginTop: 6, gap: 8 }}>
        <span style={{ color: err ? "#ff9a9a" : "rgba(255,255,255,0.75)", fontSize: 11 }}>
          {err || checkLabel}
        </span>
        {potMaxTo != null && (
          <button
            onClick={() => onAct(currentBet > 0 ? "raise" : "bet", potMaxTo)}
            className="rounded-lg flex items-center justify-center active:scale-95 font-extrabold"
            style={{
              height: 30,
              padding: "0 10px",
              background: "rgba(201,162,39,0.9)",
              color: theme.ink,
              fontSize: 12,
              boxShadow: "0 2px 0 rgba(0,0,0,0.35)",
            }}
          >
            POT ${potMaxTo}
          </button>
        )}
        <button
          onClick={() => onAllIn(n > 0 ? n : null)}
          className="rounded-lg flex items-center justify-center gap-1 active:scale-95 font-extrabold"
          style={{
            height: 30,
            padding: "0 12px",
            background: "#8a1f1f",
            color: "#fff",
            fontSize: 13,
            boxShadow: "0 2px 0 rgba(0,0,0,0.35)",
          }}
        >
          <span style={{ fontSize: 16 }}>!</span> ALL-IN
        </button>
      </div>
    </div>
  );
}
