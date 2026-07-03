import { useState, useLayoutEffect } from "react";
import { theme } from "../constants.js";

const MENU_W = 208;

const field = {
  background: "rgba(255,255,255,0.08)",
  color: theme.textLight,
  fontSize: 13,
  border: "1px solid rgba(255,255,255,0.12)",
};

// Live seat-management popover, anchored to a tapped seat. Handles stack/name
// annotation and seat moves / stand-up (hero) / sit-out (villain).
export default function PlayerMenu({
  seatNum,
  isHero,
  occupied,
  name,
  stack,
  onSetStack,
  onRename,
  onEnterCards,
  onStartMove,
  onStandUp,
  onVacate,
  onSeat,
  onClose,
}) {
  const [pos, setPos] = useState(null);

  useLayoutEffect(() => {
    const el = document.querySelector(`[data-seat="${seatNum}"]`);
    if (!el) return;
    const r = el.getBoundingClientRect();
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    let left = r.left + r.width / 2 - MENU_W / 2;
    left = Math.max(6, Math.min(left, vw - MENU_W - 6));
    let top = r.bottom + 6;
    if (top + 200 > vh - 6) top = Math.max(6, r.top - 200);
    setPos({ left, top });
  }, [seatNum]);

  const Btn = ({ children, onClick, danger }) => (
    <button
      onClick={onClick}
      className="w-full py-2 rounded-lg font-semibold active:scale-95"
      style={{
        fontSize: 13,
        background: danger ? "rgba(138,31,31,0.8)" : "rgba(255,255,255,0.1)",
        color: theme.textLight,
      }}
    >
      {children}
    </button>
  );

  if (!pos) return null;

  return (
    <>
      <div onClick={onClose} style={{ position: "fixed", inset: 0, zIndex: 85 }} />
      <div
        style={{
          position: "fixed",
          left: pos.left,
          top: pos.top,
          width: MENU_W,
          zIndex: 86,
          padding: 10,
          background: "rgba(16,38,31,0.98)",
          border: "1px solid rgba(201,162,39,0.5)",
          borderRadius: 14,
          boxShadow: "0 10px 30px rgba(0,0,0,0.55)",
        }}
        className="flex flex-col gap-2"
      >
        <div style={{ color: theme.gold, fontSize: 12, fontWeight: 700 }}>
          Seat {seatNum} · {occupied ? (isHero ? "You" : name) : "empty"}
        </div>

        {occupied ? (
          <>
            <label className="flex items-center gap-2">
              <span style={{ color: "rgba(255,255,255,0.6)", fontSize: 12, width: 40 }}>Stack</span>
              <input
                value={stack ?? ""}
                inputMode="numeric"
                placeholder="—"
                onChange={(e) => onSetStack(seatNum, e.target.value)}
                className="flex-1 px-2 py-1.5 rounded-lg outline-none text-center"
                style={field}
              />
            </label>
            {!isHero && (
              <label className="flex items-center gap-2">
                <span style={{ color: "rgba(255,255,255,0.6)", fontSize: 12, width: 40 }}>Name</span>
                <input
                  value={name}
                  onChange={(e) => onRename(seatNum, e.target.value)}
                  className="flex-1 px-2 py-1.5 rounded-lg outline-none"
                  style={field}
                />
              </label>
            )}
            <Btn onClick={() => onEnterCards(seatNum)}>Enter shown cards</Btn>
            {isHero ? (
              <>
                <Btn onClick={onStartMove}>Change seat</Btn>
                <Btn onClick={onStandUp} danger>Stand up</Btn>
              </>
            ) : (
              <Btn onClick={() => onVacate(seatNum)} danger>Sit out</Btn>
            )}
          </>
        ) : (
          <Btn onClick={() => onSeat(seatNum)}>Seat a player</Btn>
        )}
      </div>
    </>
  );
}
