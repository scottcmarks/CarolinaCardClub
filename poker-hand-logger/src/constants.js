// Card + table model and visual theme.

export const RANKS = ["A", "K", "Q", "J", "T", "9", "8", "7", "6", "5", "4", "3", "2"];

// Four-color deck: color is read faster than shape and kills ♠/♣ mis-reads.
export const SUITS = [
  { s: "♠", key: "s", name: "Spades", color: "#1c1c1e" },
  { s: "♥", key: "h", name: "Hearts", color: "#d11a2a" },
  { s: "♦", key: "d", name: "Diamonds", color: "#1565c0" },
  { s: "♣", key: "c", name: "Clubs", color: "#1f8a4c" },
];

// Board first (default entry flow). Hero hole cards are last and terminal.
export const STREETS = [
  { name: "Flop", n: 3 },
  { name: "Turn", n: 1 },
  { name: "River", n: 1 },
  { name: "Hero", n: 2, terminal: true },
];

export const TOTAL = 7;
export const HOLE_START = 5; // indices 5,6 = hero hole cards

// 3-row keypad layout: A K Q J T / 9 8 7 6 5 / 4 3 2 (centered).
export const RANK_ROWS = [
  ["A", "K", "Q", "J", "T"],
  ["9", "8", "7", "6", "5"],
  ["4", "3", "2"],
];

export const SEAT_COUNT = 9;
export const DEFAULT_HERO_SEAT = 2;

// Poker position labels going CLOCKWISE around the table from the dealer
// button (so offset 0 = BTN, 1 = SB, 2 = BB, …). The button rotates one
// seat each hand.
export const POSITIONS_9 = ["BTN", "SB", "BB", "UTG", "UTG+1", "MP", "LJ", "HJ", "CO"];

export const theme = {
  felt: "radial-gradient(120% 80% at 50% -10%, #1d4a3e 0%, #14342b 45%, #0e241d 100%)",
  panel: "#10261f",
  card: "#F6F3EA",
  gold: "#C9A227",
  ink: "#23201A",
  textLight: "#F6F3EA",
};

export const tableTheme = {
  rail: "#3a2a1a",
  feltOval: "radial-gradient(120% 90% at 50% 35%, #1f5446 0%, #163a30 55%, #0f2a22 100%)",
};
