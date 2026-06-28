import { useState, useMemo, useCallback, useRef, useEffect } from "react";
import { TOTAL, HOLE_START } from "../constants.js";
import { cardId, firstEmpty, holeStr } from "../lib/cards.js";
import { loadLog, saveLog, loadSession, saveSession, maxId } from "../lib/storage.js";

const buzz = (ms = 8) => {
  if (typeof navigator !== "undefined" && navigator.vibrate) navigator.vibrate(ms);
};

const emptyHand = () => Array(TOTAL).fill(null);

export function useHandLogger() {
  const [cards, setCards] = useState(emptyHand);
  const [reveals, setReveals] = useState([]); // [{ seat, cards:[c,c] }]
  const [active, setActive] = useState({ type: "board", index: 0 });
  const [pendingRank, setPendingRank] = useState(null);
  const [undoStack, setUndoStack] = useState([]); // fill-order targets for the current hand
  const [session, setSession] = useState(loadSession);
  const [log, setLog] = useState(loadLog);
  const [editingId, setEditingId] = useState(null);
  const [flash, setFlash] = useState(null);
  const nextId = useRef(maxId(loadLog()) + 1);

  // Persist on change.
  useEffect(() => saveLog(log), [log]);
  useEffect(() => saveSession(session), [session]);

  const usedIds = useMemo(() => {
    const s = new Set(cards.filter(Boolean).map(cardId));
    reveals.forEach((r) => r.cards.forEach((c) => c && s.add(cardId(c))));
    return s;
  }, [cards, reveals]);

  const anyEntered = useMemo(
    () => cards.some(Boolean) || reveals.some((r) => r.cards.some(Boolean)),
    [cards, reveals]
  );
  const editingEntry = useMemo(
    () => log.find((h) => h.id === editingId) || null,
    [log, editingId]
  );

  const showFlash = (m) => {
    setFlash(m);
    setTimeout(() => setFlash((f) => (f === m ? null : f)), 1500);
  };

  const resetWorking = useCallback(() => {
    setCards(emptyHand());
    setReveals([]);
    setUndoStack([]);
    setActive({ type: "board", index: 0 });
    setPendingRank(null);
  }, []);

  const endHand = useCallback(
    (snap) => {
      const c = snap?.cards || cards;
      const rv = snap?.reveals || reveals;
      if (!c.some(Boolean) && !rv.some((r) => r.cards.some(Boolean))) return;
      const revealsRaw = rv
        .filter((r) => r.cards.some(Boolean))
        .map((r) => ({ seat: r.seat, cards: [...r.cards] }));

      if (editingId !== null) {
        setLog((prev) =>
          prev.map((h) => (h.id === editingId ? { ...h, cards: [...c], reveals: revealsRaw } : h))
        );
        showFlash("Hand updated");
        setEditingId(null);
      } else {
        const entry = {
          id: nextId.current++,
          ts: Date.now(),
          location: session.location,
          table: session.table,
          seat: session.seat,
          cards: [...c],
          reveals: revealsRaw,
        };
        setLog((p) => [entry, ...p]);
        showFlash(holeStr(c).includes("·") ? "Hand saved" : "Hand saved · " + holeStr(c));
      }
      resetWorking();
    },
    [cards, reveals, session, editingId, resetWorking]
  );

  const pickRank = useCallback((rank) => {
    buzz(6);
    setPendingRank((p) => (p === rank ? null : rank));
  }, []);

  const pickSuit = useCallback(
    (suitKey) => {
      if (pendingRank === null) return;
      const id = pendingRank + suitKey;
      if (usedIds.has(id)) return;
      buzz(12);
      const card = { rank: pendingRank, suit: suitKey };
      setPendingRank(null);
      setUndoStack((h) => [...h, active]);

      if (active.type === "board") {
        const next = [...cards];
        next[active.index] = card;
        // Auto-end only on a NEW hand when both hero cards are completed.
        if (
          editingId === null &&
          active.index >= HOLE_START &&
          next[HOLE_START] &&
          next[HOLE_START + 1]
        ) {
          endHand({ cards: next, reveals });
          return;
        }
        setCards(next);
        const e = firstEmpty(next);
        setActive({ type: "board", index: e === null ? active.index : e });
      } else {
        const nr = reveals.map((r) => ({ ...r, cards: [...r.cards] }));
        nr[active.r].cards[active.c] = card;
        setReveals(nr);
        if (active.c === 0) setActive({ type: "reveal", r: active.r, c: 1 });
        else {
          const e = firstEmpty(cards);
          setActive({ type: "board", index: e === null ? HOLE_START : e });
        }
      }
    },
    [pendingRank, usedIds, active, cards, reveals, endHand, editingId]
  );

  const selectTarget = useCallback((target) => {
    buzz(6);
    setPendingRank(null);
    setActive(target);
  }, []);

  const undo = useCallback(() => {
    setUndoStack((stack) => {
      if (!stack.length) return stack;
      buzz(10);
      const t = stack[stack.length - 1];
      setPendingRank(null);
      if (t.type === "board") {
        setCards((p) => {
          const n = [...p];
          n[t.index] = null;
          return n;
        });
        setActive({ type: "board", index: t.index });
      } else {
        setReveals((p) =>
          p.map((r, i) =>
            i === t.r ? { ...r, cards: r.cards.map((c, j) => (j === t.c ? null : c)) } : r
          )
        );
        setActive({ type: "reveal", r: t.r, c: t.c });
      }
      return stack.slice(0, -1);
    });
  }, []);

  const clearHand = useCallback(() => {
    buzz(20);
    resetWorking();
  }, [resetWorking]);

  const cancelEdit = useCallback(() => {
    buzz(12);
    setEditingId(null);
    resetWorking();
  }, [resetWorking]);

  const loadHand = useCallback((entry) => {
    buzz(10);
    setCards([...entry.cards]);
    setReveals(entry.reveals.map((r) => ({ seat: r.seat, cards: [...r.cards] })));
    setEditingId(entry.id);
    const e = firstEmpty(entry.cards);
    setActive({ type: "board", index: e === null ? 0 : e });
    setPendingRank(null);
    setUndoStack([]);
  }, []);

  const deleteHand = useCallback(
    (id) => {
      buzz(15);
      setLog((p) => p.filter((h) => h.id !== id));
      if (id === editingId) cancelEdit();
    },
    [editingId, cancelEdit]
  );

  const addReveal = useCallback(() => {
    buzz(8);
    setReveals((prev) => {
      const nr = [...prev, { seat: "", cards: [null, null] }];
      setActive({ type: "reveal", r: nr.length - 1, c: 0 });
      return nr;
    });
    setPendingRank(null);
  }, []);

  const removeReveal = useCallback(
    (r) => {
      buzz(12);
      setReveals((p) => p.filter((_, i) => i !== r));
      setUndoStack([]); // indices shift; keep undo safe
      setActive({ type: "board", index: firstEmpty(cards) ?? HOLE_START });
    },
    [cards]
  );

  const setRevealSeat = useCallback((r, val) => {
    setReveals((p) =>
      p.map((x, i) => (i === r ? { ...x, seat: val.replace(/\D/g, "").slice(0, 2) } : x))
    );
  }, []);

  const updateSession = useCallback((patch) => setSession((s) => ({ ...s, ...patch })), []);

  return {
    // state
    cards, reveals, active, pendingRank, session, log, editingId, editingEntry, flash,
    // derived
    usedIds, anyEntered, canUndo: undoStack.length > 0,
    // actions
    pickRank, pickSuit, selectTarget, undo, clearHand, cancelEdit, endHand,
    loadHand, deleteHand, addReveal, removeReveal, setRevealSeat, updateSession,
  };
}
