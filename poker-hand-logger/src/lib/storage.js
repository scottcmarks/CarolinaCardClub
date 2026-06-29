// Persistence layer. Versioned keys so the schema can evolve safely.
// Hand entries store raw {rank, suit} card objects, which are JSON-safe.

import {
  SEAT_COUNT,
  DEFAULT_HERO_SEAT,
  DEFAULT_HERO_NAME,
  defaultSeats,
} from "../constants.js";

const LOG_KEY = "phl:log:v1";
const SESSION_KEY = "phl:session:v1";

const safeParse = (raw, fallback) => {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
};

export function loadLog() {
  if (typeof localStorage === "undefined") return [];
  const data = safeParse(localStorage.getItem(LOG_KEY), []);
  return Array.isArray(data) ? data : [];
}

export function saveLog(log) {
  if (typeof localStorage === "undefined") return;
  try {
    localStorage.setItem(LOG_KEY, JSON.stringify(log));
  } catch {
    /* quota or private-mode; ignore */
  }
}

function normalizeSeats(seats) {
  if (!Array.isArray(seats) || seats.length === 0) return defaultSeats();
  return seats.slice(0, SEAT_COUNT).map((s, i) => ({
    occupied: s && typeof s.occupied === "boolean" ? s.occupied : true,
    name: (s && s.name) || `Player ${i + 1}`,
  }));
}

export function loadSession() {
  const base = {
    location: "",
    table: "",
    seat: String(DEFAULT_HERO_SEAT),
    button: 1,
    heroName: DEFAULT_HERO_NAME,
    rakeProfileId: "danville-1-3",
    seats: defaultSeats(),
    onboarded: false,
  };
  if (typeof localStorage === "undefined") return base;
  const s = safeParse(localStorage.getItem(SESSION_KEY), {});
  return {
    ...base,
    location: s.location || base.location,
    table: s.table || base.table,
    seat: s.seat || base.seat,
    button: typeof s.button === "number" ? s.button : base.button,
    heroName: s.heroName || base.heroName,
    rakeProfileId: s.rakeProfileId || base.rakeProfileId,
    seats: normalizeSeats(s.seats),
    onboarded: !!s.onboarded,
  };
}

export function saveSession(session) {
  if (typeof localStorage === "undefined") return;
  try {
    localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  } catch {
    /* ignore */
  }
}

// Highest existing id, so new hands never collide after a reload.
export function maxId(log) {
  return log.reduce((m, h) => (h.id > m ? h.id : m), 0);
}
