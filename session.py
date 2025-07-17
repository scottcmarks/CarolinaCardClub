#!/usr/bin/env python3
import tkinter as tk
from tkinter import messagebox, ttk
import tkinter.font as tkFont # Import the font module for custom fonts
import sqlite3
import datetime
import time
from enum import Enum
import locale

#Useful color chart at https://cs111.wellesley.edu/archive/cs111_fall14/public_html/labs/lab12/tkintercolor.html
carolina_blue_hex = "#4B9CD3"

class ClockResolution(Enum):
    SECONDS = 1000
    MINUTES = SECONDS * 60

digital_clock_resolution = ClockResolution.SECONDS

player_data_query = """
SELECT p.Player_ID,
       p.Played_Super_Bowl,
       IFNULL(p.NickName, p.Name),
       p.Name,
       p.Email_address,
       p.Phone_number,
       p.Other_phone_number_1,
       p.Other_phone_number_2,
       p.Other_phone_number_3,
       p.Flag,
       c.Name,
       c.Hourly_Rate
FROM Player as p
       INNER JOIN
     Player_Category as c
       WHERE p.Player_Category_ID = c.ID
"""


non_flagged_player_data_query = """
SELECT p.Player_ID,
       p.Played_Super_Bowl,
       IFNULL(p.NickName, p.Name),
       p.Name,
       p.Email_address,
       p.Phone_number,
       p.Other_phone_number_1,
       p.Other_phone_number_2,
       p.Other_phone_number_3,
       p.Flag,
       c.Name,
       c.Hourly_Rate
FROM Player as p
       INNER JOIN
     Player_Category as c
       WHERE p.Player_Category_ID = c.ID
         AND p.Flag IS NULL
"""

player_name_query = """
SELECT p.Player_ID,
       IFNULL(p.NickName, p.Name)
FROM Player as p
       INNER JOIN
     Player_Category as c
       WHERE p.Player_Category_ID = c.Player_Category_ID
         AND p.Flag IS NULL
"""



root = tk.Tk()


# Set the locale (example for US English)
locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')

def fetch_data_from_db(query):
    """Fetches data from an SQLite database."""
    conn = None
    try:
        conn = sqlite3.connect('CarolinaCardClub.db')
        cursor = conn.cursor()
        cursor.execute(query)
        data = cursor.fetchall()
        return data
    except sqlite3.Error as e:
        messagebox.showerror("Database Error", f"Error fetching data: {e}")
        return []
    finally:
        if conn:
            conn.close()

class InputPopup(tk.Toplevel):
    def __init__(self, parent, title, prompt, default=None):
        super().__init__(parent)
        self.title(title)
        self.grab_set()  # Make the popup modal

        self.user_input = None

        ttk.Label(self, text=prompt).pack(padx=10)
        self.entry = ttk.Entry(self)
        self.entry.pack(padx=10)
        self.entry.focus_set()  # Set focus to the entry field
        if default is not None:
            self.entry.insert(0,default)

        # Center the popup over the parent window (if available)
        if parent:
            parent.update_idletasks() # Ensure parent geometry is calculated
            x = parent.winfo_x() + (parent.winfo_width() // 2) - (self.winfo_width() // 2)
            y = parent.winfo_y() + (parent.winfo_height() // 2) - (self.winfo_height() // 2)
            self.geometry(f"+{x}+{y}")
            self.transient(parent)  # Keep popup on top of the parent window

        button_frame = ttk.Frame(self)
        button_frame.pack(pady=10) # Pack the frame in the popup

        # Create the buttons and pack them into the frame
        self.button1 = ttk.Button(button_frame, text="Cancel", command=self.on_cancel)
        self.button2 = ttk.Button(button_frame, text="OK",     command=self.on_ok, default='active')
        self.button1.pack(side=tk.LEFT, padx=5) # Place Button 1 to the left
        self.button2.pack(side=tk.LEFT, padx=5) # Place Button 2 to the left (next to Button 1)
         # Bind the spacebar event to the Toplevel window
        self.bind('<space>', self.on_spacebar_press)

    def on_cancel(self):
        self.user_input = None
        self.destroy()

    def on_ok(self):
        self.user_input = self.entry.get()
        self.destroy()

    def on_spacebar_press(self, event):
        self.button2.invoke()
        self.destroy()


def reset_clock(event):
    print("RESET CLOCK", event, digital_clock.resolution, digital_clock.digital_clock_time_format)
    digital_clock.update_time()



class DigitalClock(tk.Label):

    def __init__(self, resolution, bgcolor):
        super().__init__(root,
                         font=('Arial', 20), background=bgcolor, foreground='light gray',
                         cursor="hand2")

        if resolution is ClockResolution.SECONDS :
            self.digital_clock_time_format = '%H:%M:%S'
        elif resolution is ClockResolution.MINUTES:
            self.digital_clock_time_format = '%H:%M'
        else:
            print("Unrecognized digital clock resolution", resolution)
            exit( 1 )

        self.resolution = resolution
        self.bind("<Button-1>", reset_clock)
        self.clock_offset = 0
        self.update_time()

    def update_time(self):
        """Updates the digital_clock label with the current time."""
        # Get the current time and format it

        string_time = time.strftime(self.digital_clock_time_format)  # Example: 15:03:00
        self.config(text=string_time)  # Update the label's text

        one_millisecond_in_microseconds = 1000
        one_second_in_milliseconds = 1000


        # Get the current datetime object
        current_datetime = datetime.datetime.now()

        # Extract the microseconds
        current_time_in_microseconds = current_datetime.microsecond

        # Round to milliseconds
        current_time_in_milliseconds = ( ( current_time_in_microseconds + (one_millisecond_in_microseconds // 2) )
                                         // one_millisecond_in_microseconds )

        # Compute the next tick
        next_tick_time_in_seconds    = ( ( current_time_in_milliseconds + one_second_in_milliseconds)
                                         // one_second_in_milliseconds )

        # Delay for that in milliseconds
        delay_in_milliseconds = next_tick_time_in_seconds * one_second_in_milliseconds - current_time_in_milliseconds

        # Schedule the update_time function to run again after 1000 milliseconds (1 second)
        self.next_update = self.after(delay_in_milliseconds, self.update_time)

    def cancel_updating(self):
        self.after_cancel(self.next_update)


    def now():
        # Get the current time
        time_now = datetime.datetime.now()
        time_string = time_now.strftime("%Y-%m-%d "+self.digital_clock_time_format)
        return time_string


    def today_at_1930():
        # Get today's date
        today = datetime.date.today()

        # Create a time object for 7:30 PM
        time_730pm = datetime.time(19, 30)  # Use 24-hour format for the time object

        # Combine the date and time into a datetime object
        datetime_730pm = datetime.datetime.combine(today, time_730pm)

        # Format the datetime object as a string
        # %I for 12-hour clock, %M for minutes, %p for AM/PM
        time_string = datetime_730pm.strftime("%Y-%m-%d %H:%M")
        return time_string




# Create the small digital clock
def create_digital_clock():
    return DigitalClock(digital_clock_resolution, carolina_blue_hex)

def get_time(label, prompt, default):
    popup = InputPopup(root, label, prompt, default)
    root.wait_window(popup) # Wait for the popup window to close
    return popup.user_input

def get_session_start_time():
    return get_time("Session Start Time", "Enter start time:", DigitalClock.today_at_1930())

def get_clock_set_time():
    return get_time("Set Clock Time", "Enter clock time:", DigitalClock.now())


def create_Carolina_font():
    try:
        return tkFont.Font(family="Academy Engraved LET", size=48)
    except tkFont.TclError:
        # Fallback to a different font if Old English is not available
        print("Warning: 'Academy Engraved LET' not found, using Arial (bold) as a fallback.") # Add a warning
        return tkFont.Font(family="Arial, size=48, weight=bold")

def create_Carolina_label(label_text):
    # Create a custom font for the label
        # Replace "Old English Text MT" with an available font on your system
        # You might need to experiment or use a font like "Blackletter"
        # You can also adjust the size as needed
    # Create the big label
    return tk.Label(root, text=label_text, font=carolina_font,
                              bg=carolina_blue_hex, fg="white")




def create_session_start_time_label(sessionStartTime):
    # Create the start time label
    label_text = "Session Start Time " + sessionStartTime
    return tk.Label(root, text=label_text, font=('Arial', 12),
                    background=carolina_blue_hex, fg="light gray")


def create_session_close_button():
    return ttk.Button(root, text="Close Session", command=close_window)




class PlayerNameListbox(tk.Listbox):

    def __init__(self, selectedfn):
        super().__init__(root, selectmode=tk.SINGLE)
        self['bg'] = carolina_blue_hex
        self.ID_and_name_list = None
        self.selectedfn = selectedfn
        self.bind('<<ListboxSelect>>', self.on_player_name_select)

    def refresh_ID_and_name_list(self):
        self.delete(0,tk.END)
        self.ID_and_name_list = fetch_data_from_db(player_name_query)
        if not self.ID_and_name_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None

        names = [item[1] for item in self.ID_and_name_list] # Extract the names into a list
        for item in names:
            self.insert(tk.END, item)
            self.selection_clear(0,tk.END)
        return self

    def on_player_name_select(self, event):
        selected_index = self.curselection()
        if selected_index is not None:
            selected_item = self.get(selected_index[0])
            (selected_ID, selected_name) = self.ID_and_name_list[selected_index[0]]
            self.selectedfn(self, selected_ID, selected_name)
        else:
            selected_item = None



class SessionsTreeview(ttk.Treeview):

    sessions_query="""
SELECT
    s.Session_ID
        as "Session_ID",

    s.Player_ID
        as "Player_ID",

    IFNULL(p.NickName,p.Name)
	as "Name",

    s.Start_Time,

    s.Stop_Time,

    ROUND((unixepoch(s.Stop_Time)-unixepoch(s.Start_Time))/3600.0*c.Hourly_Rate)
        as "Session_Seat_Fee",

    c.Name
        as "Category",

    c.Hourly_Rate
        as "Hourly_Rate"

FROM
       Player as p
   INNER JOIN
       Player_Category as c
   INNER JOIN
       Session as s
   ON
       p.Player_ID = s.Player_ID
   AND
       p.Player_Category_ID = c.Player_Category_ID;

"""

    def __init__(self, selectedfn):
        super().__init__(root, columns=("Column1", "Column2", "Column3", "Column4" ), show="headings")
        self.column("Column1", width=160, stretch=False)
        self.heading("Column1", text="Name")
        self.column("Column2", width=80, stretch=False)
        self.heading("Column2", text="Start Time")
        self.column("Column3", width=80, stretch=False)
        self.heading("Column3", text="Stop Time")
        self.column("Column4", width=75, stretch=False)
        self.heading("Column4", text="Amount Due")

        self.tag_configure("courier", font=("Courier", 10))



    def refresh_ID_and_name_list(self):
        self.delete(*self.get_children())
        self.session_list = fetch_data_from_db(self.sessions_query)
        if not self.session_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None

        def strip_time(time_string):
            return (datetime.datetime.strptime(time_string, "%Y-%m-%d %H:%M:%S.000")
                                     .strftime("%-m/%-d %H:%M"))

        for (sessionID, playerID, playerName,
             sessionStartTime, sessionStopTime, sessionSeatFee,
             _, _) in self.session_list:
            self.insert("", "end",
                        values=(playerName,
                                strip_time(sessionStartTime),
                                strip_time(sessionStopTime),
                                locale.currency(sessionSeatFee, grouping=True).rjust(8)),
                        tags=("courier",))

        self.selection_clear()

        return self

    def on_session_select(self, event):
        selected_index = self.curselection()
        if selected_index is not None:
            selected_session = self.get(selected_index[0])
            (sessionID, playerID, playerName,
             sessionStartTime, sessionStopTime, sessionSeatFee,
             _, _) = self.session_list[selected_index[0]]
            self.selectedfn(self, sessionID, playerID, playerName,
                            sessionStartTime, sessionStopTime, sessionSeatFee)
        else:
            selected_item = None


def create_sessions_treeview():
    def selectedfn(sessions_treeview, sessionID, playerID, playerName,
                   sessionStartTime, sessionStopTime, sessionSeatFee):
        print("selected_ID:", sessionID, "selected_name:", playerName)

    sessions_treeview = SessionsTreeview(selectedfn)

    if sessions_treeview.refresh_ID_and_name_list() is None:
        return None

    return sessions_treeview

def create_player_name_listbox(sessions_treeview):
    def selectedfn(player_name_listbox, ID, name, sessions_treeview):
        print("selected_ID:", ID, "selected_name:", name)

    player_name_listbox = PlayerNameListbox(selectedfn)

    if player_name_listbox.refresh_ID_and_name_list() is None:
        return None

    return player_name_listbox


def create_bottom_banner():
     return tk.Label(root, text=label_text, font=carolina_font,
                              bg=carolina_blue_hex, fg="white")





def create_session_start_time_label(sessionStartTime):
    # Create the start time label
    label_text = "Session Start Time " + sessionStartTime
    return tk.Label(root, text=label_text, font=('Arial', 12),
                    background=carolina_blue_hex, fg="light gray")


def create_session_close_button():
    return ttk.Button(root, text="Close Session", command=close_window)




class PlayerNameListbox(tk.Listbox):

    def __init__(self, selectedfn):
        super().__init__(root, selectmode=tk.SINGLE)
        self['bg'] = carolina_blue_hex
        self.ID_and_name_list = None
        self.selectedfn = selectedfn
        self.bind('<<ListboxSelect>>', self.on_player_name_select)

    def refresh_ID_and_name_list(self):
        self.delete(0,tk.END)
        self.ID_and_name_list = fetch_data_from_db(player_name_query)
        if not self.ID_and_name_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None

        names = [item[1] for item in self.ID_and_name_list] # Extract the names into a list
        for item in names:
            self.insert(tk.END, item)
            self.selection_clear(0,tk.END)
        return self

    def on_player_name_select(self, event):
        selected_index = self.curselection()
        if selected_index is not None:
            selected_item = self.get(selected_index[0])
            (selected_ID, selected_name) = self.ID_and_name_list[selected_index[0]]
            self.selectedfn(self, selected_ID, selected_name)
        else:
            selected_item = None



class SessionsTreeview(ttk.Treeview):

    sessions_query="""
SELECT
    s.Session_ID
        as "Session_ID",

    s.Player_ID
        as "Player_ID",

    IFNULL(p.NickName,p.Name)
	as "Name",

    s.Start_Time,

    s.Stop_Time,

    ROUND((unixepoch(s.Stop_Time)-unixepoch(s.Start_Time))/3600.0*c.Hourly_Rate)
        as "Session_Seat_Fee",

    c.Name
        as "Category",

    c.Hourly_Rate
        as "Hourly_Rate"

FROM
       Player as p
   INNER JOIN
       Player_Category as c
   INNER JOIN
       Session as s
   ON
       p.Player_ID = s.Player_ID
   AND
       p.Player_Category_ID = c.Player_Category_ID;

"""

    def __init__(self, selectedfn):
        super().__init__(root, columns=("Column1", "Column2", "Column3", "Column4" ), show="headings")
        self.column("Column1", width=160, stretch=False)
        self.heading("Column1", text="Name")
        self.column("Column2", width=80, stretch=False)
        self.heading("Column2", text="Start Time")
        self.column("Column3", width=80, stretch=False)
        self.heading("Column3", text="Stop Time")
        self.column("Column4", width=75, stretch=False)
        self.heading("Column4", text="Amount Due")

        self.tag_configure("courier", font=("Courier", 10))



    def refresh_ID_and_name_list(self):
        self.delete(*self.get_children())
        self.session_list = fetch_data_from_db(self.sessions_query)
        if not self.session_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None

        def strip_time(time_string):
            return (datetime.datetime.strptime(time_string, "%Y-%m-%d %H:%M:%S.000")
                                     .strftime("%-m/%-d %H:%M"))

        for (sessionID, playerID, playerName,
             sessionStartTime, sessionStopTime, sessionSeatFee,
             _, _) in self.session_list:
            self.insert("", "end",
                        values=(playerName,
                                strip_time(sessionStartTime),
                                strip_time(sessionStopTime),
                                locale.currency(sessionSeatFee, grouping=True).rjust(8)),
                        tags=("courier",))

        self.selection_clear()

        return self

    def on_session_select(self, event):
        selected_index = self.curselection()
        if selected_index is not None:
            selected_session = self.get(selected_index[0])
            (sessionID, playerID, playerName,
             sessionStartTime, sessionStopTime, sessionSeatFee,
             _, _) = self.session_list[selected_index[0]]
            self.selectedfn(self, sessionID, playerID, playerName,
                            sessionStartTime, sessionStopTime, sessionSeatFee)
        else:
            selected_item = None


def create_sessions_treeview():
    def selectedfn(sessions_treeview, sessionID, playerID, playerName,
                   sessionStartTime, sessionStopTime, sessionSeatFee):
        print("selected_ID:", sessionID, "selected_name:", playerName)

    sessions_treeview = SessionsTreeview(selectedfn)

    if sessions_treeview.refresh_ID_and_name_list() is None:
        return None

    return sessions_treeview

def create_player_name_listbox(sessions_treeview):
    def selectedfn(player_name_listbox, ID, name, sessions_treeview):
        print("selected_ID:", ID, "selected_name:", name)

    player_name_listbox = PlayerNameListbox(selectedfn)

    if player_name_listbox.refresh_ID_and_name_list() is None:
        return None

    return player_name_listbox


def create_bottom_banner():
     return tk.Label(root, text=label_text, font=carolina_font,
                              bg=carolina_blue_hex, fg="white")





def create_session_start_time_label(sessionStartTime):
    # Create the start time label
    label_text = "Session Start Time " + sessionStartTime
    return tk.Label(root, text=label_text, font=('Arial', 12),
                    background=carolina_blue_hex, fg="light gray")


def create_session_close_button():
    return ttk.Button(root, text="Close Session", command=close_window)




class PlayerNameListbox(tk.Listbox):

    def __init__(self, selectedfn):
        super().__init__(root, selectmode=tk.SINGLE)
        self['bg'] = carolina_blue_hex
        self.ID_and_name_list = None
        self.selectedfn = selectedfn
        self.bind('<<ListboxSelect>>', self.on_player_name_select)

    def refresh_ID_and_name_list(self):
        self.delete(0,tk.END)
        self.ID_and_name_list = fetch_data_from_db(player_name_query)
        if not self.ID_and_name_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None

        names = [item[1] for item in self.ID_and_name_list] # Extract the names into a list
        for item in names:
            self.insert(tk.END, item)
            self.selection_clear(0,tk.END)
        return self

    def on_player_name_select(self, event):
        selected_index = self.curselection()
        if selected_index is not None:
            selected_item = self.get(selected_index[0])
            (selected_ID, selected_name) = self.ID_and_name_list[selected_index[0]]
            self.selectedfn(self, selected_ID, selected_name)
        else:
            selected_item = None



class SessionsTreeview(ttk.Treeview):

    sessions_query="""
SELECT
    s.Session_ID
        as "Session_ID",

    s.Player_ID
        as "Player_ID",

    IFNULL(p.NickName,p.Name)
	as "Name",

    s.Start_Time,

    s.Stop_Time,

    ROUND((unixepoch(s.Stop_Time)-unixepoch(s.Start_Time))/3600.0*c.Hourly_Rate)
        as "Session_Seat_Fee",

    c.Name
        as "Category",

    c.Hourly_Rate
        as "Hourly_Rate"

FROM
       Player as p
   INNER JOIN
       Player_Category as c
   INNER JOIN
       Session as s
   ON
       p.Player_ID = s.Player_ID
   AND
       p.Player_Category_ID = c.Player_Category_ID;

"""

    def __init__(self, selectedfn):
        super().__init__(root, columns=("Column1", "Column2", "Column3", "Column4" ), show="headings")
        self.column("Column1", width=160, stretch=False)
        self.heading("Column1", text="Name")
        self.column("Column2", width=80, stretch=False)
        self.heading("Column2", text="Start Time")
        self.column("Column3", width=80, stretch=False)
        self.heading("Column3", text="Stop Time")
        self.column("Column4", width=75, stretch=False)
        self.heading("Column4", text="Amount Due")

        self.tag_configure("courier", font=("Courier", 10))



    def refresh_ID_and_name_list(self):
        self.delete(*self.get_children())
        self.session_list = fetch_data_from_db(self.sessions_query)
        if not self.session_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None

        def strip_time(time_string):
            return (datetime.datetime.strptime(time_string, "%Y-%m-%d %H:%M:%S.000")
                                     .strftime("%-m/%-d %H:%M"))

        for (sessionID, playerID, playerName,
             sessionStartTime, sessionStopTime, sessionSeatFee,
             _, _) in self.session_list:
            self.insert("", "end",
                        values=(playerName,
                                strip_time(sessionStartTime),
                                strip_time(sessionStopTime),
                                locale.currency(sessionSeatFee, grouping=True).rjust(8)),
                        tags=("courier",))

        self.selection_clear()

        return self

    def on_session_select(self, event):
        selected_index = self.curselection()
        if selected_index is not None:
            selected_session = self.get(selected_index[0])
            (sessionID, playerID, playerName,
             sessionStartTime, sessionStopTime, sessionSeatFee,
             _, _) = self.session_list[selected_index[0]]
            self.selectedfn(self, sessionID, playerID, playerName,
                            sessionStartTime, sessionStopTime, sessionSeatFee)
        else:
            selected_item = None


def create_sessions_treeview():
    def selectedfn(sessions_treeview, sessionID, playerID, playerName,
                   sessionStartTime, sessionStopTime, sessionSeatFee):
        print("selected_ID:", sessionID, "selected_name:", playerName)

    sessions_treeview = SessionsTreeview(selectedfn)

    if sessions_treeview.refresh_ID_and_name_list() is None:
        return None

    return sessions_treeview

def create_player_name_listbox(sessions_treeview):
    def selectedfn(player_name_listbox, ID, name, sessions_treeview):
        print("selected_ID:", ID, "selected_name:", name)

    player_name_listbox = PlayerNameListbox(selectedfn)

    if player_name_listbox.refresh_ID_and_name_list() is None:
        return None

    return player_name_listbox


def create_bottom_banner():
     return tk.Label(root, text=label_text, font=carolina_font,
                              bg=carolina_blue_hex, fg="white")





def create_session_start_time_label(sessionStartTime):
    # Create the start time label
    label_text = "Session Start Time " + sessionStartTime
    return tk.Label(root, text=label_text, font=('Arial', 12),
                    background=carolina_blue_hex, fg="light gray")


def create_session_close_button():
    return ttk.Button(root, text="Close Session", command=close_window)




class PlayerNameListbox(tk.Listbox):

    def __init__(self, selectedfn):
        super().__init__(root, selectmode=tk.SINGLE)
        self['bg'] = carolina_blue_hex
        self.ID_and_name_list = None
        self.selectedfn = selectedfn
        self.bind('<<ListboxSelect>>', self.on_player_name_select)

    def refresh_ID_and_name_list(self):
        self.delete(0,tk.END)
        self.ID_and_name_list = fetch_data_from_db(player_name_query)
        if not self.ID_and_name_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None

        names = [item[1] for item in self.ID_and_name_list] # Extract the names into a list
        for item in names:
            self.insert(tk.END, item)
            self.selection_clear(0,tk.END)
        return self

    def on_player_name_select(self, event):
        selected_index = self.curselection()
        if selected_index is not None:
            selected_item = self.get(selected_index[0])
            (selected_ID, selected_name) = self.ID_and_name_list[selected_index[0]]
            self.selectedfn(self, selected_ID, selected_name)
        else:
            selected_item = None



class SessionsTreeview(ttk.Treeview):

    sessions_query="""
SELECT
    s.Session_ID
        as "Session_ID",

    s.Player_ID
        as "Player_ID",

    IFNULL(p.NickName,p.Name)
	as "Name",

    s.Start_Time,

    s.Stop_Time,

    ROUND((unixepoch(s.Stop_Time)-unixepoch(s.Start_Time))/3600.0*c.Hourly_Rate)
        as "Session_Seat_Fee",

    c.Name
        as "Category",

    c.Hourly_Rate
        as "Hourly_Rate"

FROM
       Player as p
   INNER JOIN
       Player_Category as c
   INNER JOIN
       Session as s
   ON
       p.Player_ID = s.Player_ID
   AND
       p.Player_Category_ID = c.Player_Category_ID;

"""

    def __init__(self, selectedfn):
        super().__init__(root, columns=("Column1", "Column2", "Column3", "Column4" ), show="headings")
        self.column("Column1", width=160, stretch=False)
        self.heading("Column1", text="Name")
        self.column("Column2", width=80, stretch=False)
        self.heading("Column2", text="Start Time")
        self.column("Column3", width=80, stretch=False)
        self.heading("Column3", text="Stop Time")
        self.column("Column4", width=75, stretch=False)
        self.heading("Column4", text="Amount Due")

        self.tag_configure("courier", font=("Courier", 10))



    def refresh_ID_and_name_list(self):
        self.delete(*self.get_children())
        self.session_list = fetch_data_from_db(self.sessions_query)
        if not self.session_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None

        def strip_time(time_string):
            return (datetime.datetime.strptime(time_string, "%Y-%m-%d %H:%M:%S.000")
                                     .strftime("%-m/%-d %H:%M"))

        for (sessionID, playerID, playerName,
             sessionStartTime, sessionStopTime, sessionSeatFee,
             _, _) in self.session_list:
            self.insert("", "end",
                        values=(playerName,
                                strip_time(sessionStartTime),
                                strip_time(sessionStopTime),
                                locale.currency(sessionSeatFee, grouping=True).rjust(8)),
                        tags=("courier",))

        self.selection_clear()

        return self

    def on_session_select(self, event):
        selected_index = self.curselection()
        if selected_index is not None:
            selected_session = self.get(selected_index[0])
            (sessionID, playerID, playerName,
             sessionStartTime, sessionStopTime, sessionSeatFee,
             _, _) = self.session_list[selected_index[0]]
            self.selectedfn(self, sessionID, playerID, playerName,
                            sessionStartTime, sessionStopTime, sessionSeatFee)
        else:
            selected_item = None


def create_sessions_treeview():
    def selectedfn(sessions_treeview, sessionID, playerID, playerName,
                   sessionStartTime, sessionStopTime, sessionSeatFee):
        print("selected_ID:", sessionID, "selected_name:", playerName)

    sessions_treeview = SessionsTreeview(selectedfn)

    if sessions_treeview.refresh_ID_and_name_list() is None:
        return None

    return sessions_treeview

def create_player_name_listbox(sessions_treeview):
    def selectedfn(player_name_listbox, ID, name, sessions_treeview):
        print("selected_ID:", ID, "selected_name:", name)

    player_name_listbox = PlayerNameListbox(selectedfn)

    if player_name_listbox.refresh_ID_and_name_list() is None:
        return None

    return player_name_listbox


def create_bottom_banner():
     return tk.Label(root, text=label_text, font=carolina_font,
                              bg=carolina_blue_hex, fg="white")




def create_session_start_time_label(sessionStartTime):
    # Create the start time label
    label_text = "Session Start Time " + sessionStartTime
    return tk.Label(root, text=label_text, font=('Arial', 12),
                    background=carolina_blue_hex, fg="light gray")




class PlayerNameListbox(tk.Listbox):

    def __init__(self, selectedfn):
        super().__init__(root, selectmode=tk.SINGLE)
        self['bg'] = carolina_blue_hex
        self.ID_and_name_list = None
        self.selectedfn = selectedfn
        self.bind('<<ListboxSelect>>', self.on_player_name_select)

    def refresh_ID_and_name_list(self):
        self.delete(0,tk.END)
        self.ID_and_name_list = fetch_data_from_db(player_name_query)
        if not self.ID_and_name_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None

        names = [item[1] for item in self.ID_and_name_list] # Extract the names into a list
        for item in names:
            self.insert(tk.END, item)
            self.selection_clear(0,tk.END)
        return self

    def on_player_name_select(self, event):
        selected_index = self.curselection()
        if selected_index is not None:
            selected_item = self.get(selected_index[0])
            (selected_ID, selected_name) = self.ID_and_name_list[selected_index[0]]
            self.selectedfn(self, selected_ID, selected_name)
        else:
            selected_item = None



class SessionsTreeview(ttk.Treeview):

    sessions_query="""
SELECT
    s.Session_ID
        as "Session_ID",

    s.Player_ID
        as "Player_ID",

    IFNULL(p.NickName,p.Name)
	as "Name",

    s.Start_Time,

    s.Stop_Time,

    ROUND((unixepoch(s.Stop_Time)-unixepoch(s.Start_Time))/3600.0*c.Hourly_Rate)
        as "Session_Seat_Fee",

    c.Name
        as "Category",

    c.Hourly_Rate
        as "Hourly_Rate"

FROM
       Player as p
   INNER JOIN
       Player_Category as c
   INNER JOIN
       Session as s
   ON
       p.Player_ID = s.Player_ID
   AND
       p.Player_Category_ID = c.Player_Category_ID;

"""

    def __init__(self, selectedfn):
        super().__init__(root, columns=("Column1", "Column2", "Column3", "Column4" ), show="headings")
        self.column("Column1", width=160, stretch=False)
        self.heading("Column1", text="Name")
        self.column("Column2", width=80, stretch=False)
        self.heading("Column2", text="Start Time")
        self.column("Column3", width=80, stretch=False)
        self.heading("Column3", text="Stop Time")
        self.column("Column4", width=75, stretch=False)
        self.heading("Column4", text="Amount Due")

        self.tag_configure("courier", font=("Courier", 10))



    def refresh_ID_and_name_list(self):
        self.delete(*self.get_children())
        self.session_list = fetch_data_from_db(self.sessions_query)
        if not self.session_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None

        def strip_time(time_string):
            return (datetime.datetime.strptime(time_string, "%Y-%m-%d %H:%M:%S.000")
                                     .strftime("%-m/%-d %H:%M"))

        for (sessionID, playerID, playerName,
             sessionStartTime, sessionStopTime, sessionSeatFee,
             _, _) in self.session_list:
            self.insert("", "end",
                        values=(playerName,
                                strip_time(sessionStartTime),
                                strip_time(sessionStopTime),
                                locale.currency(sessionSeatFee, grouping=True).rjust(8)),
                        tags=("courier",))

        self.selection_clear()

        return self

    def on_session_select(self, event):
        selected_index = self.curselection()
        if selected_index is not None:
            selected_session = self.get(selected_index[0])
            (sessionID, playerID, playerName,
             sessionStartTime, sessionStopTime, sessionSeatFee,
             _, _) = self.session_list[selected_index[0]]
            self.selectedfn(self, sessionID, playerID, playerName,
                            sessionStartTime, sessionStopTime, sessionSeatFee)
        else:
            selected_item = None


def create_sessions_treeview():
    def selectedfn(sessions_treeview, sessionID, playerID, playerName,
                   sessionStartTime, sessionStopTime, sessionSeatFee):
        print("selected_ID:", sessionID, "selected_name:", playerName)

    sessions_treeview = SessionsTreeview(selectedfn)

    if sessions_treeview.refresh_ID_and_name_list() is None:
        return None

    return sessions_treeview

def create_player_name_listbox():
    def selectedfn(player_name_listbox, ID, name):
        print("selected_ID:", ID, "selected_name:", name)

    player_name_listbox = PlayerNameListbox(selectedfn)

    if player_name_listbox.refresh_ID_and_name_list() is None:
        return None

    return player_name_listbox




def create_session_close_button(width):
    # Create a clear pixel
    # Create a button with an image and text, compound ensures both are visible
    return tk.Button(root, text="Close Session",
                     width=round(width/10), command=close_window)


def create_bottom_banner():
    return tk.Label(root, text='♠️♥️♦️♣️', bg=carolina_blue_hex, fg="white")


digital_clock=None
sessionStartTime=None
carolina_font=None

def show_session_panel():
    # Define the hex code for Carolina Blue

    root.title("Carolina Card Club Session")
    root['bg']=carolina_blue_hex
    root.geometry('800x600')


    root.grid_columnconfigure(0, weight=1)  # Column 0 expands
    root.grid_columnconfigure(1, weight=1)  # Column 1 expands
    root.rowconfigure(0, weight=0) # Row 3 expands
    root.rowconfigure(1, weight=0) # Row 3 expands
    root.rowconfigure(2, weight=0) # Row 3 expands
    root.rowconfigure(3, weight=0) # Row 3 expands
    root.rowconfigure(4, weight=1) # Row 3 expands
    root.rowconfigure(5, weight=0) # Row 3 expands


    global carolina_font
    carolina_font = create_Carolina_font()
    if carolina_font is None: return

    global digital_clock
    digital_clock=create_digital_clock()
    digital_clock.grid(row=0, column=1, sticky="e")

    carolina_label=create_Carolina_label("Carolina Card Club")
    # Place the label in the grid, spanning the available width (sticky='ew')
    carolina_label.grid(row=1, column=0, columnspan=2, sticky='ew')


    global sessionStartTime
    sessionStartTime = get_session_start_time()
    if sessionStartTime is None: return

    session_start_time_label = create_session_start_time_label(sessionStartTime)
    if session_start_time_label is None: return
    session_start_time_label.grid(row=2, column=1, sticky="w")

    sessions_treeview = create_sessions_treeview()
    if sessions_treeview is None: return
    sessions_treeview.grid(row=4, column=1, rowspan=1, sticky="nsw")

    player_name_listbox=create_player_name_listbox()
    if player_name_listbox is None: return
    player_name_listbox.grid(row=4, column=0, rowspan=1, sticky="nse")


    # Get the width of the Treeview widget
    root.update_idletasks()
    treeview_width = sessions_treeview.winfo_width()
    close_button = create_session_close_button(treeview_width)
    if close_button is None: return
    close_button.grid(row=3,column=1, sticky="w")

    bottom_banner = create_bottom_banner()
    if bottom_banner is None: return
    bottom_banner.grid(row=5, column=0, columnspan=2, sticky="nsew")

    root.mainloop()


def close_window():
    digital_clock.cancel_updating()
    root.destroy()


if __name__ == "__main__":
    show_session_panel()
