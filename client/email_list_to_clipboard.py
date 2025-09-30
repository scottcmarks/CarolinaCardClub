#!/usr/bin/env python3
import sqlite3
import pyperclip

con = sqlite3.connect("CarolinaCardClub.db")

res = con.cursor().execute("SELECT * from Player;")

row = res.fetchone()
email_addresses=''
n_email_addresses=0
while row is not None:
    (ID, Played_Super_Bowl, Name, Email_address, Phone_number, Other_phone_number_1, Other_phone_number_2, Other_phone_number_3, Player_Category_ID, NickName, Flag) = row
    if Phone_number != '***MISSING***' and Flag is None: 
        email_addresses+=( Name + " <" + Email_address + ">\n" )
        n_email_addresses += 1
    row= res.fetchone()

con.close()

pyperclip.copy(email_addresses)
print("Copied " + str(n_email_addresses) + " email addresses to clipboard.")

