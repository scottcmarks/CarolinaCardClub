import { useState, useMemo, useCallback, useRef, useEffect } from "react";
import { TOTAL, HOLE_START, SEAT_COUNT, defaultSeats } from "../constants.js";
import { cardId, firstEmpty, holeStr } from "../lib/cards.js";
import { loadLog, saveLog, loadSession, saveSession, maxId } from "../lib/storage.js";
import { loadRakes, saveRakes, findRake, computeRake } from "../lib/rake.js";
import { reduceBetting, seedPosts } from "../lib/betting.js";
import {
  blinds,
  occupiedSeats,
  positionLabels,
  preflopOrder,
  postflopOrder,
} from "../lib/positions.js";

const buzz = (ms = 8) => {
  if (typeof navigator !== "undefined" && navigator.vibrate) navigator.vibrate(ms);
};

const emptyHand = () => Array(TOTAL).fill(null);
const nextStreetAfter = (phase) =>
  ({ preflop: "flop", flop: "turn", turn: "river" }[phase] || null);
const communityComplete = (cards, street) => {
  if (street === "flop") return !!(cards[0] && cards[1] && cards[2]);
  if (street === "turn") return !!cards[3];
  if (street === "river") return !!cards[4];
  return false;
};
const firstCommunityIndex = (street, cards) => {
  if (street === "flop") return [0, 1, 2].find((i) => !cards[i]) ?? 0;
  if (street === "turn") return 3;
  if (street === "river") return 4;
  return 0;
};
const clampSeat = (n) => Math.min(Math.max(parseInt(n, 10) || 1, 1), SEAT_COUNT);

export function useHandLogger() {
  const [cards, setCards] = useState(emptyHand);
  const [reveals, setReveals] = useState([]); // [{ seat, cards:[c,c] }]
  const [heroRevealed, setHeroRevealed] = useState(false);
  const [actions, setActions] = useState([]); // betting action log (incl. posts)
  const [phase, setPhase] = useState("preflop"); // preflop|flop|turn|river|showdown
  const [dealingStreet, setDealingStreet] = useState(null); // street whose board we're filling
  const [mode, setMode] = useState("betting"); // betting | cards
  const [active, setActive] = useState({ type: "board", index: HOLE_START });
  const [pendingRank, setPendingRank] = useState(null);
  const [snapshots, setSnapshots] = useState([]); // undo: full working-state snaps
  const [session, setSession] = useState(loadSession);
  const [rakes, setRakes] = useState(loadRakes);
  const [log, setLog] = useState(loadLog);
  const [editingId, setEditingId] = useState(null);
  const [flash, setFlash] = useState(null);
  const nextId = useRef(maxId(loadLog()) + 1);

  useEffect(() => saveLog(log), [log]);
  useEffect(() => saveSession(session), [session]);
  useEffect(() => saveRakes(rakes), [rakes]);

  const seats = session.seats || defaultSeats();
  const button = clampSeat(session.button);
  const heroSeat = clampSeat(session.seat);
  const rakeProfile = findRake(rakes, session.rakeProfileId);
  const positions = useMemo(() => positionLabels(seats, button), [seats, button]);
  const bet = useMemo(() => reduceBetting(actions, { seats, button }), [actions, seats, button]);

  const usedIds = useMemo(() => {
    const s = new Set(cards.filter(Boolean).map(cardId));
    reveals.forEach((r) => r.cards.forEach((c) => c && s.add(cardId(c))));
    return s;
  }, [cards, reveals]);

  const anyEntered = useMemo(
    () =>
      cards.some(Boolean) ||
      reveals.some((r) => r.cards.some(Boolean)) ||
      actions.some((a) => a.type !== "post" && a.type !== "street"),
    [cards, reveals, actions]
  );
  const editingEntry = useMemo(() => log.find((h) => h.id === editingId) || null, [log, editingId]);

  const showFlash = (m) => {
    setFlash(m);
    setTimeout(() => setFlash((f) => (f === m ? null : f)), 1500);
  };

  // ---- working-state snapshot (uniform undo across cards + betting) ----
  const snapshot = useCallback(
    () => ({ cards, reveals, heroRevealed, actions, phase, dealingStreet, mode, active }),
    [cards, reveals, heroRevealed, actions, phase, dealingStreet, mode, active]
  );
  const pushSnapshot = useCallback(() => setSnapshots((s) => [...s, snapshot()]), [snapshot]);

  const resetWorking = useCallback(
    (buttonForHand) => {
      const sb = rakeProfile.sb ?? 1;
      const bb = rakeProfile.bb ?? 3;
      setCards(emptyHand());
      setReveals([]);
      setHeroRevealed(false);
      setActions(seedPosts(seats, buttonForHand ?? button, sb, bb));
      setPhase("preflop");
      setDealingStreet(null);
      setMode("betting");
      setActive({ type: "board", index: HOLE_START });
      setPendingRank(null);
      setSnapshots([]);
    },
    [seats, button, rakeProfile]
  );

  // ---- finishing a hand (manual End, fold-out, or showdown End) ----
  const finishHand = useCallback(
    (actsArg, cardsArg, revealsArg, heroRevArg) => {
      const acts = actsArg || actions;
      const c = cardsArg || cards;
      const rv = revealsArg || reveals;
      const heroRev = heroRevArg ?? heroRevealed;
      const b = reduceBetting(acts, { seats, button });
      const sawFlop = !!(c[0] && c[1] && c[2]);
      const playersDealt = occupiedSeats(seats).length;
      const rk = computeRake({ pot: b.pot, playersDealt, sawFlop, profile: rakeProfile });

      const hasCards = c.some(Boolean);
      const hasReveal = rv.some((r) => r.cards.some(Boolean));
      const hasBetting = acts.some((a) => a.type !== "post" && a.type !== "street");
      if (!hasCards && !hasReveal && !hasBetting) return;

      const revealsRaw = rv
        .filter((r) => r.cards.some(Boolean))
        .map((r) => ({ seat: r.seat, cards: [...r.cards] }));
      const bl = blinds(seats, button);
      const common = {
        cards: [...c],
        reveals: revealsRaw,
        heroRevealed: heroRev,
        actions: acts.map((a) => ({ ...a })),
        pot: b.pot,
        rake: rk.total,
        blinds: bl ? { sb: rakeProfile.sb, bb: rakeProfile.bb, sbSeat: bl.sb, bbSeat: bl.bb } : null,
        button,
        seats: seats.map((s) => ({ ...s })),
        rakeProfileId: session.rakeProfileId,
      };

      if (editingId !== null) {
        setLog((prev) => prev.map((h) => (h.id === editingId ? { ...h, ...common } : h)));
        showFlash("Hand updated");
        setEditingId(null);
        resetWorking();
      } else {
        const entry = {
          id: nextId.current++,
          ts: Date.now(),
          location: session.location,
          table: session.table,
          seat: session.seat,
          heroName: session.heroName,
          ...common,
        };
        setLog((p) => [entry, ...p]);
        showFlash(holeStr(c).includes("·") ? "Hand saved" : "Hand saved · " + holeStr(c));
        const nextButton = (button % SEAT_COUNT) + 1;
        setSession((s) => ({ ...s, button: nextButton }));
        resetWorking(nextButton);
      }
    },
    [actions, cards, reveals, heroRevealed, seats, button, rakeProfile, editingId, session, resetWorking]
  );

  // ---- apply a new betting action log and drive phase transitions ----
  const commitActions = useCallback(
    (newActions) => {
      const nb = reduceBetting(newActions, { seats, button });
      setActions(newActions);
      if (nb.playersLeft <= 1) {
        finishHand(newActions);
        return;
      }
      if (nb.roundClosed) {
        if (phase === "river") {
          setPhase("showdown");
          setMode("cards");
          setHeroRevealed(true);
          setActive({ type: "board", index: HOLE_START });
        } else {
          const nextSt = nextStreetAfter(phase);
          setDealingStreet(nextSt);
          setMode("cards");
          setActive({ type: "board", index: firstCommunityIndex(nextSt, cards) });
        }
      }
    },
    [seats, button, phase, cards, finishHand]
  );

  // ---- betting: act for the current actor ----
  const act = useCallback(
    (type, amount) => {
      if (mode !== "betting" || bet.actor == null) return;
      buzz(type === "fold" ? 6 : 10);
      pushSnapshot();
      const a = { seat: bet.actor, street: phase, type };
      if (amount != null) a.amount = amount;
      commitActions([...actions, a]);
    },
    [mode, bet, phase, actions, pushSnapshot, commitActions]
  );

  // ---- betting: tap a seat to jump/correct ----
  const tapSeatToAct = useCallback(
    (n) => {
      if (mode !== "betting") return;
      const seat = Number(n);
      // correction: reopen a seat that folded THIS street
      if (bet.foldedStreet[seat] === phase) {
        buzz(8);
        pushSnapshot();
        // remove that seat's fold action within the current street
        let removed = false;
        const filtered = [];
        for (let i = actions.length - 1; i >= 0; i--) {
          const a = actions[i];
          if (!removed && a.type === "fold" && a.seat === seat && a.street === phase) {
            removed = true;
            continue;
          }
          filtered.unshift(a);
        }
        setActions(filtered);
        return;
      }
      // folded in a PRIOR street → can't fix inline; flag for the editor
      if (bet.foldedStreet[seat] != null && bet.foldedStreet[seat] !== phase) {
        showFlash("Prior-round fold — edit this hand offline");
        return;
      }
      if (bet.actor == null) return;
      if (seat === bet.actor) return; // already the actor
      // jump ahead: auto-fold pending seats between the actor and the tapped seat
      const order = phase === "preflop" ? preflopOrder(seats, button) : postflopOrder(seats, button);
      const ai = order.indexOf(bet.actor);
      const ti = order.indexOf(seat);
      if (ai === -1 || ti === -1 || ti <= ai) {
        showFlash("Use Undo to revise earlier action");
        return;
      }
      buzz(8);
      pushSnapshot();
      const folds = [];
      for (let i = ai; i < ti; i++) {
        const s = order[i];
        if (bet.inHand.includes(s)) folds.push({ seat: s, street: phase, type: "fold" });
      }
      commitActions([...actions, ...folds]);
    },
    [mode, bet, phase, actions, seats, button, pushSnapshot, commitActions]
  );

  // ---- card entry ----
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
      pushSnapshot();

      if (active.type === "board") {
        const next = [...cards];
        next[active.index] = card;
        setCards(next);

        // hero hole cards: stay on hero, advance to partner, then back to betting
        if (active.index >= HOLE_START) {
          const partner = active.index === HOLE_START ? HOLE_START + 1 : HOLE_START;
          if (!next[partner]) {
            setActive({ type: "board", index: partner });
          } else if (phase !== "showdown") {
            setMode("betting");
          }
          return;
        }

        // community card: if we're dealing a street and it's now complete, open betting
        if (dealingStreet && communityComplete(next, dealingStreet)) {
          setActions((prev) => [...prev, { type: "street", street: dealingStreet }]);
          setPhase(dealingStreet);
          setDealingStreet(null);
          setMode("betting");
          return;
        }
        // otherwise advance to the next empty community slot of this group
        if (dealingStreet) {
          setActive({ type: "board", index: firstCommunityIndex(dealingStreet, next) });
        } else {
          const e = firstEmpty(next);
          setActive({ type: "board", index: e === null ? active.index : e });
        }
      } else {
        // reveal entry (villain showdown hands)
        const nr = reveals.map((r) => ({ ...r, cards: [...r.cards] }));
        nr[active.r].cards[active.c] = card;
        setReveals(nr);
        if (active.c === 0) setActive({ type: "reveal", r: active.r, c: 1 });
      }
    },
    [pendingRank, usedIds, active, cards, reveals, phase, dealingStreet, pushSnapshot]
  );

  // select a card slot to fill (switches to card-entry mode)
  const selectTarget = useCallback((target) => {
    buzz(6);
    setPendingRank(null);
    setMode("cards");
    setActive(target);
  }, []);

  // tap a hero card: empty → enter; filled → toggle reveal
  const tapHeroCard = useCallback(
    (index) => {
      if (cards[index]) {
        buzz(6);
        setHeroRevealed((v) => !v);
      } else {
        selectTarget({ type: "board", index });
      }
    },
    [cards, selectTarget]
  );

  const undo = useCallback(() => {
    setSnapshots((stack) => {
      if (!stack.length) return stack;
      buzz(10);
      const snap = stack[stack.length - 1];
      setCards(snap.cards);
      setReveals(snap.reveals);
      setHeroRevealed(snap.heroRevealed);
      setActions(snap.actions);
      setPhase(snap.phase);
      setDealingStreet(snap.dealingStreet);
      setMode(snap.mode);
      setActive(snap.active);
      setPendingRank(null);
      return stack.slice(0, -1);
    });
  }, []);

  const clearHand = useCallback(() => {
    buzz(20);
    resetWorking();
  }, [resetWorking]);

  const endHand = useCallback(() => finishHand(), [finishHand]);

  const cancelEdit = useCallback(() => {
    buzz(12);
    setEditingId(null);
    resetWorking();
  }, [resetWorking]);

  const loadHand = useCallback((entry) => {
    buzz(10);
    setCards([...entry.cards]);
    setReveals((entry.reveals || []).map((r) => ({ seat: r.seat, cards: [...r.cards] })));
    setHeroRevealed(!!entry.heroRevealed);
    setActions((entry.actions || []).map((a) => ({ ...a })));
    setPhase("showdown");
    setDealingStreet(null);
    setMode("cards");
    setActive({ type: "board", index: HOLE_START });
    setEditingId(entry.id);
    setPendingRank(null);
    setSnapshots([]);
  }, []);

  const deleteHand = useCallback(
    (id) => {
      buzz(15);
      setLog((p) => p.filter((h) => h.id !== id));
      if (id === editingId) cancelEdit();
    },
    [editingId, cancelEdit]
  );

  // restart betting from scratch while editing (offline fix)
  const restartBetting = useCallback(() => {
    buzz(10);
    const sb = rakeProfile.sb ?? 1;
    const bb = rakeProfile.bb ?? 3;
    setActions(seedPosts(seats, button, sb, bb));
    setPhase("preflop");
    setDealingStreet(null);
    setMode("betting");
    setSnapshots([]);
  }, [seats, button, rakeProfile]);

  // ---- showdown reveals ----
  const selectSeat = useCallback((seatNum) => {
    buzz(6);
    setPendingRank(null);
    setMode("cards");
    const key = String(seatNum);
    setReveals((prev) => {
      const idx = prev.findIndex((r) => r.seat === key);
      if (idx >= 0) {
        const e = firstEmpty(prev[idx].cards);
        setActive({ type: "reveal", r: idx, c: e === null ? 0 : e });
        return prev;
      }
      const nr = [...prev, { seat: key, cards: [null, null] }];
      setActive({ type: "reveal", r: nr.length - 1, c: 0 });
      return nr;
    });
  }, []);

  const removeReveal = useCallback((r) => {
    buzz(12);
    setReveals((p) => p.filter((_, i) => i !== r));
  }, []);

  // ---- session + seat + rake mutation ----
  const updateSession = useCallback((patch) => setSession((s) => ({ ...s, ...patch })), []);
  const completeOnboarding = useCallback((patch) => {
    setSession((s) => ({ ...s, ...patch, onboarded: true }));
  }, []);
  const setButton = useCallback((seatNum) => {
    buzz(8);
    setSession((s) => ({ ...s, button: clampSeat(seatNum) }));
  }, []);
  const advanceButton = useCallback(() => {
    buzz(8);
    setSession((s) => ({ ...s, button: (clampSeat(s.button) % SEAT_COUNT) + 1 }));
  }, []);
  const setSeatOccupied = useCallback((n, occupied) => {
    setSession((s) => ({
      ...s,
      seats: s.seats.map((x, i) => (i === n - 1 ? { ...x, occupied } : x)),
    }));
  }, []);
  const setSeatName = useCallback((n, name) => {
    setSession((s) => ({
      ...s,
      seats: s.seats.map((x, i) => (i === n - 1 ? { ...x, name } : x)),
    }));
  }, []);
  const setRakeProfileId = useCallback((id) => updateSession({ rakeProfileId: id }), [updateSession]);
  const upsertRake = useCallback((profile) => {
    setRakes((rs) => {
      const i = rs.findIndex((r) => r.id === profile.id);
      if (i === -1) return [...rs, profile];
      return rs.map((r, j) => (j === i ? profile : r));
    });
  }, []);

  return {
    // working state
    cards, reveals, heroRevealed, active, pendingRank, mode, phase, dealingStreet,
    // derived
    bet, positions, seats, heroSeat, button, rakeProfile,
    usedIds, anyEntered, canUndo: snapshots.length > 0,
    // session/log
    session, log, rakes, editingId, editingEntry, flash,
    // card-entry actions
    pickRank, pickSuit, selectTarget, tapHeroCard, undo, clearHand, endHand,
    // betting actions
    act, tapSeatToAct,
    // showdown
    selectSeat, removeReveal,
    // hands
    loadHand, deleteHand, cancelEdit, restartBetting,
    // session/seat/rake
    updateSession, completeOnboarding, setButton, advanceButton,
    setSeatOccupied, setSeatName, setRakeProfileId, upsertRake,
  };
}
