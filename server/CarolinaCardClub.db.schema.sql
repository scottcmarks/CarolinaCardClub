BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS Category_Rate_Interval (
    Player_Category_Id INTEGER NOT NULL,
    Rate_Interval_Id INTEGER NOT NULL,
    PRIMARY KEY (Player_Category_Id, Rate_Interval_Id),
    FOREIGN KEY (Player_Category_Id) REFERENCES Player_Category(Player_Category_Id),
    FOREIGN KEY (Rate_Interval_Id) REFERENCES Rate_Interval(Rate_Interval_Id)
);
CREATE TABLE IF NOT EXISTS "Email_Address" (
    "EmailAddress_Id" INTEGER NOT NULL UNIQUE,
    "Address" TEXT NOT NULL UNIQUE,
    PRIMARY KEY("EmailAddress_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Payment" (
	"Payment_Id"	INTEGER NOT NULL UNIQUE,
	"Player_Id"	INTEGER NOT NULL DEFAULT 1,
	"Amount"	INTEGER NOT NULL DEFAULT 0,
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
	"Rate_Group_Id"	INTEGER NOT NULL DEFAULT 3, Prepay_Hours INTEGER DEFAULT 5,
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
    "Stop_Epoch"	INTEGER NOT NULL DEFAULT 0, Player_Category_Id INTEGER, Rate_Group_Id INTEGER,
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
    Prepay_Amount INTEGER DEFAULT 0 CHECK(Prepay_Amount >= 0), Hourly_Rate REAL DEFAULT 0.0,
    FOREIGN KEY(Player_Id) REFERENCES Player(Player_Id)
);
CREATE TABLE IF NOT EXISTS "Super_Bowl_Players" (
    "Player_Id" INTEGER NOT NULL UNIQUE,
    FOREIGN KEY("Player_Id") REFERENCES "Player"("Player_Id")
);
CREATE TABLE IF NOT EXISTS System_State (
    Id INTEGER PRIMARY KEY CHECK (Id = 1),
    Is_Club_Open INTEGER NOT NULL DEFAULT 0,
    Club_Start_Epoch INTEGER,
    Default_Session_Hour INTEGER NOT NULL DEFAULT 19,
    Default_Session_Minute INTEGER NOT NULL DEFAULT 30,
    Floor_Manager_Player_Id INTEGER,
    Floor_Manager_Table_Id INTEGER,
    Floor_Manager_Seat_Number INTEGER
, Current_Game_Epoch INTEGER, Clock_Offset_Seconds INTEGER DEFAULT 0);
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
CREATE VIEW "Payment_Rate_Interval_Id_List" AS 
SELECT 
  pmt.Player_Id as Player_Id, 
  IFNULL(p.NickName, p.Name) as Player_Name, 
  pmt.Epoch as Payment_Epoch, 
  pmt.Amount, 
  cri.Rate_Interval_Id as Rate_Interval_Id 
FROM Payment as pmt 
JOIN Player as p ON pmt.Player_Id = p.Player_Id
JOIN Player_Category as c ON p.Player_Category_Id = c.Player_Category_Id
JOIN Category_Rate_Interval as cri ON c.Player_Category_Id = cri.Player_Category_Id
JOIN Rate_Interval as ri ON cri.Rate_Interval_Id = ri.Rate_Interval_Id
WHERE pmt.Epoch >= ri.Start_Epoch 
  AND (pmt.Epoch <= ri.Stop_Epoch OR ri.Stop_Epoch IS NULL OR ri.Stop_Epoch = 0);
CREATE VIEW "Payment_Rate_List" AS 
SELECT 
  pmt.Player_Id as Player_Id, 
  pmt.Epoch as Payment_Epoch, 
  pmt.Amount, 
  cri.Rate_Interval_Id as Rate_Interval_Id, 
  r.Rate as Hourly_Rate, 
  r.Description as Rate_Description, 
  (pmt.Amount * 3600) / r.Rate as Purchased_Seconds, 
  CAST((pmt.Amount * 3600) / r.Rate / 3600 AS TEXT) || ':' || PRINTF('%02d', CAST(((pmt.Amount * 3600) / r.Rate % 3600) / 60 AS INTEGER)) AS formatted_time 
FROM Payment as pmt 
JOIN Player as p ON pmt.Player_Id = p.Player_Id
JOIN Player_Category as c ON p.Player_Category_Id = c.Player_Category_Id
JOIN Category_Rate_Interval cri ON c.Player_Category_Id = cri.Player_Category_Id
JOIN Rate_Interval ri ON cri.Rate_Interval_Id = ri.Rate_Interval_Id
JOIN Rate r ON ri.Rate_Id = r.Rate_Id
WHERE pmt.Epoch >= ri.Start_Epoch 
  AND (pmt.Epoch <= ri.Stop_Epoch OR ri.Stop_Epoch IS NULL OR ri.Stop_Epoch = 0);
CREATE VIEW "Player_Balance" AS 
SELECT p.Player_Id, p.Total_Payment - IFNULL(sa.Total_Amount,0) as Balance 
FROM Player_Total_Payment as p 
LEFT JOIN Player_Total_Session_Amount as sa ON p.Player_Id == sa.Player_Id;
CREATE VIEW "Player_Category_Rate_Interval_List" AS 
SELECT 
  cat.Player_Category_Id, 
  cat.Name, 
  ri.Start, 
  ri.Stop, 
  ri.Rate, 
  ri.Description 
FROM Player_Category as cat
JOIN Category_Rate_Interval as cri ON cat.Player_Category_Id = cri.Player_Category_Id
JOIN Rate_Interval_List as ri ON cri.Rate_Interval_Id = ri.Rate_Interval_Id;
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
    IFNULL(p.NickName, p.Name) AS Name,
    pb.Balance,
    r.Rate AS Hourly_Rate,
    cat.Prepay_Hours AS Prepay_Hours,
    CASE WHEN s.Session_Id IS NOT NULL THEN 1 ELSE 0 END AS Is_Active
FROM Player p
JOIN Player_Balance pb ON p.Player_Id = pb.Player_Id
JOIN Player_Category cat ON p.Player_Category_Id = cat.Player_Category_Id

-- THE MAGIC: Cross Join pulls in the single global state row so we can read the time
CROSS JOIN System_State ss 

LEFT JOIN Category_Rate_Interval cri ON cat.Player_Category_Id = cri.Player_Category_Id
LEFT JOIN Rate_Interval ri ON cri.Rate_Interval_Id = ri.Rate_Interval_Id 
    -- Filter the intervals based strictly on the Game Time!
    AND ss.Current_Game_Epoch >= ri.Start_Epoch 
    AND (ss.Current_Game_Epoch <= ri.Stop_Epoch OR ri.Stop_Epoch IS NULL OR ri.Stop_Epoch = 0)
LEFT JOIN Rate r ON ri.Rate_Id = r.Rate_Id

LEFT JOIN (SELECT Player_Id, MAX(Session_Id) AS Max_Session_Id FROM Session GROUP BY Player_Id) AS max_sessions ON p.Player_Id = max_sessions.Player_Id
LEFT JOIN Session s ON max_sessions.Max_Session_Id = s.Session_Id
GROUP BY p.Player_Id
ORDER BY 
    CASE 
        WHEN s.Start_Epoch IS NULL THEN 4
        WHEN s.Stop_Epoch IS NULL THEN 1
        -- 21 days = 1,814,400 seconds. This ensures list sorting respects Game Time!
        WHEN (ss.Current_Game_Epoch - 1814400) <= s.Stop_Epoch THEN 2
        ELSE 3
    END,
    IFNULL(p.NickName, p.Name);
CREATE VIEW "Player_Total_Payment" AS SELECT p.Player_Id, IFNULL(SUM(pmt.Amount),0) as Total_Payment FROM  Player as p LEFT JOIN Payment as pmt ON p.Player_Id == pmt.Player_Id GROUP BY p.Player_Id;
CREATE VIEW "Player_Total_Session_Amount" AS SELECT a.Player_Id, a.Name, SUM(a.Amount) as Total_Amount FROM Session_Amount_List as a GROUP BY a.Player_Id;
CREATE VIEW "Purchased_Seconds" AS SELECT pid.Player_Id, pid.Player_Name, strftime('%Y-%m-%d %I:%M %P', datetime(pid.Payment_Epoch, 'unixepoch')) as Purchase_Time , PRINTF('$%d',pid.Amount) as Amount, PRINTF('$%0.02f/hr',  ri.Rate) as Rate, pid.Amount * 3600 / ri.Rate as Purchased_Secs FROM Payment_Rate_Interval_Id_List as pid LEFT JOIN Rate_Interval_List ri ON pid.Rate_Interval_Id == ri.Rate_Interval_Id ORDER BY Purchase_Time ASC;
CREATE VIEW "Rate_Interval_List" AS
SELECT
    Rate_Interval.Rate_Interval_Id,
	strftime('%Y-%m-%d %I:%M %P', datetime(Rate_Interval.Start_Epoch, 'unixepoch', 'localtime')) as Start,
	strftime('%Y-%m-%d %I:%M %P', datetime(Rate_Interval.Stop_Epoch, 'unixepoch', 'localtime')) as Stop,
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
    sr.Player_Id, sr.Name, sr.Category, sr.Category_Id, sr.Rate, sr.Rate_Description, sr.Is_Prepaid, sr.Prepay_Amount,
    CASE
        WHEN sr.Is_Prepaid = 1 THEN sr.Prepay_Amount
        WHEN sr.Session_Stop_Epoch IS NULL THEN NULL
        ELSE CAST(round(MAX(sr.Session_Stop_Epoch - sr.Session_Start_Epoch, 0) * sr.Rate  / 3600.0 ) AS INTEGER)
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
    sal.Duration_In_Seconds, sal.Amount, pb.Balance, sal.Rate, sal.Category_Id
FROM Session_List as sl
JOIN Session_Amount_List as sal ON sl.Session_Id == sal.Session_Id
JOIN Player_Balance as pb ON sl.Player_Id == pb.Player_Id
ORDER BY CASE WHEN sl.Stop_Epoch IS NULL THEN 0 ELSE 1 END, sal.Category_Id, sl.Name, sl.Stop_Epoch DESC;
CREATE VIEW "Session_Rate_List" AS
SELECT
    s.Session_Id, s.Player_Id, s.Start_Epoch as Session_Start_Epoch, s.Stop_Epoch as Session_Stop_Epoch,
    IFNULL(p.NickName,p.Name) as Name, c.Name as Category, c.Player_Category_Id as Category_Id,
    0 as Rate_Start_Epoch, 0 as Rate_Stop_Epoch, s.Hourly_Rate as Rate, 'Locked Rate' as Rate_Description,
    s.Is_Prepaid, s.Prepay_Amount
FROM Session as s
JOIN Player as p ON s.Player_Id == p.Player_Id
JOIN Player_Category as c ON p.Player_Category_Id == c.Player_Category_Id;
COMMIT;
