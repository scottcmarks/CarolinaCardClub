#!/usr/bin/env python3
import sqlite3
con = sqlite3.connect("CarolinaCardClub.db")

res = con.cursor().execute("SELECT * from Player;")

row = res.fetchone()
while row is not None:
    (ID, Played_Super_Bowl, Name, Email_address, Phone_number, Other_phone_number_1, Other_phone_number_2, Other_phone_number_3, Prepaid_balance, Player_Category_ID, NickName, Flag) = row
    if Phone_number != '***MISSING***' and Flag is None: print( Name + " <" + Email_address + ">" )
    row= res.fetchone()

con.close()
