BEGIN TRANSACTION;

-- 1. Create the PokerTable table
CREATE TABLE IF NOT EXISTS "PokerTable" (
	"PokerTable_Id"	INTEGER NOT NULL UNIQUE,
	"Name"	TEXT NOT NULL UNIQUE,
	"Capacity"	INTEGER NOT NULL DEFAULT 10 CHECK(Capacity > 0 AND Capacity <= 20),
	"IsActive"	INTEGER NOT NULL DEFAULT 1,
	PRIMARY KEY("PokerTable_Id" AUTOINCREMENT)
);

-- 2. Insert Default Tables
INSERT OR IGNORE INTO PokerTable (Name) VALUES ('Table 1');
INSERT OR IGNORE INTO PokerTable (Name) VALUES ('Table 2');

-- 3. Modify Session Table
ALTER TABLE Session ADD COLUMN PokerTable_Id INTEGER REFERENCES PokerTable(PokerTable_Id);
ALTER TABLE Session ADD COLUMN Seat_Number INTEGER CHECK(Seat_Number BETWEEN 1 AND 20);
ALTER TABLE Session ADD COLUMN Is_Prepaid INTEGER DEFAULT 0 CHECK(Is_Prepaid IN (0, 1));
ALTER TABLE Session ADD COLUMN Prepay_Amount NUMERIC DEFAULT 0.00 CHECK(Prepay_Amount >= 0);

-- 4. Modify Player_Category
ALTER TABLE Player_Category ADD COLUMN Prepay_Hours INTEGER DEFAULT 5;

-- 5. Set defaults for existing active sessions (move to Table 1, no seat)
UPDATE Session
SET PokerTable_Id = (SELECT PokerTable_Id FROM PokerTable WHERE Name='Table 1')
WHERE Stop_Epoch IS NULL;

-- 6. Enforce "One Player Per Seat" (Partial Unique Index)
-- This ensures you cannot put two people in Seat 1 at Table 1 at the same time.
CREATE UNIQUE INDEX IF NOT EXISTS "idx_active_seat"
ON "Session" ("PokerTable_Id", "Seat_Number")
WHERE "Stop_Epoch" IS NULL AND "Seat_Number" IS NOT NULL;

-- 7. RECREATE VIEWS (Crucial for API visibility)
DROP VIEW IF EXISTS "Session_Panel_List";
DROP VIEW IF EXISTS "Session_List";
DROP VIEW IF EXISTS "Session_Amount_List";
DROP VIEW IF EXISTS "Session_Rate_List";

CREATE VIEW "Session_Rate_List" AS
SELECT
    s.Session_Id, s.Player_Id, s.Start_Epoch as Session_Start_Epoch, s.Stop_Epoch as Session_Stop_Epoch,
    IFNULL(p.NickName,p.Name) as Name, pc.Name as Category, pc.Player_Category_Id as Category_Id,
    pc.Start as Rate_Start_Epoch, pc.Stop as Rate_Stop_Epoch, pc.Rate as Rate, pc.Description as Rate_Description,
    s.Is_Prepaid, s.Prepay_Amount
FROM Session as s, Player as p, Player_Category_Rate_Interval_List as pc
WHERE s.Player_Id == p.Player_Id AND p.Player_Category_Id == pc.Player_Category_Id;

CREATE VIEW "Session_Amount_List" AS
SELECT
    sr.Session_Id, sr.Session_Start_Epoch, sr.Session_Stop_Epoch,
    CASE WHEN sr.Session_Stop_Epoch IS NULL THEN NULL ELSE sr.Session_Stop_Epoch - sr.Session_Start_Epoch END as Duration_In_Seconds,
    sr.Player_Id, sr.Name, sr.Category, sr.Rate, sr.Rate_Description, sr.Is_Prepaid, sr.Prepay_Amount,
    CASE
        WHEN sr.Is_Prepaid = 1 THEN sr.Prepay_Amount
        WHEN sr.Session_Stop_Epoch IS NULL THEN NULL
        ELSE round(MAX(sr.Session_Stop_Epoch - sr.Session_Start_Epoch, 0) * sr.Rate  / 3600.0 )
    END as Amount
FROM Session_Rate_List as sr ORDER BY sr.Session_Stop_Epoch ASC, sr.Category_Id ASC, sr.Name ASC;

CREATE VIEW "Session_List" AS
SELECT
    s.Session_Id, s.Player_Id, IFNULL(p.NickName,p.Name) as "Name", s.Start_Epoch, s.Stop_Epoch,
    c.Name as "Category", s.PokerTable_Id, s.Seat_Number, s.Is_Prepaid, s.Prepay_Amount
FROM Player as p
INNER JOIN Player_Category as c ON p.Player_Category_Id = c.Player_Category_Id
INNER JOIN Session as s ON p.Player_Id = s.Player_Id
ORDER BY CASE WHEN s.Stop_Epoch IS NULL THEN 0 ELSE 1 END, s.Start_Epoch ASC, c.Player_Category_Id ASC, IFNULL(p.NickName,p.Name) ASC;

CREATE VIEW "Session_Panel_List" AS
SELECT
    sl.Session_Id, sl.Player_Id, sl.Name, sl.Start_Epoch, sl.Stop_Epoch, sl.PokerTable_Id, sl.Seat_Number, sl.Is_Prepaid, sl.Prepay_Amount,
    sal.Duration_In_Seconds, sal.Amount, pb.Balance, sal.Rate
FROM Session_List as sl
JOIN Session_Amount_List as sal ON sl.Session_Id == sal.Session_Id
JOIN Player_Balance as pb ON sl.Player_Id == pb.Player_Id
ORDER BY CASE WHEN sl.Stop_Epoch IS NULL THEN 0 ELSE 1 END, sal.Rate, sl.Name;

COMMIT;
