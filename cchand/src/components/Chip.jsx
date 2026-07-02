import { suitMeta } from "../lib/cards.js";
import { theme } from "../constants.js";

// Small light card chip; keeps black spades legible on the dark felt.
export default function Chip({ c }) {
  if (!c) return <span style={{ color: "rgba(255,255,255,0.3)", fontSize: 11.5, marginRight: 3 }}>··</span>;
  return (
    <span
      style={{
        background: theme.card,
        color: suitMeta(c.suit).color,
        borderRadius: 4,
        padding: "1px 4px",
        fontSize: 11.5,
        fontWeight: 700,
        marginRight: 3,
        display: "inline-block",
      }}
    >
      {c.rank}
      {suitMeta(c.suit).s}
    </span>
  );
}
