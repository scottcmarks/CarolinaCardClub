// Rake / house-charge profiles + their math. Profiles are a small USER-EDITABLE
// table in localStorage, so any venue's structure can be corrected in-app.
//
// A profile has a `type`:
//   'percent' — per-pot rake: a list of independently-capped {percent, cap}
//               components (Danville: 10%→$7 + 10%→$2), optional short-handed
//               cap override, optional no-flop-no-drop.
//   'time'    — per-seat time collection: perHour, minHours, optional prepay
//               flat for the whole session. Charged once per session, NOT per
//               hand (per-hand rake is 0).
//   'none'    — no house cut (e.g. a purely social game).

const RAKES_KEY = "phl:rakes:v1";

export const SEED_RAKES = [
  // Danville $1/$3 = Caesars Virginia (WSOP Poker Room). Web-sourced:
  // "10% up to $7, and for promotions 10% up to $2" — max $9/pot.
  {
    id: "danville-1-3",
    venue: "Danville",
    label: "Danville 1-3 (Caesars VA)",
    type: "percent",
    sb: 1,
    bb: 3,
    components: [
      { percent: 0.1, cap: 7, shortCap: 5 }, // house rake (≤5-handed: $5)
      { percent: 0.1, cap: 2 }, // jackpot/promo drop
    ],
    shortHandedThreshold: 5,
    dropOnFlopOnly: true, // "no flop, no drop" (user's recollection)
    straddleAmounts: [5], // UTG-only, fixed $5 (automatic — single option)
  },
  // Danville 2-2 PLO (Caesars Virginia). 4-card pot-limit Omaha, $2/$2 blinds
  // with a mandatory $5 UTG bring-in. Timed rake $8 per half hour (no pot
  // rake). At each half-hour collection: a double-board PLO bomb pot — $17
  // participation + the $8 collection = $25 into the pot (or pay $8 and sit
  // out); the pot forms BEFORE the rake is removed (9 players ⇒ $225 at the
  // flops, house then takes 9×$8).
  {
    id: "danville-2-2-plo",
    venue: "Danville",
    label: "Danville 2-2 PLO (Caesars VA)",
    type: "time",
    game: "plo",
    sb: 2,
    bb: 2,
    bringIn: 5,
    perHour: 16,
    blockMinutes: 30,
    bombPot: { ante: 17, doubleBoard: true },
  },
  // Five Oaks Club (Durham, NC) — time charge, not a pot rake.
  // $6/hr, 2-hr minimum, or prepay $30 flat for the session. Blinds unknown —
  // placeholder $1/$2; edit in setup.
  {
    id: "five-oaks",
    venue: "Five Oaks",
    label: "Five Oaks (Durham)",
    type: "time",
    sb: 1,
    bb: 2,
    perHour: 6,
    minHours: 2,
    prepay: 30,
    straddleAmounts: [4, 5], // UTG-only, $4 or $5 (user picks). RoE variant ~$10 — TODO
  },
];

// Game variant implied by a profile. PLO = 4 hole cards, pot-limit betting
// ("Big O" 5-card exists elsewhere but not at Danville — add when needed).
export function gameOf(profile) {
  if (profile && profile.game === "plo") return { game: "plo", hole: 4, potLimit: true };
  return { game: "nlhe", hole: 2, potLimit: false };
}

// Per-collection charge for a block-metered time rake ($16/hr in 30-min
// blocks ⇒ $8). Falls back to a whole hour for plain hourly venues.
export const blockCharge = (p) =>
  p && p.type === "time"
    ? Math.round((p.perHour || 0) * ((p.blockMinutes || 60) / 60))
    : 0;

// Straddle: a UTG-only forced blind raise, posted before the deal, that acts
// last preflop. Amount is site/table-dependent (Danville 1-3 fixed $5; Five Oaks
// 1-2 $4 or $5). `straddleAmounts` on a profile: [] / absent = no straddle; one
// entry = automatic; multiple = the user picks. Non-UTG straddles (button /
// Mississippi) and the "Round-of-Each" (RoE mixed-game, ~$10) are future work.

const safeParse = (raw, fallback) => {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
};

// Bring a stored profile up to the current shape (migrate the old
// rakePercent/rakeCap/promo* fields into type:'percent' + components).
function migrate(p) {
  if (!p || typeof p !== "object") return p;
  if (p.type) return p; // already current
  const hasLegacy =
    p.rakePercent != null || p.rakeCap != null || p.promoPercent != null || p.promoCap != null;
  if (hasLegacy) {
    const components = [];
    if (p.rakePercent != null || p.rakeCap != null)
      components.push({ percent: p.rakePercent || 0, cap: p.rakeCap || 0, shortCap: p.shortHandedRakeCap });
    if (p.promoPercent != null || p.promoCap != null)
      components.push({ percent: p.promoPercent || 0, cap: p.promoCap || 0 });
    return {
      ...p,
      type: "percent",
      components,
      shortHandedThreshold: p.shortHandedThreshold,
      dropOnFlopOnly: !!p.dropOnFlopOnly,
    };
  }
  return { ...p, type: "none" };
}

export function loadRakes() {
  if (typeof localStorage === "undefined") return [...SEED_RAKES];
  const data = safeParse(localStorage.getItem(RAKES_KEY), null);
  if (!Array.isArray(data) || data.length === 0) return [...SEED_RAKES];
  const out = data.map(migrate);
  // merge in any NEW seed profiles this build knows about (non-destructive:
  // stored profiles — including edited copies of seeds — always win by id)
  SEED_RAKES.forEach((s) => {
    if (!out.some((r) => r.id === s.id)) out.push({ ...s });
  });
  return out;
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

export const isTimeRake = (p) => p && p.type === "time";

// Per-hand rake taken from a finished pot. Time/none profiles take nothing per
// hand (time is a session charge — see computeTimeCharge). Returns { total }.
export function computeRake({ pot, playersDealt, sawFlop, profile }) {
  const p = profile || SEED_RAKES[0];
  if (p.type !== "percent") return { total: 0, parts: [] };
  if (!pot || pot <= 0) return { total: 0, parts: [] };
  if (!sawFlop && p.dropOnFlopOnly) return { total: 0, parts: [] };

  const short = playersDealt <= (p.shortHandedThreshold ?? 0);
  const parts = (p.components || []).map((c) => {
    const cap = short && c.shortCap != null ? c.shortCap : c.cap;
    return Math.min(Math.floor(pot * (c.percent || 0)), cap ?? Infinity);
  });
  return { total: parts.reduce((a, b) => a + b, 0), parts };
}

// Session-level time charge for a 'time' profile. Metered in blocks of
// `blockMinutes` (default a whole hour): charged = ceil(time / block) × the
// per-block rate, with at least `minHours` charged.
//   elapsedHours  seated hours (fractional)
//   prepaid       did the player take the flat prepay option
// Returns { metered, prepay, charge } in whole dollars.
export function computeTimeCharge({ elapsedHours, prepaid, profile }) {
  const p = profile || {};
  if (p.type !== "time") return { metered: 0, prepay: 0, charge: 0 };
  const blockMin = p.blockMinutes || 60;
  const chargedMin = Math.max((p.minHours || 0) * 60, (elapsedHours || 0) * 60);
  const blocks = Math.ceil(chargedMin / blockMin - 1e-9) || 0;
  const metered = blocks * blockCharge(p);
  const prepay = p.prepay ?? null;
  const charge = prepaid && prepay != null ? prepay : metered;
  return { metered, prepay, charge, hours: (blocks * blockMin) / 60 };
}

// Human summary line for a profile.
export function rakeSummary(p) {
  if (!p) return "";
  let prefix = "";
  if (p.game === "plo") prefix = "PLO · ";
  if (p.bringIn) prefix += `$${p.bringIn} bring-in · `;
  if (p.type === "time") {
    let s =
      p.blockMinutes && p.blockMinutes !== 60
        ? `$${blockCharge(p)}/${p.blockMinutes}min`
        : `$${p.perHour}/hr`;
    if (p.minHours) s += `, ${p.minHours}hr min`;
    if (p.prepay != null) s += `, or $${p.prepay}/session`;
    if (p.bombPot)
      s += ` · bomb pot $${p.bombPot.ante + blockCharge(p)}${p.bombPot.doubleBoard ? " (2 boards)" : ""}`;
    return prefix + s;
  }
  if (p.type === "none") return prefix + "no house rake";
  // percent
  const pct = (x) => `${Math.round((x || 0) * 100)}%`;
  const comps = (p.components || []).map((c) => `${pct(c.percent)} to $${c.cap}`).join(" + ");
  let s = comps || "no rake";
  const sc = (p.components || []).find((c) => c.shortCap != null);
  if (sc) s += ` (≤${p.shortHandedThreshold}: rake to $${sc.shortCap})`;
  if (p.dropOnFlopOnly) s += " · no flop no drop";
  return prefix + s;
}
