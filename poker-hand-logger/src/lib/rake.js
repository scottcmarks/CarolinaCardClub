// Rake profiles + the rake calculation. Profiles are a small, USER-EDITABLE
// table in localStorage keyed by id, so an unconfirmed seed default is fine —
// the user can correct any venue's structure in-app.

const RAKES_KEY = "phl:rakes:v1";

// Seed: Danville $1/$3. Numbers are the user's stated values pending a web
// research check; capIncludesDrop=true models "($2 drop + 10%) up to $7 total".
export const SEED_RAKES = [
  {
    id: "danville-1-3",
    venue: "Danville",
    label: "Danville 1-3",
    sb: 1,
    bb: 3,
    drop: 2, // flat drop per raked pot
    rakePercent: 0.1, // 10%
    rakeCap: 7, // normal max
    capIncludesDrop: true, // cap is the TOTAL (drop + pct), not the pct alone
    shortHandedThreshold: 5, // <= this many dealt in => reduced cap
    shortHandedCap: 5, // reduced max (pending confirmation)
    dropOnFlopOnly: true, // "no flop, no drop"
  },
];

const safeParse = (raw, fallback) => {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
};

export function loadRakes() {
  if (typeof localStorage === "undefined") return [...SEED_RAKES];
  const data = safeParse(localStorage.getItem(RAKES_KEY), null);
  if (!Array.isArray(data) || data.length === 0) return [...SEED_RAKES];
  return data;
}

export function saveRakes(rakes) {
  if (typeof localStorage === "undefined") return;
  try {
    localStorage.setItem(RAKES_KEY, JSON.stringify(rakes));
  } catch {
    /* ignore */
  }
}

export const findRake = (rakes, id) =>
  rakes.find((r) => r.id === id) || rakes[0] || SEED_RAKES[0];

// Compute the rake taken from a finished pot.
//   pot          total chips in the pot
//   playersDealt occupied seats dealt into the hand (for short-handed cap)
//   sawFlop      did the hand reach a flop (drives no-flop-no-drop)
//   profile      a rake profile object
// Returns { drop, pct, cap, total } in whole dollars.
export function computeRake({ pot, playersDealt, sawFlop, profile }) {
  const p = profile || SEED_RAKES[0];
  if (!pot || pot <= 0) return { drop: 0, pct: 0, cap: 0, total: 0 };
  if (!sawFlop && p.dropOnFlopOnly) return { drop: 0, pct: 0, cap: 0, total: 0 };

  const cap =
    playersDealt <= (p.shortHandedThreshold ?? 0)
      ? p.shortHandedCap ?? p.rakeCap
      : p.rakeCap;

  const pct = Math.floor(pot * (p.rakePercent || 0));
  const drop = p.drop || 0;
  const total = p.capIncludesDrop
    ? Math.min(drop + pct, cap)
    : drop + Math.min(pct, cap);

  return { drop, pct, cap, total };
}

// Human summary of a profile, e.g. "$2 + 10% to $7 (≤5: $5) · no flop no drop".
export function rakeSummary(p) {
  if (!p) return "";
  const main = `$${p.drop} + ${Math.round((p.rakePercent || 0) * 100)}% to $${p.rakeCap}`;
  const sh =
    p.shortHandedCap != null
      ? ` (≤${p.shortHandedThreshold}: $${p.shortHandedCap})`
      : "";
  const flop = p.dropOnFlopOnly ? " · no flop no drop" : "";
  return main + sh + flop;
}
