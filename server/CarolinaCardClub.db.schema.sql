BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS "Email_Address" (
    "EmailAddress_Id" INTEGER NOT NULL UNIQUE,
    "Address" TEXT NOT NULL UNIQUE,
    PRIMARY KEY("EmailAddress_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Payment" (
	"Payment_Id"	INTEGER NOT NULL UNIQUE,
	"Player_Id"	INTEGER NOT NULL DEFAULT 1,
	"Amount"	NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
	"Epoch"	INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("Payment_Id" AUTOINCREMENT),
	FOREIGN KEY("Player_Id") REFERENCES "Player"("Player_Id")
);
CREATE TABLE IF NOT EXISTS "Phone_Number" (
    "PhoneNumber_Id"    INTEGER NOT NULL UNIQUE,
    "Number"            TEXT NOT NULL UNIQUE,
    "IsWorking"         INTEGER NOT NULL DEFAULT 1,
    "CanSMS"            INTEGER,
    PRIMARY KEY("PhoneNumber_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Player" (
    Player_Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Name TEXT NOT NULL,
    Player_Category_Id INTEGER,
    NickName TEXT,
    Flag TEXT,
    Balance INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS "Player_Category" (
	"Player_Category_Id"	INTEGER NOT NULL UNIQUE,
	"Name"	TEXT NOT NULL,
	"Rate_Interval_Id"	INTEGER NOT NULL DEFAULT 3, Prepay_Hours INTEGER DEFAULT 5,
	PRIMARY KEY("Player_Category_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Player_Email" (
    "Player_Id" INTEGER NOT NULL,
    "EmailAddress_Id" INTEGER NOT NULL,
    FOREIGN KEY("Player_Id") REFERENCES "Player"("Player_Id"),
    FOREIGN KEY("EmailAddress_Id") REFERENCES "Email_Address"("EmailAddress_Id"),
    PRIMARY KEY("Player_Id", "EmailAddress_Id")
);
CREATE TABLE IF NOT EXISTS "Player_Info" (
	"Player_Id"	INTEGER,
	"Name"	TEXT
);
CREATE TABLE IF NOT EXISTS "Player_Phone" (
    "Player_Id" INTEGER NOT NULL,
    "PhoneNumber_Id" INTEGER NOT NULL,
    FOREIGN KEY("Player_Id") REFERENCES "Player"("Player_Id"),
    FOREIGN KEY("PhoneNumber_Id") REFERENCES "Phone_Number_old"("PhoneNumber_Id"),
    PRIMARY KEY("Player_Id", "PhoneNumber_Id")
);
CREATE TABLE IF NOT EXISTS "PokerTable" (
	"PokerTable_Id"	INTEGER NOT NULL UNIQUE,
	"Name"	TEXT NOT NULL UNIQUE,
	"Capacity"	INTEGER NOT NULL DEFAULT 10 CHECK(Capacity > 0 AND Capacity <= 20),
	"IsActive"	INTEGER NOT NULL DEFAULT 1,
	PRIMARY KEY("PokerTable_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Rate" (
	"Rate_Id"	INTEGER NOT NULL UNIQUE,
	"Rate"	INTEGER(10, 2) NOT NULL DEFAULT 0.00,
	"Description"	TEXT,
	PRIMARY KEY("Rate_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Rate_Interval" (
    "Rate_Interval_Id"	INTEGER NOT NULL UNIQUE,
    "Rate_Id"	INTEGER NOT NULL,
    "Start_Epoch"	INTEGER NOT NULL DEFAULT 0,
    "Stop_Epoch"	INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY("Rate_Interval_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Session" (
    Session_Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Player_Id INTEGER NOT NULL,
    Start_Epoch INTEGER NOT NULL DEFAULT 0,
    Stop_Epoch INTEGER, 
    PokerTable_Id INTEGER REFERENCES PokerTable(PokerTable_Id), 
    Seat_Number INTEGER CHECK(Seat_Number BETWEEN 1 AND 20), 
    Is_Prepaid INTEGER DEFAULT 0 CHECK(Is_Prepaid IN (0, 1)), 
    Prepay_Amount INTEGER DEFAULT 0 CHECK(Prepay_Amount >= 0),
    FOREIGN KEY(Player_Id) REFERENCES Player(Player_Id)
);
CREATE TABLE IF NOT EXISTS "Super_Bowl_Players" (
    "Player_Id" INTEGER NOT NULL UNIQUE,
    FOREIGN KEY("Player_Id") REFERENCES "Player"("Player_Id")
);
CREATE VIEW "Email_List" AS SELECT
    p.Name as Name,

    CASE
        WHEN COUNT(DISTINCT ea.Address) = 0 THEN '[]'
        ELSE json_group_array(DISTINCT ea.Address)
    END as EmailAddresses,

    CASE
        WHEN COUNT(DISTINCT pn.Number) = 0 THEN '[]'
        ELSE json_group_array(DISTINCT pn.Number)
    END as PhoneNumbers,
    MAX(sb.Player_Id IS NOT NULL) as Super_Bowl,
    p.Flag as Flag
FROM
    Player as p
LEFT JOIN
    Player_Email as pe ON pe.Player_Id = p.Player_Id
LEFT JOIN
    Email_Address as ea ON pe.EmailAddress_Id = ea.EmailAddress_Id
LEFT JOIN
    Player_Phone as pp ON pp.Player_Id = p.Player_Id
LEFT JOIN
    "Phone_Number" as pn ON pp.PhoneNumber_Id = pn.PhoneNumber_Id
LEFT JOIN
    Super_Bowl_Players as sb ON sb.Player_Id = p.Player_Id
GROUP BY
    p.Player_Id
ORDER BY
    p.Player_Id;
CREATE VIEW "Payment_Rate_Interval_Id_List" AS SELECT pmt.Player_Id as Player_Id, IFNULL(p.NickName, p.Name) as Player_Name, pmt.Epoch as Payment_Epoch, pmt.Amount, c.Rate_Interval_Id as Rate_Interval_Id FROM Payment as pmt JOIN Player as p JOIN Player_Category as c WHERE pmt.Player_Id == p.Player_Id AND p.Player_Category_Id == c.Player_Category_Id;
CREATE VIEW "Payment_Rate_List" AS SELECT pmt.Player_Id as Player_Id, pmt.Epoch as Payment_Epoch, pmt.Amount, c.Rate_Interval_Id as Rate_Interval_Id, r.Rate as Hourly_Rate, r.Description as Rate_Description, pmt.Amount*3600/r.Rate as Purchased_Seconds, CAST(pmt.Amount*3600/r.Rate / 3600 AS TEXT) || ':' || PRINTF('%02d', (pmt.Amount*3600/r.Rate % 3600) / 60) AS formatted_time FROM Payment as pmt JOIN Player as p JOIN Player_Category as c JOIN Rate_Interval as ri JOIN Rate as r WHERE pmt.Player_Id == p.Player_Id AND p.Player_Category_Id == c.Player_Category_Id AND c.Rate_Interval_Id == ri.Rate_Interval_Id AND pmt.Epoch BETWEEN ri.Start_Epoch AND ri.Stop_Epoch AND ri.Rate_Id == r.Rate_Id;
CREATE VIEW "Player_Balance" AS 
SELECT p.Player_Id, p.Total_Payment - IFNULL(sa.Total_Amount,0) as Balance 
FROM Player_Total_Payment as p 
LEFT JOIN Player_Total_Session_Amount as sa ON p.Player_Id == sa.Player_Id;
CREATE VIEW "Player_Category_Rate_Interval_List" AS SELECT cat.Player_Category_Id, cat.Name, ri.Start, ri.Stop, ri.Rate, ri.Description FROM Player_Category as cat, Rate_Interval_List as ri WHERE cat.Rate_Interval_Id == ri.Rate_Interval_Id;
CREATE VIEW "Player_Most_Recent_Session_Start_Epoch" AS
SELECT
s.Player_Id as Player_Id,
s.Session_Id as Session_Id,
MAX(s.Start_Epoch) as Most_Recent_Start_Epoch,
MAX(s.Start_Epoch)/(60*60*24*7) as Most_Recent_Start_Week
FROM Session as s
GROUP BY s.Player_Id
ORDER BY s.Start_Epoch DESC;
CREATE VIEW "Player_Most_Recent_Session_Stop_Epoch" AS
SELECT
s.Player_Id as Player_Id,
s.Session_Id as Session_Id,
CASE WHEN MAX(IFNULL(s.Stop_Epoch,99999999999))==99999999999 THEN NULL ELSE MAX(IFNULL(s.Stop_Epoch,99999999999)) END  as Most_Recent_Stop_Epoch
FROM Session as s
GROUP BY s.Player_Id
ORDER BY IFNULL(Most_Recent_Stop_Epoch,99999999999) DESC;
CREATE VIEW "Player_Selection_List" AS
SELECT 
    p.Player_Id,
    IFNULL(p.NickName, p.Name) as Name,
    pb.Balance,
    -- Get Rate from the Interval List (which you said has the 0)
    ri.Rate as Hourly_Rate,
    -- Get Prepay_Hours from the Category table directly
    cat.Prepay_Hours as Prepay_Hours,
    CASE WHEN s.Session_Id IS NOT NULL THEN 1 ELSE 0 END as Is_Active
FROM Player p
JOIN Player_Balance pb ON p.Player_Id = pb.Player_Id
JOIN Player_Category cat ON p.Player_Category_Id = cat.Player_Category_Id
JOIN Player_Category_Rate_Interval_List ri ON p.Player_Category_Id = ri.Player_Category_Id
LEFT JOIN Session s ON p.Player_Id = s.Player_Id AND s.Stop_Epoch IS NULL
ORDER BY p.Name;
CREATE VIEW "Player_Total_Payment" AS SELECT p.Player_Id, IFNULL(SUM(pmt.Amount),0) as Total_Payment FROM  Player as p LEFT JOIN Payment as pmt ON p.Player_Id == pmt.Player_Id GROUP BY p.Player_Id;
CREATE VIEW "Player_Total_Session_Amount" AS SELECT a.Player_Id, a.Name, SUM(a.Amount) as Total_Amount FROM Session_Amount_List as a GROUP BY a.Player_Id;
CREATE VIEW "Purchased_Seconds" AS SELECT pid.Player_Id, pid.Player_Name, strftime('%Y-%m-%d %I:%M %P', datetime(pid.Payment_Epoch, 'unixepoch')) as Purchase_Time , PRINTF('$%d',pid.Amount) as Amount, PRINTF('$%0.02f/hr',  ri.Rate) as Rate, pid.Amount * 3600 / ri.Rate as Purchased_Secs FROM Payment_Rate_Interval_Id_List as pid LEFT JOIN Rate_Interval_List ri ON pid.Rate_Interval_Id == ri.Rate_Interval_Id ORDER BY Purchase_Time ASC;
CREATE VIEW "Rate_Interval_List" AS
SELECT
    Rate_Interval.Rate_Interval_Id,
	strftime('%Y-%m-%d %I:%M %P', datetime(Rate_Interval.Start_Epoch, 'unixepoch')) as Start,
	strftime('%Y-%m-%d %I:%M %P', datetime(Rate_Interval.Stop_Epoch, 'unixepoch')) as Stop,
	Rate.Rate as Rate,
	Rate.Description
  FROM
    Rate_Interval
  LEFT JOIN
     Rate
WHERE
    Rate_Interval.Rate_Id == Rate.Rate_Id;
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
FROM Session_Rate_List as sr;
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
CREATE VIEW "Session_Rate_List" AS
SELECT
    s.Session_Id, s.Player_Id, s.Start_Epoch as Session_Start_Epoch, s.Stop_Epoch as Session_Stop_Epoch,
    IFNULL(p.NickName,p.Name) as Name, pc.Name as Category, pc.Player_Category_Id as Category_Id,
    pc.Start as Rate_Start_Epoch, pc.Stop as Rate_Stop_Epoch, pc.Rate as Rate, pc.Description as Rate_Description,
    s.Is_Prepaid, s.Prepay_Amount
FROM Session as s, Player as p, Player_Category_Rate_Interval_List as pc
WHERE s.Player_Id == p.Player_Id AND p.Player_Category_Id == pc.Player_Category_Id;
COMMIT;
