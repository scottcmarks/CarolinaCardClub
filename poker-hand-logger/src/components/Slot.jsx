import { suitMeta } from "../lib/cards.js";
import { theme } from "../constants.js";

export default function Slot({ card, isActive, onSelect, w = 38, h = 54, hole = false }) {
  return (
    <button
      onClick={onSelect}
      className="relative flex items-center justify-center rounded-lg shrink-0"
      style={{
        width: w,
        height: h,
        transition: "all 120ms",
        background: card ? theme.card : "rgba(255,255,255,0.04)",
        border: isActive
          ? `2px solid ${theme.gold}`
          : card
          ? "1px solid rgba(0,0,0,0.15)"
          : hole
          ? "1px dashed rgba(201,162,39,0.4)"
          : "1px dashed rgba(255,255,255,0.18)",
        boxShadow: card ? "0 2px 6px rgba(0,0,0,0.3)" : "none",
      }}
    >
      {card ? (
        <span className="leading-none font-semibold" style={{ color: suitMeta(card.suit).color }}>
          <span style={{ fontSize: 14 }}>{card.rank}</span>
          <span style={{ fontSize: 16 }}>{suitMeta(card.suit).s}</span>
        </span>
      ) : (
        <span style={{ color: hole ? "rgba(201,162,39,0.5)" : "rgba(255,255,255,0.25)", fontSize: 16 }}>+</span>
      )}
    </button>
  );
}
