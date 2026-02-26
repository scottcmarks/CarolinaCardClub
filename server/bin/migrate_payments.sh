#!/bin/bash

# Define the database file
DB_FILE="CarolinaCardClub.db"

# Check if database exists
if [ ! -f "$DB_FILE" ]; then
    echo "Error: $DB_FILE not found."
    exit 1
fi

echo "🚀 Starting migration: Payment table (Amount: NUMERIC(10,2) -> INTEGER)..."

# Execute SQLite commands safely
sqlite3 "$DB_FILE" <<EOF
-- 1. Disable Foreign Keys during the swap
PRAGMA foreign_keys=OFF;

BEGIN TRANSACTION;

-- 2. Create the new table matching your exact schema, but with Amount as INTEGER
CREATE TABLE IF NOT EXISTS "Payment_new" (
	"Payment_Id"	INTEGER NOT NULL UNIQUE,
	"Player_Id"	INTEGER NOT NULL DEFAULT 1,
	"Amount"	INTEGER NOT NULL DEFAULT 0,
	"Epoch"	INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("Payment_Id" AUTOINCREMENT),
	FOREIGN KEY("Player_Id") REFERENCES "Player"("Player_Id")
);

-- 3. Copy data, rounding the Amount to the nearest whole integer dollar
INSERT INTO "Payment_new" ("Payment_Id", "Player_Id", "Amount", "Epoch")
SELECT
    "Payment_Id",
    "Player_Id",
    CAST(ROUND("Amount") AS INTEGER),
    "Epoch"
FROM "Payment";

-- 4. Swap the tables
DROP TABLE "Payment";
ALTER TABLE "Payment_new" RENAME TO "Payment";

COMMIT;

-- 5. Re-enable Foreign Keys
PRAGMA foreign_keys=ON;
EOF

# Check exit status
if [ $? -eq 0 ]; then
    echo "✅ Migration successful! Amount is now INTEGER dollars."
else
    echo "❌ Migration failed. The database has been rolled back."
    exit 1
fi
