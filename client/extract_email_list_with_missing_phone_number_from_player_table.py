#!/usr/bin/env python3
import sqlite3
con = sqlite3.connect("CarolinaCardClub.db")

res = con.cursor().execute("SELECT * from Player WHERE Player.Phone_number LIKE '***MISSING***' ;")

row = res.fetchone()
while row is not None:
    (_Player_ID, _Played_Super_Bowl, Name, Email_address, _Phone_number, _Other_phone_number_1, _Other_phone_number_2, _Other_phone_number_3, _Player_Category_ID, _NickName, Flag) = row
    if Flag is None: print( Name.ljust(16) + "\t<" + Email_address + ">" )
    row= res.fetchone()

con.close()
