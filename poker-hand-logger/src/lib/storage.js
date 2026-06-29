// Persistence layer. Versioned keys so the schema can evolve safely.
// Hand entries store raw {rank, suit} card objects, which are JSON-safe.

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

export function loadSession() {
  if (typeof localStorage === "undefined") return { location: "", table: "", seat: "" };
  const s = safeParse(localStorage.getItem(SESSION_KEY), {});
  return {
    location: s.location || "",
    table: s.table || "",
    seat: s.seat || "",
    button: typeof s.button === "number" ? s.button : 1,
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
