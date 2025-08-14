

BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS "Payment" (
	"Payment_ID"	         INTEGER NOT NULL UNIQUE,
	"Player_ID"	         INTEGER NOT NULL DEFAULT 1,
	"Amount"	         NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
	"Epoch"	                 INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("Payment_ID" AUTOINCREMENT),
	FOREIGN KEY("Player_ID") REFERENCES "Player"("Player_ID")
);

CREATE TABLE IF NOT EXISTS "Player" (
	"Player_ID"	INTEGER NOT NULL UNIQUE,
	"Played_Super_Bowl"	INTEGER NOT NULL DEFAULT 0,
	"Name"	                TEXT NOT NULL,
	"Email_address"	        TEXT,
	"Phone_number"	        TEXT,
	"Other_phone_number_1"	TEXT,
	"Other_phone_number_2"	TEXT,
	"Other_phone_number_3"	TEXT,
	"Player_Category_ID"	INTEGER,
	"NickName"	        TEXT,
	"Flag"	                TEXT
	PRIMARY KEY("Player_ID" AUTOINCREMENT)
);

CREATE TABLE IF NOT EXISTS "Player_Category" (
	"Player_Category_ID"	INTEGER NOT NULL UNIQUE,
	"Name"	                TEXT NOT NULL,
	"Rate_Interval_ID"	INTEGER NOT NULL DEFAULT 3,
	"Hourly_Rate_ID"	INTEGER
	PRIMARY KEY("Player_Category_ID" AUTOINCREMENT)
);

CREATE TABLE IF NOT EXISTS "Player_Info" (
	"Player_ID"	INTEGER,
	"Name"	        TEXT
);

CREATE TABLE IF NOT EXISTS "Rate" (
	"Rate_ID"	INTEGER NOT NULL UNIQUE,
	"Rate"	INTEGER(10, 2) NOT NULL DEFAULT 0.00,
	"Description"	TEXT,
	PRIMARY KEY("Rate_ID" AUTOINCREMENT)
);

CREATE TABLE IF NOT EXISTS "Rate_Interval" (
	"Rate_Interval_ID"	INTEGER NOT NULL UNIQUE,
	"Start"	TEXT NOT NULL,
	"Stop"	TEXT NOT NULL,
	"Rate_ID"	INTEGER NOT NULL,
	"Start_Epoch"	INTEGER NOT NULL DEFAULT 0,
	"Stop_Epoch"	INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("Rate_Interval_ID" AUTOINCREMENT)
);

CREATE TABLE IF NOT EXISTS "Session" (
	"Session_ID"	INTEGER NOT NULL UNIQUE,
	"Player_ID"	INTEGER NOT NULL,
	"Start_Epoch"	INTEGER NOT NULL DEFAULT 0,
	"Stop_Epoch"	INTEGER,
	PRIMARY KEY("Session_ID" AUTOINCREMENT),
	FOREIGN KEY("Player_ID") REFERENCES "Player"
);

CREATE TABLE IF NOT EXISTS "sqlite_stat4" (
	"tbl"	,
	"idx"	,
	"neq"	,
	"nlt"	,
	"ndlt"	,
	"sample"
);

CREATE VIEW "Payment_Rate_Interval_ID_View" AS
SELECT
pmt.Player_ID as Player_ID,
IFNULL(p.NickName, p.Name) as Player_Name,
pmt.Epoch as Payment_Epoch, pmt.Amount,
c.Rate_Interval_ID as Rate_Interval_ID
FROM
Payment as pmt
JOIN
Player as p
JOIN
Player_Category as c
WHERE pmt.Player_ID == p.Player_ID
AND p.Player_Category_ID == c.Player_Category_ID;

CREATE VIEW "Payment_Rate_View" AS SELECT
pmt.Player_ID as Player_ID,
pmt.Epoch as Payment_Epoch, pmt.Amount,
c.Rate_Interval_ID as Rate_Interval_ID,
r.Rate as Hourly_Rate, r.Description as Rate_Description,
pmt.Amount*3600/r.Rate as Purchased_Seconds,
CAST(pmt.Amount*3600/r.Rate / 3600 AS TEXT) || ':' ||
    PRINTF('%02d', (pmt.Amount*3600/r.Rate % 3600) / 60) AS formatted_time
FROM
Payment as pmt
JOIN
Player as p
JOIN
Player_Category as c
JOIN
Rate_Interval as ri
JOIN
Rate as r
WHERE pmt.Player_ID == p.Player_ID
AND p.Player_Category_ID == c.Player_Category_ID
AND c.Rate_Interval_ID == ri.Rate_Interval_ID
AND (pmt.Epoch BETWEEN unixepoch(ri.Start) AND unixepoch(ri.Stop))
AND ri.Rate_ID == r.Rate_ID;

CREATE VIEW "Player_Balance_View" AS
SELECT p.Player_ID, p.Total_Payment - IFNULL(sa.Total_Amount,0.00) as Balance
FROM Player_Total_Payment_View as p
LEFT JOIN Player_Total_Session_Amount_View as sa ON p.Player_ID == sa.Player_ID;

CREATE VIEW "Player_Category_Rate_Interval_View" AS
SELECT cat.Player_Category_ID,
       cat.Name,
       riv.Start,
       riv.Stop,
       riv.Rate,
       riv.Description
FROM Player_Category as cat, Rate_Interval_View as riv
WHERE cat.Rate_Interval_ID == riv.Rate_Interval_ID;

CREATE VIEW "Player_Most_Recent_Session_Start_Epoch_View" AS
SELECT
  s.Player_ID        as Player_ID,
  s.Session_ID       as Session_ID,
  MAX(s.Start_Epoch) as Most_Recent_Start_Epoch
FROM Session as s
GROUP BY s.Player_ID
ORDER BY s.Start_Epoch DESC;

CREATE VIEW "Player_Selection_View" AS
SELECT
  p.Player_ID,
  IFNULL(p.NickName, p.Name) as Name,
  IFNULL(b.Balance,0.00) as Balance
 FROM  Player as p
 LEFT JOIN Player_Most_Recent_Session_Start_Epoch_View as s ON p.Player_ID == s.Player_ID
 LEFT JOIN Player_Balance_View as b ON p.Player_ID == b.Player_ID
WHERE p.Phone_number is NOT NULL AND p.Phone_number != '***MISSING***' and p.Flag is  NULL
ORDER by s.Most_Recent_Start_Epoch DESC, p.Player_Category_ID ASC, Name ASC;

CREATE VIEW "Player_Total_Payment_View" AS
SELECT p.Player_ID, IFNULL(SUM(pmt.Amount),0) as Total_Payment
FROM  Player as p LEFT JOIN Payment as pmt ON p.Player_ID == pmt.Player_ID
GROUP BY p.Player_ID;

CREATE VIEW "Player_Total_Session_Amount_View" AS SELECT
	a.Player_ID,
	a.Name,
	SUM(a.Amount) as Total_Amount
FROM
Session_Amount_View as a
GROUP BY a.Player_ID;

CREATE VIEW "Purchased_Seconds_View" AS SELECT
pidv.Player_ID, pidv.Player_Name, strftime('%Y-%m-%d %I:%M %P', datetime(pidv.Payment_Epoch, 'unixepoch')) as Purchase_Time , PRINTF('\$%d',pidv.Amount) as Amount,
PRINTF('\$%0.02f/hr',  riv.Rate) as Rate, pidv.Amount * 3600 / riv.Rate as Purchased_Secs
FROM
Payment_Rate_Interval_ID_View as pidv
LEFT JOIN
Rate_Interval_View riv
ON pidv.Rate_Interval_ID == riv.Rate_Interval_ID
ORDER BY Purchase_Time ASC;

CREATE VIEW "Rate_Interval_View" AS SELECT
    Rate_Interval.Rate_Interval_ID,
	strftime('%Y-%m-%d %I:%M %P', datetime(Rate_Interval.Start_Epoch, 'unixepoch')) as Start,
	strftime('%Y-%m-%d %I:%M %P', datetime(Rate_Interval.Stop_Epoch, 'unixepoch')) as Stop,
	Rate.Rate as Rate,
	Rate.Description
  FROM
    Rate_Interval
  LEFT JOIN
     Rate
WHERE
    Rate_Interval.Rate_ID == Rate.Rate_ID;

CREATE VIEW "Session_Amount_View" AS
SELECT
	srv.Session_ID,
	srv.Session_Start_Epoch,
	srv.Session_Stop_Epoch,
    MAX(srv.Effective_Session_Stop_Epoch - srv.Session_Start_Epoch, 0) as Duration_In_Seconds,
	srv.Player_ID,
	srv.Name,
    srv.Category,
    srv.Rate,
    srv.Rate_Description,
   round ( MAX(  srv.Effective_Session_Stop_Epoch - srv.Session_Start_Epoch, 0) * srv.Rate  / 3600.0 ) as Amount
 FROM
    Session_Rate_View as srv
ORDER BY srv.Session_Stop_Epoch ASC, srv.Category_ID ASC, srv.Name ASC;

CREATE VIEW "Session_List_View" AS
SELECT
    s.Session_ID               as "Session_ID",
    s.Player_ID                as "Player_ID",
    IFNULL(p.NickName,p.Name)  as "Name",
    s.Start_Epoch              as "Start_Epoch",
    s.Stop_Epoch               as "Stop_Epoch",
    c.Name                     as "Category",
    r.Rate                     as "Hourly_Rate"

FROM
        Player as p
    INNER JOIN
        Player_Category as c
    ON p.Player_Category_ID = c.Player_Category_ID
    INNER JOIN
        Session as s
    ON
        p.Player_ID = s.Player_ID
    INNER JOIN
        Rate as r
    ON
        c.Hourly_Rate_ID == r.Rate_ID
ORDER BY s.Start_Epoch ASC,
         c.Player_Category_ID ASC,
         IFNULL(p.NickName,p.Name) ASC;

CREATE VIEW "Session_Panel_View" AS SELECT
    slv.Session_ID          as Session_ID,
    slv.Player_ID           as Player_ID,
    slv.Name                as Name,
    slv.Start_Epoch         as StartEpoch,
    slv.Stop_Epoch          as Stop_Epoch,
    sav.Duration_In_Seconds as Duration_In_Seconds,
    sav.Amount              as Amount,
    pbv.Balance             as Balance
FROM Session_List_View as slv
JOIN Session_Amount_View as sav
JOIN Player_Balance_View as pbv
WHERE slv.Session_ID == sav.Session_ID
AND slv.Player_ID == pbv.Player_ID;


CREATE VIEW "Session_Rate_View" AS
SELECT
 s.Session_ID,
 s.Player_ID,
 s.Start_Epoch as Session_Start_Epoch,
 s.Stop_Epoch as Session_Stop_Epoch,
 IFNULL(s.Stop_Epoch, unixepoch('now')) as Effective_Session_Stop_Epoch,
 IFNULL(p.NickName,p.Name) as Name,
 pc.Name as Category,
 pc.Player_Category_ID as Category_ID,
 pc.Start as Rate_Start_Epoch,
 pc.Stop as Rate_Stop_Epoch,
 pc.Rate as Rate,
 pc.Description as Rate_Description
FROM Session as s, Player as p, Player_Category_Rate_Interval_View as pc
WHERE s.Player_ID == p.Player_ID AND p.Player_Category_ID == pc.Player_Category_ID;

COMMIT;
