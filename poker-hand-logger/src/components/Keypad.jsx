import { RANKS, SUITS, theme } from "../constants.js";

export default function Keypad({ pendingRank, usedIds, onRank, onSuit }) {
  return (
    <>
      {/* Rank grid — high → low */}
      <div
        className="grid gap-2 mb-2"
        style={{
          gridTemplateColumns: "repeat(5, 1fr)",
          opacity: pendingRank ? 0.4 : 1,
          transition: "opacity 120ms",
        }}
      >
        {RANKS.map((r) => (
          <button
            key={r}
            onClick={() => onRank(r)}
            className="rounded-xl flex items-center justify-center font-bold active:scale-95"
            style={{
              height: 50,
              fontSize: 21,
              color: theme.ink,
              background: r === pendingRank ? theme.gold : theme.card,
              boxShadow: "0 2px 0 rgba(0,0,0,0.35)",
              transition: "transform 80ms",
            }}
          >
            {r}
          </button>
        ))}
      </div>

      {/* Suit dock — slides up only when a rank is pending */}
      <div
        className="overflow-hidden"
        style={{ maxHeight: pendingRank ? 86 : 0, opacity: pendingRank ? 1 : 0, transition: "all 200ms" }}
      >
        <div className="grid gap-2 pt-1" style={{ gridTemplateColumns: "repeat(4, 1fr)" }}>
          {SUITS.map((su) => {
            const dup = pendingRank && usedIds.has(pendingRank + su.key);
            return (
              <button
                key={su.key}
                onClick={() => onSuit(su.key)}
                disabled={dup}
                className="rounded-xl flex items-center justify-center active:scale-95"
                style={{
                  height: 62,
                  fontSize: 33,
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
      </div>
    </>
  );
}
