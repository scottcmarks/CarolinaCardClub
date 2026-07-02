// Seat ordering, blinds, and poker position labels — all occupancy-aware.
// Seats are 1..N; clockwise = increasing seat number (wraps). The button is a
// seat number (may sit on an empty seat — a "dead button").

// Position names walking forward from the BB (UTG first). Sliced to fit.
const FORWARD = ["UTG", "UTG+1", "UTG+2", "MP", "LJ", "HJ", "CO"];

export const occupiedSeats = (seats) =>
  seats.map((s, i) => (s && s.occupied ? i + 1 : null)).filter((n) => n !== null);

// Next occupied seat strictly after `from` (clockwise/wrapping). null if none.
export function nextOccupied(seats, from) {
  const n = seats.length;
  for (let k = 1; k <= n; k++) {
    const seat = ((from - 1 + k) % n) + 1;
    if (seats[seat - 1] && seats[seat - 1].occupied) return seat;
  }
  return null;
}

// { sb, bb, headsUp } or null if fewer than 2 players are seated.
export function blinds(seats, button) {
  const occ = occupiedSeats(seats);
  if (occ.length < 2) return null;
  if (occ.length === 2) {
    // Heads-up: the button posts the small blind.
    const sb = seats[button - 1] && seats[button - 1].occupied ? button : occ[0];
    const bb = occ.find((s) => s !== sb);
    return { sb, bb, headsUp: true };
  }
  const sb = nextOccupied(seats, button);
  const bb = nextOccupied(seats, sb);
  return { sb, bb, headsUp: false };
}

// Occupied seats in clockwise order starting from (and including) `start`.
function orderFrom(seats, start) {
  const out = [];
  const n = seats.length;
  for (let k = 0; k < n; k++) {
    const seat = ((start - 1 + k) % n) + 1;
    if (seats[seat - 1] && seats[seat - 1].occupied) out.push(seat);
  }
  return out;
}

// Map of seat number -> position label ("BTN","SB","BB","UTG",...) for the
// occupied seats, given where the button sits.
export function positionLabels(seats, button) {
  const b = blinds(seats, button);
  const map = {};
  if (!b) {
    occupiedSeats(seats).forEach((s) => (map[s] = ""));
    return map;
  }
  if (b.headsUp) {
    map[b.sb] = "SB/BTN";
    map[b.bb] = "BB";
    return map;
  }
  // Order from SB: [SB, BB, UTG, ..., BTN]. The last entry is the button.
  const order = orderFrom(seats, b.sb);
  order.forEach((seat, i) => {
    if (i === 0) map[seat] = "SB";
    else if (i === 1) map[seat] = "BB";
    else if (i === order.length - 1) map[seat] = "BTN";
    else map[seat] = FORWARD[i - 2] || "MP";
  });
  return map;
}

// Preflop action order (first to act = UTG ... last = BB), occupancy-aware.
export function preflopOrder(seats, button) {
  const b = blinds(seats, button);
  if (!b) return [];
  if (b.headsUp) return orderFrom(seats, b.sb); // SB(btn) acts first preflop HU
  return orderFrom(seats, nextOccupied(seats, b.bb)); // UTG first, wraps to BB last
}

// Post-flop action order (first to act = first occupied after the button = SB).
export function postflopOrder(seats, button) {
  const b = blinds(seats, button);
  if (!b) return [];
  if (b.headsUp) return orderFrom(seats, b.bb); // BB acts first post-flop HU
  return orderFrom(seats, b.sb);
}
