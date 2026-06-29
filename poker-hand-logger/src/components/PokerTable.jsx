import { X } from "lucide-react";
import { HOLE_START, POSITIONS_9, SEAT_COUNT, tableTheme, theme } from "../constants.js";
import { sameTarget } from "../lib/cards.js";
import Slot from "./Slot.jsx";

// Seat geometry: dealer notch at top (12 o'clock). Seats go COUNTER-clockwise
// from the viewer (so the dealer's left = upper-right on screen):
//   seat 1 upper-right, seat 2 right, ..., seat 5 bottom (across from dealer),
//   ..., seat 9 upper-left.
// Place 9 seats on the ellipse at angles ψ_n = n * (2π/10) measured CCW from
// the top; ψ=0 stays empty (dealer).
// Flatten the table — wider than tall.
const RX = 46;
const RY = 34;
function seatPos(n) {
  const psi = (n * 2 * Math.PI) / (SEAT_COUNT + 1);
  // CCW from top, viewer perspective: positive ψ goes to the right.
  const left = 50 + RX * Math.sin(psi);
  const top = 50 - RY * Math.cos(psi);
  return { left: `${left}%`, top: `${top}%` };
}

// Place the dealer-button chip slightly inboard of the named seat so it
// reads as "this seat has the button" without overlapping the cards.
function buttonChipPos(n) {
  const psi = (n * 2 * Math.PI) / (SEAT_COUNT + 1);
  const left = 50 + (RX - 14) * Math.sin(psi);
  const top = 50 - (RY - 12) * Math.cos(psi);
  return { left: `${left}%`, top: `${top}%` };
}

// Resolve position label for a seat given where the button sits.
function positionLabel(seat, button) {
  const offset = (seat - button + SEAT_COUNT) % SEAT_COUNT;
  return POSITIONS_9[offset];
}

function CommunityRow({ cards, active, onSelect }) {
  const slot = (i) => {
    const target = { type: "board", index: i };
    return (
      <Slot
        key={i}
        card={cards[i]}
        isActive={sameTarget(active, target)}
        onSelect={() => onSelect(target)}
        w={34}
        h={48}
      />
    );
  };
  return (
    <div
      className="flex items-center"
      style={{
        position: "absolute",
        left: "50%",
        top: "50%",
        transform: "translate(-50%, -50%)",
      }}
    >
      <div className="flex gap-1">{[0, 1, 2].map(slot)}</div>
      <div style={{ width: 14 }} />
      {slot(3)}
      <div style={{ width: 14 }} />
      {slot(4)}
    </div>
  );
}

function HeroSeat({ n, cards, active, onSelect, position }) {
  const { left, top } = seatPos(n);
  return (
    <div
      style={{
        position: "absolute",
        left,
        top,
        transform: "translate(-50%, -50%)",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 2,
      }}
    >
      <div className="flex gap-1">
        {[HOLE_START, HOLE_START + 1].map((i) => {
          const target = { type: "board", index: i };
          return (
            <Slot
              key={i}
              card={cards[i]}
              isActive={sameTarget(active, target)}
              onSelect={() => onSelect(target)}
              w={32}
              h={46}
              hole
            />
          );
        })}
      </div>
      <span
        className="uppercase"
        style={{
          fontSize: 9,
          letterSpacing: "0.1em",
          color: "rgba(201,162,39,0.85)",
          fontWeight: 700,
        }}
      >
        You · S{n} · {position}
      </span>
    </div>
  );
}

function VillainSeat({ n, revealIdx, reveal, active, onSelect, onRemove, position }) {
  const { left, top } = seatPos(n);
  return (
    <div
      style={{
        position: "absolute",
        left,
        top,
        transform: "translate(-50%, -50%)",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 2,
      }}
    >
      <div className="flex gap-1">
        {[0, 1].map((c) => {
          const target = { type: "reveal", r: revealIdx, c };
          return (
            <Slot
              key={c}
              card={reveal.cards[c]}
              isActive={sameTarget(active, target)}
              onSelect={() => onSelect(target)}
              w={30}
              h={42}
            />
          );
        })}
      </div>
      <div className="flex items-center gap-1">
        <span style={{ fontSize: 9, color: "rgba(255,255,255,0.6)" }}>S{n} · {position}</span>
        <button onClick={() => onRemove(revealIdx)} style={{ color: "rgba(255,255,255,0.5)" }}>
          <X size={11} />
        </button>
      </div>
    </div>
  );
}

function EmptySeat({ n, onSelectSeat, position }) {
  const { left, top } = seatPos(n);
  return (
    <div
      style={{
        position: "absolute",
        left,
        top,
        transform: "translate(-50%, -50%)",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 2,
      }}
    >
      <button
        onClick={() => onSelectSeat(n)}
        style={{
          width: 40,
          height: 40,
          borderRadius: "50%",
          background: "rgba(0,0,0,0.35)",
          border: "1px dashed rgba(255,255,255,0.3)",
          color: "rgba(255,255,255,0.65)",
          fontSize: 13,
          fontWeight: 700,
        }}
        className="active:scale-95"
      >
        {n}
      </button>
      <span
        style={{
          fontSize: 8,
          letterSpacing: "0.1em",
          color: "rgba(255,255,255,0.45)",
          fontWeight: 600,
        }}
      >
        {position}
      </span>
    </div>
  );
}

function DealerButton({ seat, onTap }) {
  const { left, top } = buttonChipPos(seat);
  return (
    <button
      onClick={onTap}
      title="Tap to advance the button one seat"
      style={{
        position: "absolute",
        left,
        top,
        transform: "translate(-50%, -50%)",
        width: 26,
        height: 26,
        borderRadius: "50%",
        background: "#F6F3EA",
        color: "#23201A",
        fontSize: 11,
        fontWeight: 900,
        border: "2px solid #C9A227",
        boxShadow: "0 2px 6px rgba(0,0,0,0.5)",
        zIndex: 5,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        letterSpacing: 0,
      }}
      className="active:scale-95"
    >
      D
    </button>
  );
}

function DealerNotch() {
  return (
    <div
      style={{
        position: "absolute",
        left: "50%",
        top: 0,
        transform: "translate(-50%, -50%)",
        width: 56,
        height: 20,
        borderRadius: 10,
        background: tableTheme.rail,
        border: "1px solid rgba(255,255,255,0.15)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: 9,
        letterSpacing: "0.15em",
        color: "rgba(255,255,255,0.55)",
      }}
    >
      DEALER
    </div>
  );
}

export default function PokerTable({
  cards,
  reveals,
  active,
  heroSeat,
  buttonSeat,
  onSelect,
  onSelectSeat,
  onRemoveReveal,
  onAdvanceButton,
}) {
  // Map seat number → reveal index (only for non-hero seats).
  const revealBySeat = new Map();
  reveals.forEach((r, i) => {
    if (r.seat) revealBySeat.set(String(r.seat), i);
  });

  return (
    <div
      className="relative my-3"
      style={{ flex: 1, minHeight: 320 }}
    >
      {/* Felt oval */}
      <div
        style={{
          position: "absolute",
          inset: 6,
          borderRadius: "50%",
          background: tableTheme.feltOval,
          border: `8px solid ${tableTheme.rail}`,
          boxShadow: "inset 0 4px 24px rgba(0,0,0,0.55)",
        }}
      />

      <DealerNotch />

      <CommunityRow cards={cards} active={active} onSelect={onSelect} />

      {Array.from({ length: SEAT_COUNT }, (_, k) => k + 1).map((n) => {
        const pos = positionLabel(n, buttonSeat);
        if (n === heroSeat) {
          return (
            <HeroSeat
              key={n}
              n={n}
              cards={cards}
              active={active}
              onSelect={onSelect}
              position={pos}
            />
          );
        }
        const ri = revealBySeat.get(String(n));
        if (ri !== undefined) {
          return (
            <VillainSeat
              key={n}
              n={n}
              revealIdx={ri}
              reveal={reveals[ri]}
              active={active}
              onSelect={onSelect}
              onRemove={onRemoveReveal}
              position={pos}
            />
          );
        }
        return <EmptySeat key={n} n={n} onSelectSeat={onSelectSeat} position={pos} />;
      })}

      <DealerButton seat={buttonSeat} onTap={onAdvanceButton} />
    </div>
  );
}
