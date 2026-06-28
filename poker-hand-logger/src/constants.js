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

export const theme = {
  felt: "radial-gradient(120% 80% at 50% -10%, #1d4a3e 0%, #14342b 45%, #0e241d 100%)",
  panel: "#10261f",
  card: "#F6F3EA",
  gold: "#C9A227",
  ink: "#23201A",
  textLight: "#F6F3EA",
};
