import { X } from "lucide-react";
import { SEAT_COUNT, TABLE_EXPONENT, tableTheme, theme } from "../constants.js";
import { sameTarget, holeStartOf } from "../lib/cards.js";
import Slot from "./Slot.jsx";

// Seats ride a superellipse ring inside the felt. Positions are % of the inner
// aspect-ratio box (which is itself wide). RX/RY are the ring's half-extents.
const RX = 45;
const RY = 41;

// A superellipse maps a circle direction (cos t, sin t) onto |x|^n+|y|^n=1 by
// keeping the sign and raising the magnitude to 2/n. n=2 => plain ellipse.
const sgn = (v) => (v < 0 ? -1 : v > 0 ? 1 : 0);
function superPt(u, v, expo) {
  const p = 2 / expo;
  return { sx: sgn(u) * Math.abs(u) ** p, sy: sgn(v) * Math.abs(v) ** p };
}

// Seat angle. Dealer mode: 10 evenly-spaced slots with slot 0 left empty at the
// top for the DEALER notch (seat 1 to its left, seat 5 opposite, seat 9 to its
// right). Self-dealt: 9 seats, no gap — seat 2 at the right "end" of the oval,
// seats 6 and 7 flanking the far ("west") end.
function seatAngle(n, dealt) {
  if (dealt === "self") return ((n - 2) / SEAT_COUNT) * 2 * Math.PI;
  return (n * 2 * Math.PI) / (SEAT_COUNT + 1) - Math.PI / 2;
}
function ringPos(n, rx, ry, dealt, expo) {
  const a = seatAngle(n, dealt);
  const { sx, sy } = superPt(Math.cos(a), Math.sin(a), expo);
  return { left: `${50 + rx * sx}%`, top: `${50 + ry * sy}%` };
}

// Superellipse outline as a clip-path polygon, in % of the element's own box.
function superClip(expo, steps = 72) {
  const pts = [];
  for (let i = 0; i < steps; i++) {
    const a = (i / steps) * 2 * Math.PI;
    const { sx, sy } = superPt(Math.cos(a), Math.sin(a), expo);
    pts.push(`${(50 + 50 * sx).toFixed(2)}% ${(50 + 50 * sy).toFixed(2)}%`);
  }
  return `polygon(${pts.join(", ")})`;
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

function SeatFrame({ n, pos, active, folded, warnStack, children }) {
  const { left, top } = pos;
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
          position: "relative",
          padding: 3,
          borderRadius: 12,
          boxShadow: active ? `0 0 0 2px ${theme.gold}, 0 0 14px rgba(201,162,39,0.7)` : "none",
        }}
      >
        {children}
        {warnStack && (
          <span
            title="Stack not set — tap the name to set it"
            style={{
              position: "absolute",
              top: -6,
              right: -6,
              width: 16,
              height: 16,
              borderRadius: "50%",
              background: "#f0b429",
              color: "#23201A",
              fontSize: 11,
              fontWeight: 900,
              lineHeight: "16px",
              textAlign: "center",
              boxShadow: "0 1px 4px rgba(0,0,0,0.5)",
            }}
            className="animate-pulse"
          >
            ?
          </span>
        )}
      </div>
    </div>
  );
}

function Tag({ name, sub, stack, committed, allIn, onClick }) {
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
      {stack == null ? (
        <b style={{ fontSize: 8, letterSpacing: "0.06em", color: "#f0b429" }}>SET STACK</b>
      ) : (
        <span style={{ fontSize: 8, color: "rgba(255,255,255,0.4)" }}>${stack}</span>
      )}
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
  dealt,
  tableShape,
  geo,
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
  const selfDealt = dealt === "self";
  const boards = geo?.boards || 1;
  const holeN = geo?.hole || 2;
  const holeStart = holeStartOf(geo);
  const expo = TABLE_EXPONENT[tableShape] ?? TABLE_EXPONENT.oval;
  const clip = superClip(expo);
  const seatPos = (n) => ringPos(n, RX, RY, dealt, expo);
  const buttonChipPos = (n) => ringPos(n, RX - 13, RY - 11, dealt, expo);
  // menu is disabled while awarding a pot so a seat change can't wipe the hand
  const openMenu = (n) => {
    if (!settling) onOpenMenu(n);
  };
  const revealBySeat = new Map();
  reveals.forEach((r, i) => r.seat && revealBySeat.set(String(r.seat), i));

  // card sizes shrink for double boards / 4-card hands so everything fits
  const commW = boards > 1 ? 26 : 34;
  const commH = boards > 1 ? 37 : 48;
  const holeW = holeN > 2 ? 24 : 32;
  const holeH = holeN > 2 ? 35 : 46;
  const rvW = holeN > 2 ? 19 : 28;
  const rvH = holeN > 2 ? 28 : 40;

  const communitySlot = (b) => (i0) => {
    const i = 5 * b + i0;
    const target = { type: "board", index: i };
    return (
      <Slot
        key={i}
        card={cards[i]}
        isActive={mode === "cards" && sameTarget(active, target)}
        onSelect={() => onSelectCommunity(target)}
        w={commW}
        h={commH}
      />
    );
  };

  return (
    <div
      className="relative my-3 flex items-center justify-center"
      style={{ flex: 1, minHeight: 250 }}
    >
      <div style={{ position: "relative", width: "100%", aspectRatio: "1.35" }}>
      {/* rail (superellipse) */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: tableTheme.rail,
          clipPath: clip,
        }}
      />
      {/* felt (superellipse), sits inside the rail leaving an 8px ring */}
      <div
        style={{
          position: "absolute",
          inset: 8,
          background: tableTheme.feltOval,
          clipPath: clip,
          boxShadow: "inset 0 4px 24px rgba(0,0,0,0.55)",
        }}
      />

      {/* dealer notch — only in dealer mode (self-dealt has no house dealer) */}
      {!selfDealt && (
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
      )}

      {/* community + pot (one row per board) */}
      <div
        className="flex flex-col items-center"
        style={{ position: "absolute", left: "50%", top: "50%", transform: "translate(-50%, -50%)", gap: boards > 1 ? 4 : 0 }}
      >
        {Array.from({ length: boards }, (_, b) => {
          const slot = communitySlot(b);
          return (
            <div key={b} className="flex items-center">
              <div className="flex gap-1">{[0, 1, 2].map(slot)}</div>
              <div style={{ width: boards > 1 ? 8 : 12 }} />
              {slot(3)}
              <div style={{ width: boards > 1 ? 8 : 12 }} />
              {slot(4)}
            </div>
          );
        })}
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
            <SeatFrame key={n} n={n} pos={seatPos(n)} active={isActor} folded={folded} warnStack={seat.stack == null}>
              <div className="flex gap-1">
                {Array.from({ length: holeN }, (_, k) => holeStart + k).map((i) => {
                  if (!cards[i]) {
                    const target = { type: "board", index: i };
                    return (
                      <Slot
                        key={i}
                        card={null}
                        isActive={mode === "cards" && sameTarget(active, target)}
                        onSelect={() => onTapHeroCard(i)}
                        w={holeW}
                        h={holeH}
                        hole
                      />
                    );
                  }
                  return faceUp ? (
                    <Slot key={i} card={cards[i]} isActive={false} onSelect={() => onTapHeroCard(i)} w={holeW} h={holeH} hole />
                  ) : (
                    <CardBack key={i} w={holeW} h={holeH} onClick={() => onTapHeroCard(i)} />
                  );
                })}
              </div>
              <Tag name={heroName || "You"} sub={`S${n} · ${pos}`} stack={seat.stack ?? null} committed={committed} allIn={isAllIn} onClick={() => openMenu(n)} />
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
          <SeatFrame key={n} n={n} pos={seatPos(n)} active={isActor} folded={folded} warnStack={seat.stack == null}>
            {hasReveal ? (
              <div className="flex gap-0.5">
                {reveals[ri].cards.map((c, ci) => (
                  <Slot
                    key={ci}
                    card={c}
                    isActive={revealActive(ci)}
                    onSelect={() => onSelectSeat(n)}
                    w={rvW}
                    h={rvH}
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
            <Tag name={seat.name} sub={`S${n} · ${pos}`} stack={seat.stack ?? null} committed={committed} allIn={isAllIn} onClick={() => openMenu(n)} />
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
