// Rake profiles + the rake calculation. Profiles are a small, USER-EDITABLE
// table in localStorage keyed by id, so any venue's structure can be corrected
// in-app.

const RAKES_KEY = "phl:rakes:v1";

// Seed: Danville $1/$3 = Caesars Virginia (WSOP Poker Room), Danville VA.
// Web-sourced (PokerAtlas + poker.org reviews, 2025): "10% up to $7, and for
// promotions 10% up to $2" — two independently-capped components, max $9/pot.
//   $20 pot -> $2 + $2 = $4 ;  $70+ pot -> $7 + $2 = $9.
// dropOnFlopOnly and the short-handed (<=5) reduced cap are UNCONFIRMED online
// and reflect the user's recollection — both easily edited in setup.
export const SEED_RAKES = [
  {
    id: "danville-1-3",
    venue: "Danville",
    label: "Danville 1-3 (Caesars VA)",
    sb: 1,
    bb: 3,
    rakePercent: 0.1, // house rake %
    rakeCap: 7, // house rake max
    promoPercent: 0.1, // jackpot/promo drop %
    promoCap: 2, // jackpot/promo drop max
    shortHandedThreshold: 5, // <= this many dealt in => reduced rake cap
    shortHandedRakeCap: 5, // house-rake cap when short-handed (promo unchanged)
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
//   playersDealt occupied seats dealt into the hand (for the short-handed cap)
//   sawFlop      did the hand reach a flop (drives no-flop-no-drop)
//   profile      a rake profile object
// Returns { rake, promo, total } in whole dollars.
export function computeRake({ pot, playersDealt, sawFlop, profile }) {
  const p = profile || SEED_RAKES[0];
  if (!pot || pot <= 0) return { rake: 0, promo: 0, total: 0 };
  if (!sawFlop && p.dropOnFlopOnly) return { rake: 0, promo: 0, total: 0 };

  const rakeCap =
    playersDealt <= (p.shortHandedThreshold ?? 0)
      ? p.shortHandedRakeCap ?? p.rakeCap
      : p.rakeCap;

  const rake = Math.min(Math.floor(pot * (p.rakePercent || 0)), rakeCap);
  const promo = Math.min(Math.floor(pot * (p.promoPercent || 0)), p.promoCap || 0);
  return { rake, promo, total: rake + promo };
}

// Human summary, e.g. "10% to $7 + 10% to $2 (≤5: rake to $5) · no flop no drop".
export function rakeSummary(p) {
  if (!p) return "";
  const pct = (x) => `${Math.round((x || 0) * 100)}%`;
  let s = `${pct(p.rakePercent)} to $${p.rakeCap}`;
  if (p.promoCap) s += ` + ${pct(p.promoPercent)} to $${p.promoCap}`;
  if (p.shortHandedRakeCap != null)
    s += ` (≤${p.shortHandedThreshold}: rake to $${p.shortHandedRakeCap})`;
  if (p.dropOnFlopOnly) s += " · no flop no drop";
  return s;
}
