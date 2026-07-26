import { useState, useMemo, useCallback, useRef, useEffect } from "react";
import { SEAT_COUNT, defaultSeats } from "../constants.js";
import {
  cardId,
  firstEmpty,
  holeStr,
  GEO_NLHE,
  geoOf,
  holeStartOf,
  emptyHand,
  communityComplete,
  firstCommunityIndex,
} from "../lib/cards.js";
import { loadLog, saveLog, loadSession, saveSession, maxId } from "../lib/storage.js";
import { loadRakes, saveRakes, findRake, computeRake, gameOf, blockCharge } from "../lib/rake.js";
import {
  reduceBetting,
  seedPosts,
  settleStacks,
  settleResult,
  settleResultBoards,
  contestedPot,
  raiseLegality,
  potLimitMaxTo,
} from "../lib/betting.js";
import { showdownWinners, showdownWinnersMulti } from "../lib/handeval.js";
import {
  blinds,
  nextOccupied,
  occupiedSeats,
  positionLabels,
  preflopOrder,
  postflopOrder,
} from "../lib/positions.js";

const buzz = (ms = 8) => {
  if (typeof navigator !== "undefined" && navigator.vibrate) navigator.vibrate(ms);
};

const nextStreetAfter = (phase) =>
  ({ preflop: "flop", flop: "turn", turn: "river" }[phase] || null);
const clampSeat = (n) => Math.min(Math.max(parseInt(n, 10) || 1, 1), SEAT_COUNT);

export function useHandLogger() {
  // Per-hand card geometry: NLHE = 1 board / 2 hole; PLO = 4 hole; a
  // double-board bomb pot = 2 boards. The `cards` array is sized to match.
  const [geo, setGeo] = useState(GEO_NLHE);
  const [bomb, setBomb] = useState(null); // { ante, collection, participants } when this hand is a bomb pot
  const [cards, setCards] = useState(() => emptyHand(GEO_NLHE));
  const [reveals, setReveals] = useState([]); // [{ seat, cards:[…hole-sized] }]
  const [heroRevealed, setHeroRevealed] = useState(false);
  const [actions, setActions] = useState([]); // betting action log (incl. posts)
  const [phase, setPhase] = useState("preflop"); // preflop|flop|turn|river|showdown
  const [dealingStreet, setDealingStreet] = useState(null); // street whose board we're filling
  const [mode, setMode] = useState("betting"); // betting | cards
  const [active, setActive] = useState({ type: "board", index: holeStartOf(GEO_NLHE) });
  const [pendingRank, setPendingRank] = useState(null);
  const [snapshots, setSnapshots] = useState([]); // undo: full working-state snaps
  const [session, setSession] = useState(loadSession);
  const [rakes, setRakes] = useState(loadRakes);
  const [log, setLog] = useState(loadLog);
  const [editingId, setEditingId] = useState(null);
  const [flash, setFlash] = useState(null);
  const [settling, setSettling] = useState(false); // showdown: awaiting winner tap
  const [illegalPrompt, setIllegalPrompt] = useState(null); // { type, amount, reason } — override gate
  const nextId = useRef(maxId(loadLog()) + 1);

  useEffect(() => saveLog(log), [log]);
  useEffect(() => saveSession(session), [session]);
  useEffect(() => saveRakes(rakes), [rakes]);

  const seats = session.seats || defaultSeats();
  const button = clampSeat(session.button);
  const heroSeat = clampSeat(session.seat);
  const rakeProfile = findRake(rakes, session.rakeProfileId);
  const variant = gameOf(rakeProfile); // { game, hole, potLimit }
  const holeStart = holeStartOf(geo);
  const positions = useMemo(() => positionLabels(seats, button), [seats, button]);
  const bet = useMemo(
    () => reduceBetting(actions, { seats, button, bb: rakeProfile.bb ?? 3 }),
    [actions, seats, button, rakeProfile]
  );

  // Seed the blinds (and any bring-in) for a fresh (not-yet-started) hand —
  // including the very first hand of a session, and after a seating/button/
  // profile change before play begins. Also snaps the card geometry to the
  // selected game (switching to the PLO profile resizes a fresh hand to 4
  // hole cards). resetWorking handles subsequent hands; this covers resets.
  useEffect(() => {
    if (editingId !== null) return;
    const started = actions.some(
      (a) => !(a.type === "post" || (a.type === "straddle" && a.seeded))
    );
    const hasCards = cards.some(Boolean) || reveals.some((r) => r.cards.some(Boolean));
    if (started || hasCards) return;
    const wantGeo = { boards: 1, hole: variant.hole };
    if (geo.boards !== wantGeo.boards || geo.hole !== wantGeo.hole) {
      setGeo(wantGeo);
      setCards(emptyHand(wantGeo));
      setBomb(null);
      setActive({ type: "board", index: holeStartOf(wantGeo) });
    }
    const wanted = seedPosts(
      seats,
      button,
      rakeProfile.sb ?? 1,
      rakeProfile.bb ?? 3,
      rakeProfile.bringIn
    );
    const same =
      wanted.length === actions.length &&
      wanted.every(
        (w, i) =>
          actions[i] &&
          actions[i].seat === w.seat &&
          actions[i].amount === w.amount &&
          actions[i].type === w.type
      );
    if (!same) setActions(wanted);
  }, [seats, button, rakeProfile, variant, geo, editingId, actions, cards, reveals]);

  const usedIds = useMemo(() => {
    const s = new Set(cards.filter(Boolean).map(cardId));
    reveals.forEach((r) => r.cards.forEach((c) => c && s.add(cardId(c))));
    return s;
  }, [cards, reveals]);

  const anyEntered = useMemo(
    () =>
      cards.some(Boolean) ||
      reveals.some((r) => r.cards.some(Boolean)) ||
      actions.some(
        (a) =>
          a.type !== "post" &&
          a.type !== "street" &&
          !(a.type === "straddle" && a.seeded) // a seeded bring-in isn't play
      ),
    [cards, reveals, actions]
  );

  // Evaluate the showdown winner(s) from the board(s) + shown hands (retires
  // the winner-tap; the tap stays as the override for mucked / unknown hands).
  // Omaha (4-hole) hands must show ALL hole cards to compete; a double-board
  // bomb pot scores each board separately (half the pot each).
  const showdownEval = useMemo(() => {
    if (phase !== "showdown" && !settling) return null;
    const omaha = geo.hole === 4;
    const contenders = bet.inHand.map((seat) => {
      if (seat === heroSeat) return { seat, cards: cards.slice(holeStart, holeStart + geo.hole) };
      const rv = reveals.find((r) => String(r.seat) === String(seat));
      return { seat, cards: rv ? rv.cards : [] };
    });
    if (geo.boards > 1) {
      const boards = Array.from({ length: geo.boards }, (_, b) =>
        cards.slice(5 * b, 5 * b + 5).filter(Boolean)
      );
      if (boards.every((b) => b.length < 3)) return null;
      const m = showdownWinnersMulti(contenders, boards, omaha);
      if (!m.any) return null;
      const union = [...new Set(m.perBoard.flatMap((r) => (r ? r.winners : [])))];
      return {
        winners: union,
        names: m.names,
        best: m.perBoard.map((r) => (r ? r.best : "—")).join(" / "),
        perBoard: m.perBoard,
      };
    }
    const board = cards.slice(0, 5).filter(Boolean);
    if (board.length < 3) return null;
    return showdownWinners(contenders, board, omaha);
  }, [phase, settling, cards, reveals, bet, heroSeat, geo, holeStart]);

  // Straddle (UTG-only): allowed preflop, before any voluntary action, when the
  // table profile permits it. Amount(s) are site-dependent (auto if one). A
  // bring-in game already has its forced third post — no straddle on top.
  const straddleAmounts = rakeProfile.straddleAmounts || [];
  const canStraddle =
    mode === "betting" &&
    phase === "preflop" &&
    !rakeProfile.bringIn &&
    straddleAmounts.length > 0 &&
    !actions.some((a) => a.type === "straddle") &&
    !actions.some((a) => a.type !== "post" && a.type !== "straddle" && a.type !== "street") &&
    blinds(seats, button) != null;
  const editingEntry = useMemo(() => log.find((h) => h.id === editingId) || null, [log, editingId]);

  const showFlash = (m) => {
    setFlash(m);
    setTimeout(() => setFlash((f) => (f === m ? null : f)), 1500);
  };

  // ---- working-state snapshot (uniform undo across cards + betting) ----
  const snapshot = useCallback(
    () => ({ cards, reveals, heroRevealed, actions, phase, dealingStreet, mode, active, geo, bomb }),
    [cards, reveals, heroRevealed, actions, phase, dealingStreet, mode, active, geo, bomb]
  );
  const pushSnapshot = useCallback(() => setSnapshots((s) => [...s, snapshot()]), [snapshot]);

  const resetWorking = useCallback(
    (buttonForHand, seatsForHand) => {
      const sd = seatsForHand || seats;
      const sb = rakeProfile.sb ?? 1;
      const bb = rakeProfile.bb ?? 3;
      const g = { boards: 1, hole: gameOf(rakeProfile).hole };
      setGeo(g);
      setBomb(null);
      setCards(emptyHand(g));
      setReveals([]);
      setHeroRevealed(false);
      setActions(seedPosts(sd, buttonForHand ?? button, sb, bb, rakeProfile.bringIn));
      setPhase("preflop");
      setDealingStreet(null);
      setMode("betting");
      setActive({ type: "board", index: holeStartOf(g) });
      setPendingRank(null);
      setSnapshots([]);
      setSettling(false);
    },
    [seats, button, rakeProfile]
  );

  // ---- finishing a hand (manual End, fold-out, or showdown award) ----
  // winnerSeat: the seat that won the pot (fold-to-one is automatic; a showdown
  // uses the tap-the-winner SCAFFOLDING — a stand-in until the logger evaluates
  // hands itself). null winner ⇒ record only, no stack settlement.
  const finishHand = useCallback(
    (winnerArg, actsArg, cardsArg, revealsArg, heroRevArg, winnersBArg) => {
      const editing = editingId !== null;
      const acts = actsArg || actions;
      const c = cardsArg || cards;
      const rv = revealsArg || reveals;
      const heroRev = heroRevArg ?? heroRevealed;

      // when editing, reconstruct the hand's ORIGINAL context from the stored
      // entry (seats/button/rake/heroSeat/geometry) rather than the live session
      const ent = editing ? editingEntry : null;
      const ctxSeats = ent?.seats || seats;
      const ctxButton = ent?.button ?? button;
      const ctxProfile = ent ? findRake(rakes, ent.rakeProfileId) : rakeProfile;
      const ctxHeroSeat = ent ? clampSeat(ent.seat) : heroSeat;
      const ctxGeo = ent ? geoOf(ent) : geo;
      const ctxBomb = ent ? ent.bomb || null : bomb;

      const b = reduceBetting(acts, { seats: ctxSeats, button: ctxButton });
      const sawFlop = !!(c[0] && c[1] && c[2]);
      const playersDealt = occupiedSeats(ctxSeats).length;
      const pot = contestedPot(b.totalCommitted);
      // a bomb pot's rake is the collection each participant paid into the pot
      // ($8 × players, removed from the $25-a-head pot); otherwise the profile
      const rk = ctxBomb
        ? { total: (ctxBomb.collection || 0) * (ctxBomb.participants?.length || 0) }
        : computeRake({ pot, playersDealt, sawFlop, profile: ctxProfile });

      const hasCards = c.some(Boolean);
      const hasReveal = rv.some((r) => r.cards.some(Boolean));
      const hasBetting = acts.some(
        (a) =>
          a.type !== "post" && a.type !== "street" && !(a.type === "straddle" && a.seeded)
      );
      if (!hasCards && !hasReveal && !hasBetting && !ctxBomb) return;

      const norm = (w) =>
        (Array.isArray(w) ? w : w != null ? [w] : []).map(Number).filter((x) => b.inHand.includes(x));
      const winners = norm(winnerArg);
      // double board: separate winners per board (defaults to a scoop when the
      // caller doesn't distinguish, e.g. a manual override tap)
      const winnersB =
        ctxGeo.boards > 1 && winners.length ? (winnersBArg ? norm(winnersBArg) : winners) : null;
      const { winnings, unresolved } =
        winnersB && winnersB.length
          ? settleResultBoards(b.totalCommitted, winners, winnersB, rk.total)
          : settleResult(b.totalCommitted, winners, rk.total);
      const heroNet = winners.length
        ? (winnings[ctxHeroSeat] || 0) - (b.totalCommitted[ctxHeroSeat] || 0)
        : 0; // null winner ⇒ no result recorded, no P&L impact

      const revealsRaw = rv
        .filter((r) => r.cards.some(Boolean))
        .map((r) => ({ seat: r.seat, cards: [...r.cards] }));
      const bl = blinds(ctxSeats, ctxButton);
      const allWinners = [...new Set([...winners, ...(winnersB || [])])];
      const common = {
        cards: [...c],
        reveals: revealsRaw,
        heroRevealed: heroRev,
        actions: acts.map((a) => ({ ...a })),
        pot,
        rake: rk.total,
        winner: allWinners.length === 1 ? allWinners[0] : allWinners.length ? allWinners : null,
        ...(winnersB ? { winnersByBoard: [winners, winnersB] } : {}),
        heroNet,
        game: ctxGeo.hole === 4 ? "plo" : "nlhe",
        boards: ctxGeo.boards,
        hole: ctxGeo.hole,
        ...(ctxBomb ? { bomb: { ...ctxBomb } } : {}),
        blinds: bl
          ? {
              sb: ctxProfile.sb,
              bb: ctxProfile.bb,
              sbSeat: bl.sb,
              bbSeat: bl.bb,
              ...(ctxProfile.bringIn ? { bringIn: ctxProfile.bringIn } : {}),
            }
          : null,
        button: ctxButton,
        seats: ctxSeats.map((s) => ({ ...s })),
        rakeProfileId: ent ? ent.rakeProfileId : session.rakeProfileId,
      };

      if (editing) {
        // offline edit updates the record only — never re-settles stacks
        setLog((prev) => prev.map((h) => (h.id === editingId ? { ...h, ...common } : h)));
        showFlash(unresolved ? "Updated · verify side-pot stacks" : "Hand updated");
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
        showFlash(
          unresolved
            ? "Saved · side pot not settled — verify stacks"
            : holeStr(c, ctxGeo).includes("·")
            ? "Hand saved"
            : "Hand saved · " + holeStr(c, ctxGeo)
        );
        const nextButton = (button % SEAT_COUNT) + 1;
        setSession((s) => ({
          ...s,
          button: nextButton,
          ...(winners.length
            ? { seats: settleStacks(s.seats, b, winners, rk.total, winnersB || undefined) }
            : {}),
        }));
        resetWorking(nextButton);
      }
    },
    [actions, cards, reveals, heroRevealed, seats, button, heroSeat, rakeProfile, rakes, editingId, editingEntry, session, geo, bomb, resetWorking]
  );

  // ---- apply a new action log and drive phase transitions ----
  // Called after any betting action OR after a street's board is completed.
  // Handles the all-in run-out: if a freshly-opened street is already closed
  // (everyone all-in), it advances straight to the next board / showdown.
  const afterActionsChanged = useCallback(
    (newActions, cardsOverride) => {
      const c = cardsOverride || cards;
      const nb = reduceBetting(newActions, { seats, button });
      setActions(newActions);
      if (nb.playersLeft <= 1) {
        // folded to one — that player wins automatically (no tap needed)
        finishHand(nb.inHand[0] ?? null, newActions, c);
        return;
      }
      setPhase(nb.street);
      if (nb.roundClosed) {
        if (nb.street === "river") {
          setMode("cards");
          setHeroRevealed(true);
          setDealingStreet(null);
          setActive({ type: "board", index: holeStart });
        } else {
          const nextSt = nextStreetAfter(nb.street);
          setDealingStreet(nextSt);
          setMode("cards");
          setActive({ type: "board", index: firstCommunityIndex(nextSt, c, geo) });
        }
      } else {
        setDealingStreet(null);
        setMode("betting");
      }
    },
    [seats, button, cards, geo, holeStart, finishHand]
  );

  const stackOf = useCallback(
    (n) => {
      const s = seats[n - 1];
      return s && typeof s.stack === "number" ? s.stack : null;
    },
    [seats]
  );

  // ---- betting: act for the current actor ----
  const commitAction = useCallback(
    (type, amount) => {
      buzz(type === "fold" ? 6 : 10);
      pushSnapshot();
      const a = { seat: bet.actor, street: phase, type };
      if (amount != null) a.amount = amount;
      afterActionsChanged([...actions, a]);
    },
    [bet, phase, actions, pushSnapshot, afterActionsChanged]
  );

  // Gate rule-violating actions behind an explained "are you sure?" override
  // rather than blocking them (poker rules are computed, not enforced).
  const act = useCallback(
    (type, amount) => {
      if (mode !== "betting" || bet.actor == null) return;
      // With an all-in already in play, exact stacks are required to know whether
      // this call/raise is itself all-in and to build side pots — insist on them.
      if (
        (type === "call" || type === "bet" || type === "raise") &&
        stackOf(bet.actor) == null &&
        bet.allIn.some((s) => bet.inHand.includes(s))
      ) {
        showFlash(`Set S${bet.actor}'s stack first (all-in in play) — tap their name`);
        return;
      }
      const reason = raiseLegality(bet, type, amount, rakeProfile.bb ?? 3, {
        potLimit: variant.potLimit,
      });
      if (reason) {
        setIllegalPrompt({ type, amount, reason });
        return;
      }
      commitAction(type, amount);
    },
    [mode, bet, rakeProfile, variant, stackOf, commitAction]
  );

  const confirmIllegal = useCallback(() => {
    if (illegalPrompt) commitAction(illegalPrompt.type, illegalPrompt.amount);
    setIllegalPrompt(null);
  }, [illegalPrompt, commitAction]);
  const cancelIllegal = useCallback(() => setIllegalPrompt(null), []);

  // all-in: commit the actor's whole remaining stack. Stacks are mandatory for
  // an all-in — without one the pot/side-pot math and P&L can't be computed, so
  // we require it be set (tap the name → Stack) rather than guessing.
  const allIn = useCallback(
    () => {
      if (mode !== "betting" || bet.actor == null) return;
      const seat = bet.actor;
      const stack = stackOf(seat);
      if (stack == null) {
        showFlash(`Set S${seat}'s stack to log the all-in — tap their name`);
        return;
      }
      const remaining = Math.max(0, stack - (bet.totalCommitted[seat] || 0));
      const amount = (bet.committed[seat] || 0) + remaining;
      // pot-limit: a shove can't exceed the pot — warn (never block) like any rule
      if (variant.potLimit) {
        const maxTo = potLimitMaxTo(bet, seat);
        if (amount > maxTo) {
          setIllegalPrompt({
            type: "allin",
            amount,
            reason:
              `Pot limit: the maximum here is $${maxTo} (call + pot) — an all-in ` +
              `for $${amount} is over the pot.`,
          });
          return;
        }
      }
      buzz(16);
      pushSnapshot();
      afterActionsChanged([...actions, { seat, street: phase, type: "allin", amount }]);
    },
    [mode, bet, phase, actions, stackOf, variant, pushSnapshot, afterActionsChanged]
  );

  // post a UTG straddle before the action (a forced blind raise that acts last)
  const straddle = useCallback(
    (amount) => {
      const b = blinds(seats, button);
      if (!b) return;
      const utg = nextOccupied(seats, b.bb);
      if (utg == null) return;
      buzz(10);
      pushSnapshot();
      setActions((prev) =>
        prev.some((a) => a.type === "straddle")
          ? prev
          : [...prev, { seat: utg, street: "preflop", type: "straddle", amount }]
      );
    },
    [seats, button, pushSnapshot]
  );

  // ---- bomb pot (Danville PLO: at each half-hour collection) ----
  // Everyone chooses: pay the $8 collection and sit the hand out, or put
  // $17+$8 = $25 into the bomb pot. The pot forms BEFORE the rake is removed
  // (9 players ⇒ $225 at the flops); the hand's rake is $8 × participants.
  // No preflop betting — the boards (2 at Danville) come right out.
  const canBombPot =
    !!rakeProfile.bombPot &&
    mode === "betting" &&
    phase === "preflop" &&
    !anyEntered &&
    editingId === null;
  const startBombPot = useCallback(
    (participants) => {
      const bp = rakeProfile.bombPot;
      if (!bp || !participants || participants.length < 2) return;
      const collection = blockCharge(rakeProfile);
      const per = (bp.ante || 0) + collection;
      const g = { boards: bp.doubleBoard ? 2 : 1, hole: variant.hole };
      buzz(16);
      pushSnapshot();
      setGeo(g);
      setBomb({ ante: bp.ante || 0, collection, participants: [...participants] });
      setCards(emptyHand(g));
      setReveals([]);
      setHeroRevealed(false);
      setActions([
        ...participants.map((s) => ({ seat: s, street: "preflop", type: "post", amount: per })),
        { type: "street", street: "flop" },
      ]);
      setPhase("flop");
      setDealingStreet("flop");
      setMode("cards");
      setActive({ type: "board", index: 0 });
      setPendingRank(null);
      setSettling(false);
      // seated non-participants pay the collection out of their stacks; if the
      // hero sat out, count it toward the session's time charges
      const inSet = new Set(participants);
      setSession((s) => ({
        ...s,
        seats: s.seats.map((x, i) =>
          x.occupied && !inSet.has(i + 1) && typeof x.stack === "number"
            ? { ...x, stack: Math.max(0, x.stack - collection) }
            : x
        ),
        ...(!inSet.has(heroSeat) && !s.sittingOut
          ? { collections: (s.collections || 0) + 1 }
          : {}),
      }));
    },
    [rakeProfile, variant, heroSeat, pushSnapshot]
  );
  // manual fix-up for the half-hour collections the hero paid outside bomb pots
  const bumpCollections = useCallback((delta) => {
    buzz(8);
    setSession((s) => ({ ...s, collections: Math.max(0, (s.collections || 0) + delta) }));
  }, []);

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
        if (bet.inHand.includes(s) && !bet.allIn.includes(s))
          folds.push({ seat: s, street: phase, type: "fold" });
      }
      afterActionsChanged([...actions, ...folds]);
    },
    [mode, bet, phase, actions, seats, button, pushSnapshot, afterActionsChanged]
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

        // hero hole cards: stay on hero, advance to the next empty hole slot,
        // then back to betting (2 slots in hold'em, 4 in PLO)
        if (active.index >= holeStart) {
          const nxt = Array.from({ length: geo.hole }, (_, k) => holeStart + k).find(
            (i) => !next[i]
          );
          if (nxt != null) {
            setActive({ type: "board", index: nxt });
          } else if (phase !== "showdown") {
            setMode("betting");
          }
          return;
        }

        // community card: if we're dealing a street and it's now complete (all
        // boards), open that street's betting round (or auto-advance if
        // everyone's all-in)
        if (dealingStreet && communityComplete(next, dealingStreet, geo)) {
          const st = dealingStreet;
          setDealingStreet(null);
          afterActionsChanged([...actions, { type: "street", street: st }], next);
          return;
        }
        // otherwise advance to the next empty community slot of this group
        if (dealingStreet) {
          setActive({ type: "board", index: firstCommunityIndex(dealingStreet, next, geo) });
        } else {
          const e = firstEmpty(next);
          setActive({ type: "board", index: e === null ? active.index : e });
        }
      } else {
        // a shown/exposed card for any seat — can be entered at ANY point in the
        // hand (a flash, a tabled card, a showdown). A fully-shown hand (2 cards
        // in hold'em, all 4 in PLO) is eligible to win the showdown.
        const nr = reveals.map((r) => ({ ...r, cards: [...r.cards] }));
        nr[active.r].cards[active.c] = card;
        setReveals(nr);
        const e = nr[active.r].cards.findIndex((x) => !x);
        if (e >= 0) setActive({ type: "reveal", r: active.r, c: e });
        else if (phase !== "showdown") setMode("betting"); // all in → back to the action
      }
    },
    [pendingRank, usedIds, active, cards, reveals, phase, dealingStreet, actions, geo, holeStart, pushSnapshot, afterActionsChanged]
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
      if (snap.geo) setGeo(snap.geo);
      setBomb(snap.bomb ?? null);
      setPendingRank(null);
      return stack.slice(0, -1);
    });
  }, []);

  const clearHand = useCallback(() => {
    buzz(20);
    resetWorking();
  }, [resetWorking]);

  // End hand → award the pot. Fold-to-one or a walk settles immediately; a
  // contested pot enters "settling" and prompts the winner tap (scaffolding).
  const endHand = useCallback(() => {
    if (editingId !== null) {
      finishHand(editingEntry ? editingEntry.winner ?? null : null);
      return;
    }
    if (bet.playersLeft >= 2 && bet.pot > 0) {
      setSettling(true);
      return;
    }
    finishHand(bet.playersLeft === 1 ? bet.inHand[0] : null);
  }, [editingId, editingEntry, bet, finishHand]);

  const awardTo = useCallback(
    (winners) => {
      buzz(12);
      setSettling(false);
      // double board: when the taps match the evaluator's winners, settle each
      // board separately from the eval; a manual OVERRIDE (taps differ, or no
      // eval) awards the tapped seat(s) both boards — a scoop.
      if (geo.boards > 1 && showdownEval?.perBoard) {
        const tapped = (Array.isArray(winners) ? winners : [winners]).map(Number);
        const union = showdownEval.winners || [];
        const sameSet =
          tapped.length === union.length && tapped.every((w) => union.includes(w));
        const [a, b] = showdownEval.perBoard;
        if (sameSet && (a?.winners?.length || b?.winners?.length)) {
          finishHand(
            a?.winners?.length ? a.winners : tapped,
            null, null, null, undefined,
            b?.winners?.length ? b.winners : tapped
          );
          return;
        }
      }
      finishHand(winners); // scalar or array — normalized in finishHand
    },
    [finishHand, geo, showdownEval]
  );
  const skipSettle = useCallback(() => {
    setSettling(false);
    finishHand(null);
  }, [finishHand]);
  const cancelSettle = useCallback(() => setSettling(false), []);

  const cancelEdit = useCallback(() => {
    buzz(12);
    setEditingId(null);
    resetWorking();
  }, [resetWorking]);

  const loadHand = useCallback((entry) => {
    buzz(10);
    const g = geoOf(entry);
    setGeo(g);
    setBomb(entry.bomb || null);
    setCards([...entry.cards]);
    setReveals((entry.reveals || []).map((r) => ({ seat: r.seat, cards: [...r.cards] })));
    setHeroRevealed(!!entry.heroRevealed);
    setActions((entry.actions || []).map((a) => ({ ...a })));
    setPhase("showdown");
    setDealingStreet(null);
    setMode("cards");
    setActive({ type: "board", index: holeStartOf(g) });
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

  // restart betting from scratch while editing (offline fix). A bomb-pot hand
  // restarts from its antes, not from blinds.
  const restartBetting = useCallback(() => {
    buzz(10);
    if (bomb) {
      const per = (bomb.ante || 0) + (bomb.collection || 0);
      setActions([
        ...(bomb.participants || []).map((s) => ({
          seat: s,
          street: "preflop",
          type: "post",
          amount: per,
        })),
        { type: "street", street: "flop" },
      ]);
      setPhase("flop");
    } else {
      const sb = rakeProfile.sb ?? 1;
      const bb = rakeProfile.bb ?? 3;
      setActions(seedPosts(seats, button, sb, bb, rakeProfile.bringIn));
      setPhase("preflop");
    }
    setDealingStreet(null);
    setMode("betting");
    setSnapshots([]);
  }, [seats, button, rakeProfile, bomb]);

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
      const nr = [...prev, { seat: key, cards: Array(geo.hole).fill(null) }];
      setActive({ type: "reveal", r: nr.length - 1, c: 0 });
      return nr;
    });
  }, [geo]);

  const removeReveal = useCallback((r) => {
    buzz(12);
    setReveals((p) => p.filter((_, i) => i !== r));
  }, []);

  // enter a seat's shown cards at any point in the hand (hero → own hole slot,
  // villain → a reveal). A fully-shown hand is eligible to win the showdown.
  const enterCards = useCallback(
    (n) => {
      if (n === heroSeat && !session.sittingOut) {
        const holeIdxs = Array.from({ length: geo.hole }, (_, k) => holeStart + k);
        const i = holeIdxs.find((x) => !cards[x]) ?? holeIdxs[0];
        selectTarget({ type: "board", index: i });
      } else {
        selectSeat(n);
      }
    },
    [heroSeat, session.sittingOut, cards, geo, holeStart, selectTarget, selectSeat]
  );

  // ---- session + seat + rake mutation ----
  const updateSession = useCallback((patch) => setSession((s) => ({ ...s, ...patch })), []);
  const completeOnboarding = useCallback((patch) => {
    // hybrid timing: auto-start the clock on the FIRST setup only. Re-opening
    // setup later leaves the clock (incl. an ended session) untouched.
    setSession((s) => ({
      ...s,
      ...patch,
      onboarded: true,
      sittingOut: false, // finishing setup means you're seated
      ...(s.onboarded ? {} : { startedAt: Date.now(), endedAt: null }),
    }));
  }, []);
  const setSessionStart = useCallback(
    (ts) =>
      setSession((s) => ({ ...s, startedAt: Math.min(ts, s.endedAt || Date.now()) })),
    []
  );
  const endSession = useCallback(() => {
    buzz(10);
    setSession((s) => ({ ...s, endedAt: Date.now() }));
  }, []);
  const startNewSession = useCallback(() => {
    buzz(10);
    setSession((s) => ({ ...s, startedAt: Date.now(), endedAt: null, prepaid: false, collections: 0 }));
  }, []);
  const setPrepaid = useCallback((v) => setSession((s) => ({ ...s, prepaid: !!v })), []);
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
  const setSeatStack = useCallback((n, stack) => {
    const v = stack === "" || stack == null ? null : Math.max(0, parseInt(stack, 10) || 0);
    setSession((s) => ({
      ...s,
      seats: s.seats.map((x, i) => (i === n - 1 ? { ...x, stack: v } : x)),
    }));
  }, []);

  // occupancy/position changes reseed the (between-hands) working hand so blinds
  // + positions track the new seating.
  const applySeating = useCallback(
    (newSeats, patch) => {
      // seating changes happen between hands — don't wipe a hand mid-entry
      if (anyEntered) {
        showFlash("Finish or clear the hand first");
        return;
      }
      setSession((s) => ({ ...s, seats: newSeats, ...patch }));
      resetWorking(button, newSeats);
    },
    [anyEntered, button, resetWorking]
  );

  const moveHeroTo = useCallback(
    (n) => {
      buzz(8);
      const to = clampSeat(n);
      if (to === heroSeat && !session.sittingOut) return;
      const st = seats[heroSeat - 1]?.stack ?? null;
      const newSeats = seats.map((x, i) => {
        if (i + 1 === heroSeat) return { ...x, occupied: false, stack: null }; // stack travels with hero
        if (i + 1 === to) return { ...x, occupied: true, name: session.heroName, stack: st };
        return x;
      });
      applySeating(newSeats, { seat: String(to), sittingOut: false });
    },
    [seats, heroSeat, session.heroName, session.sittingOut, applySeating]
  );

  const heroStandUp = useCallback(() => {
    buzz(10);
    const newSeats = seats.map((x, i) => (i + 1 === heroSeat ? { ...x, occupied: false } : x));
    applySeating(newSeats, { sittingOut: true }); // keep session.seat so the stack stays put
  }, [seats, heroSeat, applySeating]);

  const heroSitDown = useCallback(
    (n) => {
      buzz(8);
      const to = clampSeat(n);
      const st = seats[heroSeat - 1]?.stack ?? null; // hero's stack rests on the old seat entry
      const newSeats = seats.map((x, i) =>
        i + 1 === to ? { ...x, occupied: true, name: session.heroName, stack: st } : x
      );
      applySeating(newSeats, { seat: String(to), sittingOut: false });
    },
    [seats, heroSeat, session.heroName, applySeating]
  );

  const seatVillain = useCallback(
    (n) => {
      // a fresh occupant starts from an unknown (null) stack
      const newSeats = seats.map((x, i) =>
        i + 1 === n ? { ...x, occupied: true, name: x.name || `Player ${n}`, stack: null } : x
      );
      applySeating(newSeats, {});
    },
    [seats, applySeating]
  );

  const vacateSeat = useCallback(
    (n) => {
      buzz(8);
      // player leaves with their chips — clear the seat's stack
      const newSeats = seats.map((x, i) => (i + 1 === n ? { ...x, occupied: false, stack: null } : x));
      applySeating(newSeats, {});
    },
    [seats, applySeating]
  );
  const setRakeProfileId = useCallback((id) => updateSession({ rakeProfileId: id }), [updateSession]);
  const upsertRake = useCallback((profile) => {
    setRakes((rs) => {
      const i = rs.findIndex((r) => r.id === profile.id);
      if (i === -1) return [...rs, profile];
      return rs.map((r, j) => (j === i ? profile : r));
    });
  }, []);
  const deleteRake = useCallback((id) => {
    setRakes((rs) => {
      if (rs.length <= 1) return rs;
      const next = rs.filter((r) => r.id !== id);
      setSession((s) => (s.rakeProfileId === id ? { ...s, rakeProfileId: next[0].id } : s));
      return next;
    });
  }, []);

  return {
    // working state
    cards, reveals, heroRevealed, active, pendingRank, mode, phase, dealingStreet, settling,
    // variant / geometry
    geo, holeStart, variant, bomb,
    // derived
    bet, positions, seats, heroSeat, button, rakeProfile,
    usedIds, anyEntered, canUndo: snapshots.length > 0,
    potMaxTo: variant.potLimit && bet.actor != null ? potLimitMaxTo(bet) : null,
    // settling
    awardTo, skipSettle, cancelSettle, showdownEval,
    // session/log
    session, log, rakes, editingId, editingEntry, flash,
    // card-entry actions
    pickRank, pickSuit, selectTarget, tapHeroCard, undo, clearHand, endHand,
    // betting actions
    act, allIn, tapSeatToAct, stackOf, straddle, canStraddle, straddleAmounts,
    canBombPot, startBombPot, bumpCollections,
    illegalPrompt, confirmIllegal, cancelIllegal,
    // showdown / reveals (any time)
    selectSeat, removeReveal, enterCards,
    // hands
    loadHand, deleteHand, cancelEdit, restartBetting,
    // session/seat/rake
    updateSession, completeOnboarding, setButton, advanceButton,
    setSeatOccupied, setSeatName, setSeatStack, setRakeProfileId, upsertRake, deleteRake,
    setSessionStart, endSession, startNewSession, setPrepaid,
    moveHeroTo, heroStandUp, heroSitDown, seatVillain, vacateSeat,
  };
}
