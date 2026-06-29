import { useEffect, useRef, useState } from "react";
import { RANK_ROWS, SUITS, theme } from "../constants.js";

const POPOVER_W = 296; // 4 * 64 + 3 * 10 + 2*5 padding
const POPOVER_H = 80;

export default function Keypad({ pendingRank, usedIds, onRank, onSuit }) {
  const [anchor, setAnchor] = useState(null); // { left, top, flipped }
  const anchorRef = useRef(null);

  // Hide popover whenever pendingRank clears.
  useEffect(() => {
    if (!pendingRank) setAnchor(null);
  }, [pendingRank]);

  const handleRank = (r, e) => {
    if (r !== pendingRank) {
      const rect = e.currentTarget.getBoundingClientRect();
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      // Center the popover ON the tapped rank button (overlays the keypad)
      // so the finger doesn't have to move and the popover doesn't push
      // anything around.
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      let left = cx - POPOVER_W / 2;
      let top = cy - POPOVER_H / 2;
      left = Math.max(6, Math.min(left, vw - POPOVER_W - 6));
      top = Math.max(6, Math.min(top, vh - POPOVER_H - 6));
      setAnchor({ left, top });
      anchorRef.current = rect;
    }
    onRank(r);
  };

  const dismiss = () => {
    if (pendingRank) onRank(pendingRank); // toggles off
  };

  return (
    <>
      <div className="grid gap-2.5 mb-2" style={{ gridTemplateColumns: "repeat(5, 1fr)" }}>
        {RANK_ROWS.map((row, rowIdx) =>
          row.map((r, colIdx) => {
            // Center the short bottom row (4 3 2) into columns 2..4.
            const col = rowIdx === 2 ? colIdx + 2 : colIdx + 1;
            return (
              <button
                key={r}
                onClick={(e) => handleRank(r, e)}
                className="rounded-xl flex items-center justify-center font-extrabold active:scale-95"
                style={{
                  gridRow: rowIdx + 1,
                  gridColumn: col,
                  height: 58,
                  fontSize: 27,
                  color: theme.ink,
                  background: r === pendingRank ? theme.gold : theme.card,
                  boxShadow: "0 2px 0 rgba(0,0,0,0.35)",
                  transition: "transform 80ms",
                }}
              >
                {r}
              </button>
            );
          })
        )}
      </div>

      {pendingRank && anchor && (
        <>
          {/* Dismiss backdrop */}
          <div
            onClick={dismiss}
            style={{ position: "fixed", inset: 0, zIndex: 40, background: "transparent" }}
          />
          {/* Suit popover */}
          <div
            style={{
              position: "fixed",
              left: anchor.left,
              top: anchor.top,
              width: POPOVER_W,
              height: POPOVER_H,
              padding: 8,
              zIndex: 50,
              background: "rgba(20,52,43,0.96)",
              border: "1px solid rgba(201,162,39,0.5)",
              borderRadius: 14,
              boxShadow: "0 8px 24px rgba(0,0,0,0.5)",
              display: "grid",
              gridTemplateColumns: "repeat(4, 1fr)",
              gap: 10,
            }}
          >
            {SUITS.map((su) => {
              const dup = usedIds.has(pendingRank + su.key);
              return (
                <button
                  key={su.key}
                  onClick={() => onSuit(su.key)}
                  disabled={dup}
                  className="rounded-xl flex items-center justify-center active:scale-95"
                  style={{
                    height: 64,
                    fontSize: 38,
                    color: su.color,
                    background: dup ? "rgba(246,243,234,0.25)" : theme.card,
                    boxShadow: dup ? "none" : "0 2px 0 rgba(0,0,0,0.35)",
                    transition: "transform 80ms",
                  }}
                >
                  {su.s}
                </button>
              );
            })}
          </div>
        </>
      )}
    </>
  );
}
