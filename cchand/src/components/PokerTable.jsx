import { X } from "lucide-react";
import { HOLE_START, SEAT_COUNT, tableTheme, theme } from "../constants.js";
import { sameTarget } from "../lib/cards.js";
import Slot from "./Slot.jsx";

// Wider-than-tall oval; seats CCW from the top (dealer notch). Seat 1
// upper-right, seat 5 across from dealer at the bottom, seat 9 upper-left.
// Positions are % of the inner aspect-ratio box (which is itself wide).
const RX = 45;
const RY = 41;
function seatPos(n) {
  const psi = (n * 2 * Math.PI) / (SEAT_COUNT + 1);
  return { left: `${50 + RX * Math.sin(psi)}%`, top: `${50 - RY * Math.cos(psi)}%` };
}
function buttonChipPos(n) {
  const psi = (n * 2 * Math.PI) / (SEAT_COUNT + 1);
  return { left: `${50 + (RX - 13) * Math.sin(psi)}%`, top: `${50 - (RY - 11) * Math.cos(psi)}%` };
}

function CardBack({ w = 32, h = 46, onClick }) {
  return (
    <button
      onClick={onClick}
      className="rounded-lg shrink-0"
      style={{
        width: w,
        height: h,
        background: "repeating-linear-gradient(45deg, #7a1420 0 6px, #5e0f19 6px 12px)",
        border: "1px solid rgba(255,255,255,0.25)",
        boxShadow: "0 2px 6px rgba(0,0,0,0.4)",
      }}
    />
  );
}

function SeatFrame({ n, active, folded, children }) {
  const { left, top } = seatPos(n);
  return (
    <div
      data-seat={n}
      style={{
        position: "absolute",
        left,
        top,
        transform: "translate(-50%, -50%)",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 2,
        opacity: folded ? 0.4 : 1,
        filter: folded ? "grayscale(0.6)" : "none",
      }}
    >
      <div
        className={active ? "animate-pulse" : ""}
        style={{
          padding: 3,
          borderRadius: 12,
          boxShadow: active ? `0 0 0 2px ${theme.gold}, 0 0 14px rgba(201,162,39,0.7)` : "none",
        }}
      >
        {children}
      </div>
    </div>
  );
}

function Tag({ name, sub, committed, allIn, onClick }) {
  return (
    <button onClick={onClick} className="flex flex-col items-center" style={{ lineHeight: 1.15, marginTop: 1 }}>
      <span
        style={{ fontSize: 9.5, color: "rgba(255,255,255,0.85)", fontWeight: 600, maxWidth: 72 }}
        className="truncate"
      >
        {name}
      </span>
      <span style={{ fontSize: 8, letterSpacing: "0.08em", color: "rgba(255,255,255,0.5)" }}>
        {sub}
        {allIn ? (
          <b style={{ color: "#ff7a7a" }}>{sub ? " · " : ""}ALL-IN</b>
        ) : (
          committed > 0 && <b style={{ color: theme.gold }}>{sub ? " · " : ""}${committed}</b>
        )}
      </span>
    </button>
  );
}

export default function PokerTable({
  cards,
  reveals,
  heroRevealed,
  active,
  mode,
  phase,
  bet,
  seats,
  positions,
  heroSeat,
  heroName,
  buttonSeat,
  settling,
  selectedWinners,
  sittingOut,
  moving,
  onSelectCommunity,
  onTapHeroCard,
  onSeatAct,
  onSelectSeat,
  onRemoveReveal,
  onAdvanceButton,
  onAwardWinner,
  onOpenMenu,
  onMoveHere,
  onSitHere,
}) {
  const showdown = phase === "showdown";
  // menu is disabled while awarding a pot so a seat change can't wipe the hand
  const openMenu = (n) => {
    if (!settling) onOpenMenu(n);
  };
  const revealBySeat = new Map();
  reveals.forEach((r, i) => r.seat && revealBySeat.set(String(r.seat), i));

  const communitySlot = (i) => {
    const target = { type: "board", index: i };
    return (
      <Slot
        key={i}
        card={cards[i]}
        isActive={mode === "cards" && sameTarget(active, target)}
        onSelect={() => onSelectCommunity(target)}
        w={34}
        h={48}
      />
    );
  };

  return (
    <div
      className="relative my-3 flex items-center justify-center"
      style={{ flex: 1, minHeight: 250 }}
    >
      <div style={{ position: "relative", width: "100%", aspectRatio: "1.35" }}>
      <div
        style={{
          position: "absolute",
          inset: 4,
          borderRadius: "50%",
          background: tableTheme.feltOval,
          border: `8px solid ${tableTheme.rail}`,
          boxShadow: "inset 0 4px 24px rgba(0,0,0,0.55)",
        }}
      />

      {/* dealer notch */}
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

      {/* community + pot */}
      <div
        className="flex flex-col items-center"
        style={{ position: "absolute", left: "50%", top: "50%", transform: "translate(-50%, -50%)" }}
      >
        <div className="flex items-center">
          <div className="flex gap-1">{[0, 1, 2].map(communitySlot)}</div>
          <div style={{ width: 12 }} />
          {communitySlot(3)}
          <div style={{ width: 12 }} />
          {communitySlot(4)}
        </div>
        <div
          style={{
            marginTop: 6,
            padding: "2px 12px",
            borderRadius: 12,
            background: "rgba(0,0,0,0.4)",
            color: theme.gold,
            fontSize: 12,
            fontWeight: 800,
            letterSpacing: "0.04em",
          }}
        >
          POT ${bet.pot}
        </div>
      </div>

      {/* seats */}
      {Array.from({ length: SEAT_COUNT }, (_, k) => k + 1).map((n) => {
        const seat = seats[n - 1];
        const occupied = seat && seat.occupied;
        const pos = positions[n] || "";
        const committed = bet.committed[n] || 0;
        const folded = bet.foldedStreet[n] != null;
        const isAllIn = bet.allIn.includes(n);
        const isActor = bet.actor === n && mode === "betting";

        if (n === heroSeat && !sittingOut) {
          const faceUp = heroRevealed || showdown;
          return (
            <SeatFrame key={n} n={n} active={isActor} folded={folded}>
              <div className="flex gap-1">
                {[HOLE_START, HOLE_START + 1].map((i) => {
                  if (!cards[i]) {
                    const target = { type: "board", index: i };
                    return (
                      <Slot
                        key={i}
                        card={null}
                        isActive={mode === "cards" && sameTarget(active, target)}
                        onSelect={() => onTapHeroCard(i)}
                        w={32}
                        h={46}
                        hole
                      />
                    );
                  }
                  return faceUp ? (
                    <Slot key={i} card={cards[i]} isActive={false} onSelect={() => onTapHeroCard(i)} w={32} h={46} hole />
                  ) : (
                    <CardBack key={i} onClick={() => onTapHeroCard(i)} />
                  );
                })}
              </div>
              <Tag name={heroName || "You"} sub={`S${n} · ${pos}`} committed={committed} allIn={isAllIn} onClick={() => openMenu(n)} />
            </SeatFrame>
          );
        }

        if (!occupied) {
          const { left, top } = seatPos(n);
          const highlight = moving || sittingOut;
          const onTap = () =>
            moving ? onMoveHere(n) : sittingOut ? onSitHere(n) : openMenu(n);
          return (
            <button
              key={n}
              data-seat={n}
              onClick={onTap}
              style={{
                position: "absolute",
                left,
                top,
                transform: "translate(-50%, -50%)",
                width: 40,
                height: 40,
                borderRadius: "50%",
                background: highlight ? "rgba(31,138,76,0.35)" : "rgba(0,0,0,0.3)",
                border: highlight ? "1px solid #1f8a4c" : "1px dashed rgba(255,255,255,0.22)",
                color: highlight ? "#c7f0d5" : "rgba(255,255,255,0.4)",
                fontSize: 11,
                fontWeight: highlight ? 700 : 400,
              }}
              className="active:scale-95"
            >
              {highlight ? "sit" : `+${n}`}
            </button>
          );
        }

        // occupied villain seat
        const ri = revealBySeat.get(String(n));
        const hasReveal = ri !== undefined;
        const clickable = showdown ? () => onSelectSeat(n) : () => onSeatAct(n);
        const revealActive = (c) =>
          mode === "cards" && active.type === "reveal" && active.r === ri && active.c === c;

        return (
          <SeatFrame key={n} n={n} active={isActor} folded={folded}>
            {hasReveal ? (
              <div className="flex gap-1">
                {[0, 1].map((c) => (
                  <Slot
                    key={c}
                    card={reveals[ri].cards[c]}
                    isActive={revealActive(c)}
                    onSelect={() => onSelectSeat(n)}
                    w={28}
                    h={40}
                  />
                ))}
              </div>
            ) : (
              <button
                onClick={clickable}
                style={{
                  width: 64,
                  height: 40,
                  borderRadius: 10,
                  background: folded ? "rgba(0,0,0,0.25)" : "rgba(255,255,255,0.07)",
                  border: isActor ? `1px solid ${theme.gold}` : "1px solid rgba(255,255,255,0.12)",
                  color: "rgba(255,255,255,0.6)",
                  fontSize: 10,
                }}
                className="active:scale-95"
              >
                {folded ? "folded" : showdown ? "show?" : "—"}
              </button>
            )}
            <Tag name={seat.name} sub={`S${n} · ${pos}`} committed={committed} allIn={isAllIn} onClick={() => openMenu(n)} />
            {hasReveal && showdown && (
              <button
                onClick={() => onRemoveReveal(ri)}
                style={{ color: "rgba(255,255,255,0.45)", marginTop: 1 }}
              >
                <X size={11} />
              </button>
            )}
          </SeatFrame>
        );
      })}

      {/* winner tap (SCAFFOLDING): overlay an award target on each live seat */}
      {settling &&
        bet.inHand.map((n) => {
          const { left, top } = seatPos(n);
          const picked = (selectedWinners || []).includes(n);
          return (
            <button
              key={"win" + n}
              onClick={() => onAwardWinner(n)}
              className="active:scale-95"
              style={{
                position: "absolute",
                left,
                top,
                transform: "translate(-50%, -50%)",
                zIndex: 8,
                padding: "4px 10px",
                borderRadius: 10,
                background: picked ? "rgba(31,138,76,0.96)" : "rgba(0,0,0,0.6)",
                color: "#fff",
                fontSize: 11,
                fontWeight: 800,
                border: picked ? "2px solid #7fe0a6" : "1px solid rgba(255,255,255,0.4)",
                boxShadow: "0 2px 8px rgba(0,0,0,0.5)",
              }}
            >
              {picked ? "WON ✓" : "won?"}
            </button>
          );
        })}

      {/* dealer button */}
      <button
        onClick={onAdvanceButton}
        title="Tap to advance the button one seat"
        style={{
          position: "absolute",
          ...buttonChipPos(buttonSeat),
          transform: "translate(-50%, -50%)",
          width: 24,
          height: 24,
          borderRadius: "50%",
          background: "#F6F3EA",
          color: "#23201A",
          fontSize: 11,
          fontWeight: 900,
          border: "2px solid #C9A227",
          boxShadow: "0 2px 6px rgba(0,0,0,0.5)",
          zIndex: 6,
        }}
        className="active:scale-95"
      >
        D
      </button>
      </div>
    </div>
  );
}
