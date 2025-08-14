BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS "Payment" (
	"Payment_Id"	INTEGER NOT NULL UNIQUE,
	"Player_Id"	INTEGER NOT NULL DEFAULT 1,
	"Amount"	NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
	"Epoch"	INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("Payment_Id" AUTOINCREMENT),
	FOREIGN KEY("Player_Id") REFERENCES "Player"("Player_Id")
);
CREATE TABLE IF NOT EXISTS "Player" (
	"Player_Id"	INTEGER NOT NULL UNIQUE,
	"Played_Super_Bowl"	INTEGER NOT NULL DEFAULT 0,
	"Name"	TEXT NOT NULL,
	"Email_address"	TEXT,
	"Phone_number"	TEXT,
	"Other_phone_number_1"	TEXT,
	"Other_phone_number_2"	TEXT,
	"Other_phone_number_3"	TEXT,
	"Player_Category_Id"	INTEGER,
	"NickName"	TEXT,
	"Flag"	TEXT,
	PRIMARY KEY("Player_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Player_Category" (
	"Player_Category_Id"	INTEGER NOT NULL UNIQUE,
	"Name"	TEXT NOT NULL,
	"Rate_Interval_Id"	INTEGER NOT NULL DEFAULT 3,
	"Hourly_Rate_Id"	INTEGER,
	PRIMARY KEY("Player_Category_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Player_Info" (
	"Player_Id"	INTEGER,
	"Name"	TEXT
);
CREATE TABLE IF NOT EXISTS "Rate" (
	"Rate_Id"	INTEGER NOT NULL UNIQUE,
	"Rate"	INTEGER(10, 2) NOT NULL DEFAULT 0.00,
	"Description"	TEXT,
	PRIMARY KEY("Rate_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Rate_Interval" (
	"Rate_Interval_Id"	INTEGER NOT NULL UNIQUE,
	"Start"	TEXT NOT NULL,
	"Stop"	TEXT NOT NULL,
	"Rate_Id"	INTEGER NOT NULL,
	"Start_Epoch"	INTEGER NOT NULL DEFAULT 0,
	"Stop_Epoch"	INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("Rate_Interval_Id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "Session" (
	"Session_Id"	INTEGER NOT NULL UNIQUE,
	"Player_Id"	INTEGER NOT NULL,
	"Start_Epoch"	INTEGER NOT NULL DEFAULT 0,
	"Stop_Epoch"	INTEGER,
	PRIMARY KEY("Session_Id" AUTOINCREMENT),
	FOREIGN KEY("Player_Id") REFERENCES "Player"
);

INSERT INTO "Payment" VALUES (14,407,6,1754441100);
INSERT INTO "Payment" VALUES (16,187,7,1754441280);
INSERT INTO "Payment" VALUES (17,188,14,1754446320);
INSERT INTO "Payment" VALUES (18,30,15,1754447160);
INSERT INTO "Payment" VALUES (19,410,10,1754448600);
INSERT INTO "Payment" VALUES (20,178,17,1754448780);
INSERT INTO "Payment" VALUES (21,64,9,1754449380);
INSERT INTO "Payment" VALUES (22,45,18,1754449380);
INSERT INTO "Payment" VALUES (23,11,20,1754450700);
INSERT INTO "Payment" VALUES (24,269,22,1754454600);
INSERT INTO "Payment" VALUES (25,7,26,1754455560);
INSERT INTO "Payment" VALUES (26,9,26,1754455560);
INSERT INTO "Payment" VALUES (27,177,26,1754455560);
INSERT INTO "Payment" VALUES (28,190,26,1754455560);
INSERT INTO "Payment" VALUES (29,44,26,1754455560);
INSERT INTO "Player" VALUES (1,1,'Scott Marks','scott.c.marks@gmail.com','919-969-1636',NULL,NULL,NULL,1,'Pony',NULL);
INSERT INTO "Player" VALUES (2,1,'Jon DeHart','jonnydeuce@gmail.com','919-408-4749',NULL,NULL,NULL,2,'Jonny Deuce',NULL);
INSERT INTO "Player" VALUES (3,3,'John Andrews','JohnFAndrewsIII@gmail.com','774-261-0423',NULL,NULL,NULL,3,'Boston John',NULL);
INSERT INTO "Player" VALUES (5,1,'Adam Wachter','acwachter@gmail.com','919-672-4697',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (6,1,'Ahmed Aziz','aaziz@nc.rr.com','919-360-3760',NULL,NULL,NULL,5,'Med',NULL);
INSERT INTO "Player" VALUES (7,1,'Alan Cohen','alancohen49@yahoo.com','919-602-4787',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (8,1,'Alan Tyndall','atvpizza@aol.com','919-612-4462',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (9,1,'Andrew Mousmoules','amousmoules@yahoo.com','919-370-0566',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (10,1,'Brevet Howe','brevethowe@gmail.com','919-475-5196',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (11,1,'Burton Levine','blevine@rti.org','919-949-3672',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (12,1,'Dennis Best','DennisBest32@hotmail.com','919-801-0270',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (13,0,'Gideon Young','gideonw.young@gmail.com','860-575-3706',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (14,0,'Jae Sun Rhee','jaesunrheeunc@gmail.com','919-616-0974',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (15,0,'Jeff Goldman','jeffcgoldman@gmail.com','919-909-5400',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (18,0,'Johnny May','johnny.may@nestrealty.com','818-731-1930',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (20,0,'Jon Mills','jonbrucemills@gmail.com','919-593-6365',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (21,0,'Jon Rand','jonrand@gmail.com','‭+1 (646) 382-0506‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (22,0,'Josh Walker','jmw1664@gmail.com','919-810-3441',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (23,0,'Joshua Collins','jcollin2000@gmail.com','919-225-2035',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (24,0,'Jovani Price','jovani.price@gmail.com','319-651-5760',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (25,1,'Ketan Mayer-Patel','kmp@cs.unc.edu','919-599-9435',NULL,NULL,NULL,4,NULL,NULL);
INSERT INTO "Player" VALUES (26,0,'Kevin Staring','Kevin.staring@gmail.com','919-360-9034',NULL,NULL,NULL,1,NULL,NULL);
INSERT INTO "Player" VALUES (27,0,'Kim Johnson','kimfjohnsonnc@gmail.com','919-260-7391',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (28,1,'Kiya Sabet','kdsabet@gmail.com','813-995-3467','631-576-9735',NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (29,0,'Matt Baird','Mattb.trg@yahoo.com','919-428-5941',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (30,0,'Mike Taylor','mitaylor@primeres.com','919-608-7034',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (31,1,'Pete Turner','Turnercottages@gmail.com','919-357-2773',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (32,0,'Peter Priest','phpriest7399@gmail.com','919-923-4230',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (33,1,'Phil DePinto','foodwithphil@gmail.com','919-696-1200',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (34,1,'Ray Martin','rayjmartin2@gmail.com','919-368-0824',NULL,NULL,NULL,5,'Mummy',NULL);
INSERT INTO "Player" VALUES (35,1,'Richard Lee','richardhlee56@gmail.com','919-819-8027',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (36,0,'Ron Absher','ron.absher@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (37,0,'Shannon Crane','mshannonc@aol.com','919-923-6466',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (39,1,'Taff Zicklefuse','tjz123@gmail.com','919-272-5002',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (40,0,'TheDeezer1','sdees@live.com','919-500-3043',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (41,0,'Thomas McDonnell','Thomas.mcdonnell7700@gmail.com','919-357-6604',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (42,0,'Todd Grantham','tgwrestle@gmail.com','919-260-1618',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (43,1,'Todd Owens','equipro@bellsouth.net','919-971-4704',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (44,0,'John Hudson','wakef25@aol.com','‭+1 (919) 624-1200‬','‭(919) 929-0060‬',NULL,NULL,5,'Wake Forest John',NULL);
INSERT INTO "Player" VALUES (45,0,'Walt Bassett','waltbassett@hotmail.com','203-859-0360',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (46,0,'Yash Shah','yashshah2001@outlook.com','704-942-5740',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (47,0,'Zach Sloane','zsloane@nc.rr.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (48,0,'Aaron Giachett','agiachett@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (49,0,'Adam Green','AdamHGreen@gmail.com','646-220-0405',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (50,0,'Ben Cox','ncbencox@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (51,0,'Bill DeArmey','bill.dearmey@gmail.com','919-888-3081',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (52,0,'Bobby Semler','semlerbobby@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (53,0,'Brad Connor','bradjconnor@hotmail.com','919-605-5902',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (54,0,'Brett Caramalis','caramalisbrett@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (55,0,'Bruce Gitter','bdgitter@aol.com','317-946-3926',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (56,1,'Chad Shooter','chadofedit@yahoo.com','919-818-6968','984-269-8838','323-833-9094','919-606-8420',5,NULL,NULL);
INSERT INTO "Player" VALUES (57,0,'Chad Adams','Ca4u@hotmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (59,0,'Chad Truax','chadtruax1@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (60,0,'Chris Brown','cbrown7584@gmail.com','919-932-7584',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (61,0,'Chris Combs','chrisdcombs@yahoo.com','832-545-3944',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (62,0,'Chris DePiano','Cdeeps318@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (63,0,'Chris Honoré','cfhonore@gmail.com','919-457-2778',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (64,0,'Chris Marthinson','mrthnsn2@gmail.com','‭+1 (919) 819-9980‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (65,0,'Chris Smith','chsmith13@outlook.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (66,0,'Christine Wilson','hipaachick@yahoo.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (67,0,'Chuck','chucktheman_2000@yahoo.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (68,0,'Corey Reid','corey_reid@hotmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (70,0,'Daniel Feinberg','dfeinber@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (71,0,'Daniel McCoy','Referee_Daniel_Mccoy@yahoo.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (72,0,'Darrel Moser','darrel.moser1@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (73,0,'Darryl Robinson','darrylr35@gmail.com','919-450-5014',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (74,0,'Dave Browning','dbrownin@yahoo.com','919-345-0454',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (75,0,'Dave Wall','dhwall@outlook.com','919-673-3303',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (76,0,'David DeHart','dbdehart@aol.com','919-247-1214',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (77,0,'David J Beery','davidjbeery@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (78,0,'David Wyatt','Wyatt.David@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (79,0,'Derek Gottlich','123gottlich@gmail.com','‭+1 (919) 805-4952‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (80,0,'Derek Wildman','Derek.Wildman@gmail.com','‭+1 (919) 360-0488‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (81,1,'Don Levine','dlevi363@gmail.com','‭(919) 616-7513‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (82,0,'Dyquise','Dyquise@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (83,0,'Ed Denault','edwarddenault@outlook.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (85,1,'Eric Brown','chan_barber@yahoo.com','‭+1 (919) 619-7483‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (86,0,'Erik Lentine','Elentine_2000@yahoo.com','‭(732) 685-9868‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (87,0,'Eric Wilson','eric.wilson@webbasix.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (88,0,'Gary Colen','garycolen@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (89,0,'Gautam Khandelwal','gkhandel@hotmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (90,0,'George Kuchenreuther','gkuchenreuther@myeyedr.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (91,0,'Greg Boone','boonegb@gmail.com','919-260-4970',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (92,1,'Hai Le','haile_strata@yahoo.com','919-500-9255',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (93,0,'Harold Bowers','hjbowers11@gmail.com','‭+1 (919) 923-7723‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (94,0,'Heather Dennis','hrd244@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (95,0,'Howard Wizwer','Howardwizwer@gmail.com','‭+1 (919) 308-4182‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (96,0,'James Johnson','jamesmtcarmel@gmail.com','‭+1 (919) 667-3267‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (97,0,'Jan Atkinson','janatkinson.law@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (98,0,'Jason Douglas','jason@jasondouglasrealty.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (99,0,'Jason Tant','jaybear500@gmail.com','919-945-6852',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (100,0,'Jay Hauser','ArizonaJay@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (101,0,'Jeff Baldino','plumrunner@gmail.com','919-932-0148',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (102,0,'Jeff Craver','jeffcraver1@att.net','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (103,1,'Jeff Gambrel','jeff.gambrel@gmail.com','919-889-4861',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (104,0,'Jeff Yiannaki','Jyiannaki@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (105,0,'Jeremy Cloud','JCloud@alliancemocvd.com','678-447-4264',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (106,0,'Jim Cole','james.cole@duke.edu','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (107,0,'Joe Marchand','jrmarchand0312@gmail.com','‭+1 (828) 244-8921‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (108,0,'Joe Snyder','jeswcu@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (109,0,'John Jessem','Johnjessem@msn.com','‭+1 (919) 624-1200‬','‭(919) 929-0060‬',NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (110,1,'John Rhoades','rhoades@cs.unc.edu','919-451-3399',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (111,0,'Johnny Wehmann','jwehmann@gmail.com','919-259-3618',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (112,0,'Keshav K. Srinivasan','keshav.k.srinivasan@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (113,0,'Ketan Lad','ketanblad@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (114,0,'Kris','Topher8644@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (115,0,'Kurt Pearson','kepearson@triad.rr.com','336-214-3427',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (116,0,'Kyle Heath','kyle.library@gmail.com','‭(919) 801-8467‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (117,0,'Larry Kall','kalllarry@gmail.com','919-345-7135',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (118,0,'Leon Copeland','leonhcopeland@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (119,0,'Marc Casale','marc.casale@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (120,0,'Marco Schletz','marco.schletz@gmail.com','919-928-7095',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (121,0,'Mark Addison','maddison36@gmail.com','919-949-3451',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (122,0,'Mark Mdme','mark.mdme@juno.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (123,0,'Martin Stevens','martintstevens97@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (124,0,'Massoud Monazah','mmonazah@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (125,0,'Matt Bello','mbellous@yahoo.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (126,0,'Matt Buffington','tmbuffington@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (127,0,'Matt Kerekes','Mrkerekes15@gmail.com','919-279-3260',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (128,0,'Matt Malone','matthew.james.malone@gmail.com','‭(214) 263-7780‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (129,0,'Matt Pusateri','mattdc@gmail.com','202-445-3068',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (130,0,'Mehul Shah','Amehul99@yahoo.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (131,0,'Michael Blake','mtblake000@yahoo.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (132,0,'Michael Klein','mklein1977@gmail.com','917-825-2634',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (133,0,'Michael Lemanski','Lemanski@newsouthventures.com','919-824-0472',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (134,0,'Michael Peters','michael00peters@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (135,0,'Michael Pierce','map24pma@yahoo.com','919-265-7950',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (136,0,'Michael Pritchard','michaelpritchard333@gmail.com','724-831-0103',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (137,0,'Michael Timmons','michael.timmons@protonmail.com','919-491-3325',NULL,NULL,NULL,5,NULL,'Self-banned');
INSERT INTO "Player" VALUES (138,0,'Mike Jones','mikelj80@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (139,0,'Mike Rice','mrice@paraclerealty.com','919-818-1841',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (140,0,'Nathan Huening','nathan.huening@gmail.com','919-593-6724',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (141,0,'Noah McEachern','noahmce@outlook.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (142,0,'Pat Spampinato','spampinp@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (143,0,'Pat Wray','Pwray1969@gmail.com','919-604-9486',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (144,0,'Paul Banza','pbanza5@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (145,0,'Paul O''Neil','paulmoneil35@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (146,1,'Pete Makowenskyj','Murg40@hotmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (147,0,'Rajeev Rajendran','rajeev.rajendran@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (148,0,'Rene Cossin','lesbleusismyteam@gmail.com','919-452-2862',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (149,0,'Rich Fountain','rfountain1011@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (150,0,'Rich Paravella','rparavella@gmail.com','‭+1 (919) 219-4745‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (151,0,'Rob Wainwright','rmw8478@yahoo.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (152,0,'Robert Doring','rdoring47@yahoo.com','919-610-8338',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (153,0,'Robert Girardin','Rob.girardin@gmail.com','919-264-8332',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (154,0,'Roy Twiddle','royunc@aol.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (155,0,'Russell Schnell','rdschnell@bloomer.net','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (156,0,'Ryan Shaughnessy','rjshaughnessy@aol.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (157,0,'Sahith Reddy Desham','sahithreddydesham@gmail.com','‭+1 (703) 371-1992‬',NULL,NULL,NULL,5,'Sunny',NULL);
INSERT INTO "Player" VALUES (158,0,'Sam Shamseldin','sam@catatac.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (159,1,'Scott Iglehart','Trahelgi@aol.com','‭(954) 471-7907‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (160,0,'Shane Port','shanemport@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (161,0,'Sharod Baldwin','S.baldwin496.bb@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (162,0,'Steve Monroe','monroe@us.ibm.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (163,0,'Tim Miller','BufBillsFan@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (164,0,'Tim Niles','timniles@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (165,0,'Tom Reynolds','tgreynolds8@live.com','919-649-8417',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (166,0,'Vik Kapoor','vkap@hotmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (167,0,'Vince Picciano','v524picciano@yahoo.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (168,0,'Weihan Chan','weiyan8@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (169,0,'Whit Brannon','wbrannon9@yahoo.com','919-667-6226',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (170,0,'Morris Weinberger','mweinber@email.unc.edu','919-724-9176',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (171,0,'Ted Avery','etavery2002@yahoo.com','919-597-0464',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (172,0,'Justin Anderson','jander1112@hotmail.com','919-308-7713',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (173,0,'Dameion Rutherfprd','dameionrn@aol.com','973-819-6212',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (174,0,'David Pass','d.pass.unc@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (176,0,'Beth Wood','bethwood@gwitax.com','919-880-5718',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (177,0,'Brad Williams','bradwilliamsnc@gmail.com','336-337-3800',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (178,0,'Misha Katrin','katrinmikhail@gmail.com','919-638-7865',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (179,0,'Steve Hand','trianglebni@yahoo.com','919-417-9400',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (180,0,'Trey Ball','tball73@gmail.com','919-946-4782',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (181,0,'Len Talarico','lentalarico@gmail.com','‭+1 (919) 452-6418‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (183,0,'Adam Behr','behr.adam00@gmail.com','919-503-0888',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (184,0,'Peter Robson','factor1783@gmail.com','919-389-4678',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (185,0,'Ben Pereklita','benpereklita@gmail.com','630-414-7020',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (186,0,'Bart Poynor','bartpoynor@gmail.com','919-235-7525',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (187,0,'Akhila Belur','akhila.belur@gmail.com','508-523-2854',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (188,0,'Phil Marino','Phil@damarinos.com','312-560-9878',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (189,0,'Chris Peck','jammerjoez@gmail.com','9195845639',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (190,0,'Ray Johnson','rayjohnson41@gmail.com','9196692596',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (191,0,'David Bass','dbass@nc.rr.com','919-247-7439',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (192,0,'Alex King','alexking5689@gmail.com','984-303-2242',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (193,0,'Les johns','les.d.johns@gmail.com','270-317-5046',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (194,0,'Noah Dail','nhd256@outlook.com','910-540-1194',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (195,0,'Brian Frasure','tbfrasure@aol.com','919-522-8883',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (212,0,'522585978','522585978@qq.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (213,0,'Lou Daless','L.daless96@gmail.com','‭+1 (407) 488-7866‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (232,0,'Barry Selman','barrykselman@icloud.com','‭(919) 824-8880‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (233,0,'Mayur','mayurananth@yahoo.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (234,0,'Michael Ventola','sccgolfproff@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (235,0,'Brent Arnold','brent@3aught.com','1 (919) 880-9154‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (240,0,'Ben Goroshnik','ben.goroshnik@gmail.com','‭+1 (917) 757-5577‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (241,0,'John Goebel','jgoebel@unc.edu','‭(828) 275-3363‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (242,0,'Joseph Ma','jma345@email.unc.edu','‭+1 (919) 816-7342‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (244,0,'Zach Mraz','zach@mraz.us','‭(919) 323-8503‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (245,0,'Zack Boone','zaboone17@gmail.com','‭+1 (919) 710-4713‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (246,0,'Hal Darby','varoadstter@yahoo.com','‭(919) 376-5388‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (247,0,'Joshua Stubbolo','Josh@familylegacync.com','919-794-1560',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (248,0,'Jason Hartford','jasonhartford25@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (249,0,'John Elam','sibe_world03@yahoo.com','‭(336) 269-2157‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (250,0,'Sydney Sarmiento','Sydney.Sarmiento@gmail.com','‭+1 (252) 751-7427‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (251,0,'Rod Williams','ranzino69@yahoo.com','‭+1 (919) 451-2976‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (265,0,'Terrence Jordan','jordan1@alumni.unc.edu','‭(516) 732-1805‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (269,0,'Chandrababu Konduru','chandra02.k@gmail.com','‭(919) 917-0015‬',NULL,NULL,NULL,5,'Chandra',NULL);
INSERT INTO "Player" VALUES (274,0,'Chad Gibson','cjgibso3@gmail.com','‭+1 (919) 210-4979‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (275,0,'Mark Shalda','mdshalda@gmail.com','650-930-6393‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (276,0,'Jay Sunde','jrsunde@yahoo.com','‭+1 (919) 260-1480‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (278,0,'James Zewe','Jameszewe@gmail.com','716-672-9017',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (279,0,'Adam Leigh','tempestdash@gmail.com','‭+1 (513) 967-4758‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (280,0,'Nick Mandikos','Nickmandikos@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (281,0,'Travis McCracken','travisrmccracken@gmail.com','‭(919) 360-2320‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (282,0,'Antoine Flippen','antoineflippen43@gmail.com','‭+1 (336) 684-5209‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (286,0,'Sai Kushan','Saikushal08@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (288,0,'Anton panov','chrisophylacks@gmail.com','984-270-4566',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (289,0,'Christian Dixon','Apexpirate@yahoo.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (308,0,'Craig Hill','chill123.ch@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (321,0,'Emma Raisel','emma.rasiel@duke.edu','***MISSING***',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (400,0,'Chad Randolph','chad@envisionpowered.com','***MISSING***',NULL,NULL,NULL,5,NULL,'Non-working email addresses');
INSERT INTO "Player" VALUES (401,0,'Quincy Amekuedi','qamekuedi@nc.rr.com','***MISSING***',NULL,NULL,NULL,5,NULL,'Non-working email addresses');
INSERT INTO "Player" VALUES (402,0,'Jason Weir-Smith','Jasonws8888@gmail.com','‭+1 (801) 638-7944‬',NULL,NULL,NULL,5,NULL,'Moved away');
INSERT INTO "Player" VALUES (403,0,'Bristow Church','Bristow.Church@gmail.com','1 (615) 580-5009‬',NULL,NULL,NULL,5,NULL,'Moved away');
INSERT INTO "Player" VALUES (404,0,'Sasha','reachalber@gmail.com','‭+1 (919) 433-6764‬',NULL,NULL,NULL,5,NULL,'Banned');
INSERT INTO "Player" VALUES (405,0,'Carly Newman','carly129newman@gmail.com','‭+1 (919) 599-3413‬',NULL,NULL,NULL,5,NULL,'Self-banned');
INSERT INTO "Player" VALUES (406,0,'Jeff Boynton','jboynton24@gmail.com','***MISSING***',NULL,NULL,NULL,5,NULL,'Self-banned');
INSERT INTO "Player" VALUES (407,0,'Clayton Howard','johnclaytonhoward1978@gmail.com','‭+1 (919) 214-1686‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (408,0,'Andy Connor','alcproperties01@gmail.com','‭+1 (336) 264-2617‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (409,0,'Eric Allen','eallen152@hotmail.com','‭+1 (484) 437-8470‬',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player" VALUES (410,0,'Curtis Best','curtis.best@gmail.com','+1 (919) 824-5905',NULL,NULL,NULL,5,NULL,NULL);
INSERT INTO "Player_Category" VALUES (1,'Founder',1,1);
INSERT INTO "Player_Category" VALUES (2,'Manager',1,1);
INSERT INTO "Player_Category" VALUES (3,'Assistant Manager',2,2);
INSERT INTO "Player_Category" VALUES (4,'Five Oaks Member',3,2);
INSERT INTO "Player_Category" VALUES (5,'Regular',3,3);
INSERT INTO "Player_Info" VALUES (1,'Scott Marks');
INSERT INTO "Player_Info" VALUES (2,'Jon DeHart');
INSERT INTO "Player_Info" VALUES (3,'John Andrews');
INSERT INTO "Player_Info" VALUES (5,'Adam Wachter');
INSERT INTO "Player_Info" VALUES (6,'Ahmed Aziz');
INSERT INTO "Player_Info" VALUES (7,'Alan Cohen');
INSERT INTO "Player_Info" VALUES (8,'Alan Tyndall');
INSERT INTO "Player_Info" VALUES (9,'Andrew Mousmoules');
INSERT INTO "Player_Info" VALUES (10,'Brevet Howe');
INSERT INTO "Player_Info" VALUES (11,'Burton Levine');
INSERT INTO "Player_Info" VALUES (12,'Dennis Best');
INSERT INTO "Player_Info" VALUES (13,'Gideon Young');
INSERT INTO "Player_Info" VALUES (14,'Jae Sun Rhee');
INSERT INTO "Player_Info" VALUES (15,'Jeff Goldman');
INSERT INTO "Player_Info" VALUES (18,'Johnny May');
INSERT INTO "Player_Info" VALUES (20,'Jon Mills');
INSERT INTO "Player_Info" VALUES (21,'Jon Rand');
INSERT INTO "Player_Info" VALUES (22,'Josh Walker');
INSERT INTO "Player_Info" VALUES (23,'Joshua Collins');
INSERT INTO "Player_Info" VALUES (24,'Jovani Price');
INSERT INTO "Player_Info" VALUES (25,'Ketan Mayer-Patel');
INSERT INTO "Player_Info" VALUES (26,'Kevin Staring');
INSERT INTO "Player_Info" VALUES (27,'Kim Johnson');
INSERT INTO "Player_Info" VALUES (28,'Kiya Sabet');
INSERT INTO "Player_Info" VALUES (29,'Matt Baird');
INSERT INTO "Player_Info" VALUES (30,'Mike Taylor');
INSERT INTO "Player_Info" VALUES (31,'Pete Turner');
INSERT INTO "Player_Info" VALUES (32,'Peter Priest');
INSERT INTO "Player_Info" VALUES (33,'Phil DePinto');
INSERT INTO "Player_Info" VALUES (34,'Ray Martin');
INSERT INTO "Player_Info" VALUES (35,'Richard Lee');
INSERT INTO "Player_Info" VALUES (36,'Ron Absher');
INSERT INTO "Player_Info" VALUES (37,'Shannon Crane');
INSERT INTO "Player_Info" VALUES (39,'Taff Zicklefuse');
INSERT INTO "Player_Info" VALUES (40,'TheDeezer1');
INSERT INTO "Player_Info" VALUES (41,'Thomas McDonnell');
INSERT INTO "Player_Info" VALUES (42,'Todd Grantham');
INSERT INTO "Player_Info" VALUES (43,'Todd Owens');
INSERT INTO "Player_Info" VALUES (44,'John Hudson');
INSERT INTO "Player_Info" VALUES (45,'Walt Bassett');
INSERT INTO "Player_Info" VALUES (46,'Yash Shah');
INSERT INTO "Player_Info" VALUES (47,'Zach Sloane');
INSERT INTO "Player_Info" VALUES (48,'Aaron Giachett');
INSERT INTO "Player_Info" VALUES (49,'Adam Green');
INSERT INTO "Player_Info" VALUES (50,'Ben Cox');
INSERT INTO "Player_Info" VALUES (51,'Bill DeArmey');
INSERT INTO "Player_Info" VALUES (52,'Bobby Semler');
INSERT INTO "Player_Info" VALUES (53,'Brad Connor');
INSERT INTO "Player_Info" VALUES (54,'Brett Caramalis');
INSERT INTO "Player_Info" VALUES (55,'Bruce Gitter');
INSERT INTO "Player_Info" VALUES (56,'Chad Shooter');
INSERT INTO "Player_Info" VALUES (57,'Chad Adams');
INSERT INTO "Player_Info" VALUES (59,'Chad Truax');
INSERT INTO "Player_Info" VALUES (60,'Chris Brown');
INSERT INTO "Player_Info" VALUES (61,'Chris Combs');
INSERT INTO "Player_Info" VALUES (62,'Chris DePiano');
INSERT INTO "Player_Info" VALUES (63,'Chris Honoré');
INSERT INTO "Player_Info" VALUES (64,'Chris Marthinson');
INSERT INTO "Player_Info" VALUES (65,'Chris Smith');
INSERT INTO "Player_Info" VALUES (66,'Christine Wilson');
INSERT INTO "Player_Info" VALUES (67,'Chuck');
INSERT INTO "Player_Info" VALUES (68,'Corey Reid');
INSERT INTO "Player_Info" VALUES (70,'Daniel Feinberg');
INSERT INTO "Player_Info" VALUES (71,'Daniel McCoy');
INSERT INTO "Player_Info" VALUES (72,'Darrel Moser');
INSERT INTO "Player_Info" VALUES (73,'Darryl Robinson');
INSERT INTO "Player_Info" VALUES (74,'Dave Browning');
INSERT INTO "Player_Info" VALUES (75,'Dave Wall');
INSERT INTO "Player_Info" VALUES (76,'David DeHart');
INSERT INTO "Player_Info" VALUES (77,'David J Beery');
INSERT INTO "Player_Info" VALUES (78,'David Wyatt');
INSERT INTO "Player_Info" VALUES (79,'Derek Gottlich');
INSERT INTO "Player_Info" VALUES (80,'Derek Wildman');
INSERT INTO "Player_Info" VALUES (81,'Don Levine');
INSERT INTO "Player_Info" VALUES (82,'Dyquise');
INSERT INTO "Player_Info" VALUES (83,'Ed Denault');
INSERT INTO "Player_Info" VALUES (85,'Eric Brown');
INSERT INTO "Player_Info" VALUES (86,'Erik Lentine');
INSERT INTO "Player_Info" VALUES (87,'Eric Wilson');
INSERT INTO "Player_Info" VALUES (88,'Gary Colen');
INSERT INTO "Player_Info" VALUES (89,'Gautam Khandelwal');
INSERT INTO "Player_Info" VALUES (90,'George Kuchenreuther');
INSERT INTO "Player_Info" VALUES (91,'Greg Boone');
INSERT INTO "Player_Info" VALUES (92,'Hai Le');
INSERT INTO "Player_Info" VALUES (93,'Harold Bowers');
INSERT INTO "Player_Info" VALUES (94,'Heather Dennis');
INSERT INTO "Player_Info" VALUES (95,'Howard Wizwer');
INSERT INTO "Player_Info" VALUES (96,'James Johnson');
INSERT INTO "Player_Info" VALUES (97,'Jan Atkinson');
INSERT INTO "Player_Info" VALUES (98,'Jason Douglas');
INSERT INTO "Player_Info" VALUES (99,'Jason Tant');
INSERT INTO "Player_Info" VALUES (100,'Jay Hauser');
INSERT INTO "Player_Info" VALUES (101,'Jeff Baldino');
INSERT INTO "Player_Info" VALUES (102,'Jeff Craver');
INSERT INTO "Player_Info" VALUES (103,'Jeff Gambrel');
INSERT INTO "Player_Info" VALUES (104,'Jeff Yiannaki');
INSERT INTO "Player_Info" VALUES (105,'Jeremy Cloud');
INSERT INTO "Player_Info" VALUES (106,'Jim Cole');
INSERT INTO "Player_Info" VALUES (107,'Joe Marchand');
INSERT INTO "Player_Info" VALUES (108,'Joe Snyder');
INSERT INTO "Player_Info" VALUES (109,'John Jessem');
INSERT INTO "Player_Info" VALUES (110,'John Rhoades');
INSERT INTO "Player_Info" VALUES (111,'Johnny Wehmann');
INSERT INTO "Player_Info" VALUES (112,'Keshav K. Srinivasan');
INSERT INTO "Player_Info" VALUES (113,'Ketan Lad');
INSERT INTO "Player_Info" VALUES (114,'Kris');
INSERT INTO "Player_Info" VALUES (115,'Kurt Pearson');
INSERT INTO "Player_Info" VALUES (116,'Kyle Heath');
INSERT INTO "Player_Info" VALUES (117,'Larry Kall');
INSERT INTO "Player_Info" VALUES (118,'Leon Copeland');
INSERT INTO "Player_Info" VALUES (119,'Marc Casale');
INSERT INTO "Player_Info" VALUES (120,'Marco Schletz');
INSERT INTO "Player_Info" VALUES (121,'Mark Addison');
INSERT INTO "Player_Info" VALUES (122,'Mark Mdme');
INSERT INTO "Player_Info" VALUES (123,'Martin Stevens');
INSERT INTO "Player_Info" VALUES (124,'Massoud Monazah');
INSERT INTO "Player_Info" VALUES (125,'Matt Bello');
INSERT INTO "Player_Info" VALUES (126,'Matt Buffington');
INSERT INTO "Player_Info" VALUES (127,'Matt Kerekes');
INSERT INTO "Player_Info" VALUES (128,'Matt Malone');
INSERT INTO "Player_Info" VALUES (129,'Matt Pusateri');
INSERT INTO "Player_Info" VALUES (130,'Mehul Shah');
INSERT INTO "Player_Info" VALUES (131,'Michael Blake');
INSERT INTO "Player_Info" VALUES (132,'Michael Klein');
INSERT INTO "Player_Info" VALUES (133,'Michael Lemanski');
INSERT INTO "Player_Info" VALUES (134,'Michael Peters');
INSERT INTO "Player_Info" VALUES (135,'Michael Pierce');
INSERT INTO "Player_Info" VALUES (136,'Michael Pritchard');
INSERT INTO "Player_Info" VALUES (137,'Michael Timmons');
INSERT INTO "Player_Info" VALUES (138,'Mike Jones');
INSERT INTO "Player_Info" VALUES (139,'Mike Rice');
INSERT INTO "Player_Info" VALUES (140,'Nathan Huening');
INSERT INTO "Player_Info" VALUES (141,'Noah McEachern');
INSERT INTO "Player_Info" VALUES (142,'Pat Spampinato');
INSERT INTO "Player_Info" VALUES (143,'Pat Wray');
INSERT INTO "Player_Info" VALUES (144,'Paul Banza');
INSERT INTO "Player_Info" VALUES (145,'Paul O''Neil');
INSERT INTO "Player_Info" VALUES (146,'Pete Makowenskyj');
INSERT INTO "Player_Info" VALUES (147,'Rajeev Rajendran');
INSERT INTO "Player_Info" VALUES (148,'Rene Cossin');
INSERT INTO "Player_Info" VALUES (149,'Rich Fountain');
INSERT INTO "Player_Info" VALUES (150,'Rich Paravella');
INSERT INTO "Player_Info" VALUES (151,'Rob Wainwright');
INSERT INTO "Player_Info" VALUES (152,'Robert Doring');
INSERT INTO "Player_Info" VALUES (153,'Robert Girardin');
INSERT INTO "Player_Info" VALUES (154,'Roy Twiddle');
INSERT INTO "Player_Info" VALUES (155,'Russell Schnell');
INSERT INTO "Player_Info" VALUES (156,'Ryan Shaughnessy');
INSERT INTO "Player_Info" VALUES (157,'Sahith Reddy Desham');
INSERT INTO "Player_Info" VALUES (158,'Sam Shamseldin');
INSERT INTO "Player_Info" VALUES (159,'Scott Iglehart');
INSERT INTO "Player_Info" VALUES (160,'Shane Port');
INSERT INTO "Player_Info" VALUES (161,'Sharod Baldwin');
INSERT INTO "Player_Info" VALUES (162,'Steve Monroe');
INSERT INTO "Player_Info" VALUES (163,'Tim Miller');
INSERT INTO "Player_Info" VALUES (164,'Tim Niles');
INSERT INTO "Player_Info" VALUES (165,'Tom Reynolds');
INSERT INTO "Player_Info" VALUES (166,'Vik Kapoor');
INSERT INTO "Player_Info" VALUES (167,'Vince Picciano');
INSERT INTO "Player_Info" VALUES (168,'Weihan Chan');
INSERT INTO "Player_Info" VALUES (169,'Whit Brannon');
INSERT INTO "Player_Info" VALUES (170,'Morris Weinberger');
INSERT INTO "Player_Info" VALUES (171,'Ted Avery');
INSERT INTO "Player_Info" VALUES (172,'Justin Anderson');
INSERT INTO "Player_Info" VALUES (173,'Dameion Rutherfprd');
INSERT INTO "Player_Info" VALUES (174,'David Pass');
INSERT INTO "Player_Info" VALUES (176,'Beth Wood');
INSERT INTO "Player_Info" VALUES (177,'Brad Williams');
INSERT INTO "Player_Info" VALUES (178,'Misha Katrin');
INSERT INTO "Player_Info" VALUES (179,'Steve Hand');
INSERT INTO "Player_Info" VALUES (180,'Trey Ball');
INSERT INTO "Player_Info" VALUES (181,'Len Talarico');
INSERT INTO "Player_Info" VALUES (183,'Adam Behr');
INSERT INTO "Player_Info" VALUES (184,'Peter Robson');
INSERT INTO "Player_Info" VALUES (185,'Ben Pereklita');
INSERT INTO "Player_Info" VALUES (186,'Bart Poynor');
INSERT INTO "Player_Info" VALUES (187,'Akhila Belur');
INSERT INTO "Player_Info" VALUES (188,'Phil Marino');
INSERT INTO "Player_Info" VALUES (189,'Chris');
INSERT INTO "Player_Info" VALUES (190,'Ray Johnson');
INSERT INTO "Player_Info" VALUES (191,'David Bass');
INSERT INTO "Player_Info" VALUES (192,'Alex King');
INSERT INTO "Player_Info" VALUES (193,'Les johns');
INSERT INTO "Player_Info" VALUES (194,'Noah Dail');
INSERT INTO "Player_Info" VALUES (195,'Brian Frasure');
INSERT INTO "Player_Info" VALUES (212,'522585978');
INSERT INTO "Player_Info" VALUES (213,'Lou Daless');
INSERT INTO "Player_Info" VALUES (232,'Barry Selman');
INSERT INTO "Player_Info" VALUES (233,'Mayur');
INSERT INTO "Player_Info" VALUES (234,'Michael Ventola');
INSERT INTO "Player_Info" VALUES (235,'Brent Arnold');
INSERT INTO "Player_Info" VALUES (240,'Ben Goroshnik');
INSERT INTO "Player_Info" VALUES (241,'John Goebel');
INSERT INTO "Player_Info" VALUES (242,'Joseph Ma');
INSERT INTO "Player_Info" VALUES (244,'Zach Mraz');
INSERT INTO "Player_Info" VALUES (245,'Zack Boone');
INSERT INTO "Player_Info" VALUES (246,'Hal Darby');
INSERT INTO "Player_Info" VALUES (247,'Joshua Stubbolo');
INSERT INTO "Player_Info" VALUES (248,'Jason Hartford');
INSERT INTO "Player_Info" VALUES (249,'John Elam');
INSERT INTO "Player_Info" VALUES (250,'Sydney Sarmiento');
INSERT INTO "Player_Info" VALUES (251,'Rod Williams');
INSERT INTO "Player_Info" VALUES (265,'Terrence Jordan');
INSERT INTO "Player_Info" VALUES (269,'Chandrababu Konduru');
INSERT INTO "Player_Info" VALUES (274,'Chad Gibson');
INSERT INTO "Player_Info" VALUES (275,'Mark Shalda');
INSERT INTO "Player_Info" VALUES (276,'Jay Sunde');
INSERT INTO "Player_Info" VALUES (278,'James Zewe');
INSERT INTO "Player_Info" VALUES (279,'Adam Leigh');
INSERT INTO "Player_Info" VALUES (280,'Nick Mandikos');
INSERT INTO "Player_Info" VALUES (281,'Travis McCracken');
INSERT INTO "Player_Info" VALUES (282,'Antoine Flippen');
INSERT INTO "Player_Info" VALUES (286,'Sai Kushan');
INSERT INTO "Player_Info" VALUES (288,'Anton panov');
INSERT INTO "Player_Info" VALUES (289,'Christian Dixon');
INSERT INTO "Player_Info" VALUES (308,'Craig Hill');
INSERT INTO "Player_Info" VALUES (321,'Emma Raisel');
INSERT INTO "Player_Info" VALUES (400,'Chad Randolph');
INSERT INTO "Player_Info" VALUES (401,'Quincy Amekuedi');
INSERT INTO "Player_Info" VALUES (402,'Jason Weir-Smith');
INSERT INTO "Player_Info" VALUES (403,'Bristow Church');
INSERT INTO "Player_Info" VALUES (404,'Sasha');
INSERT INTO "Player_Info" VALUES (405,'Carly Newman');
INSERT INTO "Player_Info" VALUES (406,'Jeff Boynton');
INSERT INTO "Player_Info" VALUES (407,'Clayton Howard');
INSERT INTO "Player_Info" VALUES (408,'Andy Connor');
INSERT INTO "Player_Info" VALUES (409,'Eric Allen');
INSERT INTO "Rate" VALUES (1,0,'Free');
INSERT INTO "Rate" VALUES (2,3,'Reduced');
INSERT INTO "Rate" VALUES (3,5,'Regular');
INSERT INTO "Rate_Interval" VALUES (1,'2025-01-01 00:00:00.000','2099-12-31 23:59:59.999',1,1735689600,4102444799);
INSERT INTO "Rate_Interval" VALUES (2,'2025-01-01 00:00:00.000','2099-12-31 23:59:59.999',2,1735689600,4102444799);
INSERT INTO "Rate_Interval" VALUES (3,'2025-01-01 00:00:00.000','2099-12-31 23:59:59.999',3,1735689600,4102444799);
INSERT INTO "Session" VALUES (74,1,1754436600,1754455560);
INSERT INTO "Session" VALUES (75,30,1754436600,1754447160);
INSERT INTO "Session" VALUES (76,11,1754436600,1754450700);
INSERT INTO "Session" VALUES (77,45,1754436600,1754449380);
INSERT INTO "Session" VALUES (78,188,1754436600,1754446320);
INSERT INTO "Session" VALUES (79,190,1754436600,1754455560);
INSERT INTO "Session" VALUES (80,44,1754436600,1754455560);
INSERT INTO "Session" VALUES (81,178,1754436600,1754448780);
INSERT INTO "Session" VALUES (82,177,1754436600,1754455560);
INSERT INTO "Session" VALUES (83,9,1754436600,1754455560);
INSERT INTO "Session" VALUES (84,187,1754436600,1754441280);
INSERT INTO "Session" VALUES (85,7,1754436600,1754455560);
INSERT INTO "Session" VALUES (86,407,1754436600,1754441100);
INSERT INTO "Session" VALUES (87,269,1754439060,1754454600);
INSERT INTO "Session" VALUES (88,2,1754439720,1754455500);
INSERT INTO "Session" VALUES (89,410,1754441160,1754448600);
INSERT INTO "Session" VALUES (91,64,1754442840,1754449380);
CREATE VIEW "Payment_Rate_Interval_Id_List" AS
SELECT
pmt.Player_Id as Player_Id,
IFNULL(p.NickName, p.Name) as Player_Name,
pmt.Epoch as Payment_Epoch, pmt.Amount,
c.Rate_Interval_Id as Rate_Interval_Id
FROM
Payment as pmt
JOIN
Player as p
JOIN
Player_Category as c
WHERE
pmt.Player_Id == p.Player_Id
AND
p.Player_Category_Id == c.Player_Category_Id;
CREATE VIEW "Payment_Rate_List" AS
SELECT
pmt.Player_Id as Player_Id,
pmt.Epoch as Payment_Epoch, pmt.Amount,
c.Rate_Interval_Id as Rate_Interval_Id,
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
WHERE
pmt.Player_Id == p.Player_Id
AND
p.Player_Category_Id == c.Player_Category_Id
AND c.Rate_Interval_Id == ri.Rate_Interval_Id AND(pmt.Epoch BETWEEN unixepoch(ri.Start)  AND  unixepoch(ri.Stop))
AND ri.Rate_Id == r.Rate_Id;
CREATE VIEW "Player_Balance" AS
SELECT p.Player_Id, p.Total_Payment - IFNULL(sa.Total_Amount,0.00) as Balance
FROM Player_Total_Payment as p
LEFT JOIN Player_Total_Session_Amount as sa ON p.Player_Id == sa.Player_Id;
CREATE VIEW "Player_Category_Rate_Interval_List" AS
SELECT cat.Player_Category_Id, cat.Name, ri.Start, ri.Stop, ri.Rate, ri.Description
FROM Player_Category as cat, Rate_Interval_List as ri
WHERE cat.Rate_Interval_Id == ri.Rate_Interval_Id;
CREATE VIEW "Player_Most_Recent_Session_Start_Epoch" AS
SELECT
s.Player_Id as Player_Id,
s.Session_Id as Session_Id,
MAX(s.Start_Epoch) as Most_Recent_Start_Epoch
FROM Session as s
GROUP BY s.Player_Id
ORDER BY s.Start_Epoch DESC;
CREATE VIEW "Player_Selection_List" AS
SELECT
  p.Player_Id,
  IFNULL(p.NickName, p.Name) as Name,
  IFNULL(b.Balance,0.00) as Balance
 FROM
   Player as p
  LEFT JOIN
  Player_Most_Recent_Session_Start_Epoch as s
  ON p.Player_Id == s.Player_Id
 LEFT JOIN
   Player_Balance as b
ON p.Player_Id == b.Player_Id
WHERE p.Phone_number is NOT NULL AND p.Phone_number != '***MISSING***' and p.Flag is  NULL
ORDER by s.Most_Recent_Start_Epoch DESC, p.Player_Category_Id ASC, Name ASC;
CREATE VIEW "Player_Total_Payment" AS
SELECT p.Player_Id, IFNULL(SUM(pmt.Amount),0) as Total_Payment
FROM  Player as p LEFT JOIN Payment as pmt ON p.Player_Id == pmt.Player_Id
GROUP BY p.Player_Id;
CREATE VIEW "Player_Total_Session_Amount" AS
SELECT
	a.Player_Id,
	a.Name,
	SUM(a.Amount) as Total_Amount
FROM
Session_Amount_List as a
GROUP BY a.Player_Id;
CREATE VIEW "Purchased_Seconds" AS
SELECT
pid.Player_Id, pid.Player_Name, strftime('%Y-%m-%d %I:%M %P', datetime(pid.Payment_Epoch, 'unixepoch')) as Purchase_Time , PRINTF('$%d',pid.Amount) as Amount,
PRINTF('$%0.02f/hr',  ri.Rate) as Rate, pid.Amount * 3600 / ri.Rate as Purchased_Secs
FROM
Payment_Rate_Interval_Id_List as pid
LEFT JOIN
Rate_Interval_List ri
ON pid.Rate_Interval_Id == ri.Rate_Interval_Id
ORDER BY Purchase_Time ASC;
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
	sr.Session_Id,
	sr.Session_Start_Epoch,
	sr.Session_Stop_Epoch,
    MAX(sr.Effective_Session_Stop_Epoch - sr.Session_Start_Epoch, 0) as Duration_In_Seconds,
	sr.Player_Id,
	sr.Name,
    sr.Category,
    sr.Rate,
    sr.Rate_Description,
   round(MAX(sr.Effective_Session_Stop_Epoch - sr.Session_Start_Epoch, 0) * sr.Rate  / 3600.0 ) as Amount
 FROM
    Session_Rate_List as sr
ORDER BY sr.Session_Stop_Epoch ASC, sr.Category_Id ASC, sr.Name ASC;
CREATE VIEW "Session_List" AS
SELECT
    s.Session_Id               as "Session_Id",
    s.Player_Id                as "Player_Id",
    IFNULL(p.NickName,p.Name)  as "Name",
    s.Start_Epoch              as "Start_Epoch",
    s.Stop_Epoch               as "Stop_Epoch",
    c.Name                     as "Category",
    r.Rate                     as "Hourly_Rate"

FROM
        Player as p
    INNER JOIN
        Player_Category as c
    ON p.Player_Category_Id = c.Player_Category_Id
    INNER JOIN
        Session as s
    ON
        p.Player_Id = s.Player_Id
    INNER JOIN
        Rate as r
    ON
        c.Hourly_Rate_Id == r.Rate_Id

ORDER BY CASE
            WHEN s.Stop_Epoch IS NULL THEN 0 -- Assign a low value to NULLs
            ELSE 1                          -- Assign a higher value to non-NULLs
         END,
         s.Start_Epoch ASC,
         c.Player_Category_Id ASC,
         IFNULL(p.NickName,p.Name) ASC;
CREATE VIEW "Session_Panel_List" AS
SELECT
    sl.Session_Id           as Session_Id,
    sl.Player_Id            as Player_Id,
    sl.Name                 as Name,
    sl.Start_Epoch          as StartEpoch,
    sl.Stop_Epoch           as Stop_Epoch,
	sal.Duration_In_Seconds as Duration_In_Seconds,
    sal.Amount              as Amount,
	pb.Balance              as Balance
FROM Session_List as sl
JOIN Session_Amount_List as sal
JOIN Player_Balance as pb
WHERE sl.Session_Id == sal.Session_Id
AND sl.Player_Id == pb.Player_Id
ORDER BY CASE WHEN sl.Stop_Epoch IS NULL THEN 0 ELSE 1 END;
CREATE VIEW "Session_Rate_List" AS
SELECT
 s.Session_Id,
 s.Player_Id,
 s.Start_Epoch as Session_Start_Epoch,
 s.Stop_Epoch as Session_Stop_Epoch,
IFNULL(s.Stop_Epoch, unixepoch('now')) as Effective_Session_Stop_Epoch,
IFNULL(p.NickName,p.Name) as Name,

pc.Name as Category,
pc.Player_Category_Id as Category_Id,
pc.Start as Rate_Start_Epoch,
pc.Stop as Rate_Stop_Epoch,
pc.Rate as Rate,
pc.Description as Rate_Description

 FROM Session as s, Player as p, Player_Category_Rate_Interval_List as pc
WHERE s.Player_Id == p.Player_Id AND p.Player_Category_Id == pc.Player_Category_Id;
COMMIT;
