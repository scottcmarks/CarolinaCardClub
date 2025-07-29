#!/usr/bin/env python3
# Copyright (c) 2025 Scott Marks
"""
Run a session management module for Carolina Card Club
"""

import tkinter as tk
from tkinter import messagebox, ttk
import tkinter.font as tkFont # Import the font module for custom fonts
import sqlite3
import datetime
from datetime import timezone
import time
from enum import Enum
import locale
import sys

#Useful color chart at
#https://cs111.wellesley.edu/archive/cs111_fall14/public_html/labs/lab12/tkintercolor.html
CAROLINA_BLUE_HEX = "#4B9CD3"


root = tk.Tk()

exit_code = 0


class ClockResolution(Enum):
    """ Enum for selecting clock resolution """
    SECONDS = 1000
    MINUTES = SECONDS * 60

digital_clock_resolution = ClockResolution.SECONDS

HICKORY_CLICKABLE_CLOCK = False

class DigitalClock(tk.Label):
    """
       Label specialized to show time
       and allow interaction to reset clock
    """

    def __init__(self, resolution, bgcolor):
        super().__init__(root,
                         font=('Arial', 20),
                         background=bgcolor, foreground='light gray',
                         cursor="hand2" if HICKORY_CLICKABLE_CLOCK else
#                                 "watch"
                                "arrow"
                         )

        if resolution is ClockResolution.SECONDS :
            self.digital_clock_time_format = '%H:%M:%S'
        elif resolution is ClockResolution.MINUTES:
            self.digital_clock_time_format = '%H:%M'
        else:
            print("Unrecognized digital clock resolution", resolution)
            exit_code = 1
            root.destroy()


        self.resolution = resolution
        if HICKORY_CLICKABLE_CLOCK:
            self.bind('<Button-1>', self.reset_clock)
        self.clock_offset = 0
        self.update_time()

    def update_time(self):
        """
        Updates the digital_clock label with the current time.
        """

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
        current_time_in_milliseconds = ( ( current_time_in_microseconds
                                           + (one_millisecond_in_microseconds // 2) )
                                         // one_millisecond_in_microseconds )

        # Compute the next tick
        next_tick_time_in_seconds    = ( ( current_time_in_milliseconds
                                           + one_second_in_milliseconds)
                                         // one_second_in_milliseconds )

        # Delay for that in milliseconds
        delay_in_milliseconds = ( ( next_tick_time_in_seconds * one_second_in_milliseconds )
                                  -  current_time_in_milliseconds )

        # Schedule the update_time function to run again after 1000 milliseconds (1 second)
        self.next_update = self.after(delay_in_milliseconds, self.update_time)

    def cancel_updating(self):
        """
        Stop the clock updating.
        Do this before stopping the program to avoid a messy error on sys.exiting.
        """
        self.after_cancel(self.next_update)

    def reset_clock(self, event):
        """
        Reset the system clock
        """
        print("RESET CLOCK", event, self.resolution, self.digital_clock_time_format)
        self.update_time()


    def now(self):
        """
        Get the current time in the current digital clock time format
        """
        time_now = datetime.datetime.now()
        time_string = time_now.strftime("%Y-%m-%d "+self.digital_clock_time_format)
        return time_string


# Create the small digital clock
digital_clock = DigitalClock(digital_clock_resolution, CAROLINA_BLUE_HEX)

def close_window(ex_cd=0):
    """
    Close the main window.
    Stop the digital clock updating to end the program cleanly.
    """
    digital_clock.cancel_updating()
    exit_code = ex_cd
    root.destroy()


# Set the locale (example for US English)
locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')

def fetch_data_from_db(query):
    """
    Fetches data from the Carolina Card Club database.
    """
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

def send_data_to_db(query,data):
    """
    Sends data to the Carolina Card Club database.
    """
    conn = None
    try:
        conn = sqlite3.connect('CarolinaCardClub.db')
        cursor = conn.cursor()
        cursor.execute(query, data)
        conn.commit()
    except sqlite3.Error as e:
        messagebox.showerror("Database Error", f"Error sending data: {e}")
        return []
    finally:
        if conn:
            conn.close()



class InputPopup(tk.Toplevel):
    """
    Specialize TopLevel to package a user Entry with
    a Cancel Button and an OK Button
    """
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
        """
        The Cancel button picks no input
        """
        self.user_input = None
        self.done()

    def on_ok(self):
        """
        The OK button pick the user input
        """
        self.user_input = self.entry.get()
        self.done()

    def on_spacebar_press(self, _event):
        """
        Spacebar is an assistive shortcut for button2=OK.
        """
        self.button2.invoke()
        self.done()

    def done(self):
        """
        Clean up this instance.
        """
        self.unbind('<space>')
        self.destroy()





def strip_time(time_string):
    return (datetime.datetime.strptime(time_string, "%Y-%m-%d %H:%M:%S.000")
                             .strftime("%-m/%-d %H:%M"))


def local_time(epoch):
    dt_object_local = datetime.datetime.fromtimestamp(epoch)
    # Format the datetime object into a human-readable string
    # Customize the format using strftime codes (similar to SQLite)
    formatted_time = dt_object_local.strftime('%-m/%-d %H:%M')
    return formatted_time


def today_at_1930():
    """
    Compute the time for today at 7:30 PM for the default session start time
    """
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




def get_user_input(label, prompt, default):
    """
    Use an InputPopup to get a user input
    """
    popup = InputPopup(root, label, prompt, default)
    root.wait_window(popup) # Wait for the popup window to close
    return popup.user_input

def get_session_start_time():
    """
    Use the get_user_input popup to set the session start time
    """
    return get_user_input("Session Start Time", "Enter start time:", today_at_1930())


def create_carolina_font():
    """
    Create the font used by the Carolina Card Club label
    """
    try:
        return tkFont.Font(family="Academy Engraved LET", size=48)
    except tk.TclError:
        # Fallback to a different font if Old English is not available
        print("Warning: 'Academy Engraved LET' not found, using Arial (bold) as a fallback.")
        return tkFont.Font(family="Arial, size=48, weight=bold")

def create_carolina_label(label_text):
    """
    Create the Carolina Card Club label at the top
    """
    # Create a custom font for the label
        # Replace "Old English Text MT" with an available font on your system
        # You might need to experiment or use a font like "Blackletter"
        # You can also adjust the size as needed
    # Create the big label
    return tk.Label(root, text=label_text, font=carolina_font,
                              bg=CAROLINA_BLUE_HEX, fg="white")



class PlayerNameSelector(tk.Frame):
    """
       Frame containing a Listbox set up
       to show a players selection view
       and allow interaction with a selected player via
       either a regular click (usually just to start a session)
       or a control click (to purchase time or edit player data)
    """

    def __init__(self, regular_clickedfn, control_clickedfn):
        super().__init__(root)
        self['bg'] = CAROLINA_BLUE_HEX
        self.id_and_name_list = None
        self.listbox = tk.Listbox(self, selectmode=tk.SINGLE)
        self.listbox['bg'] = CAROLINA_BLUE_HEX
        self.regular_clickedfn = regular_clickedfn
        self.listbox.bind('<Button-1>', lambda event: self.on_player_name_clicked(event, self.regular_clickedfn))
        self.control_clickedfn = control_clickedfn
        self.listbox.bind('<Control-Button-1>', lambda event: self.on_player_name_clicked(event, self.control_clickedfn))
        self.listbox.pack(padx=5,pady=5, fill=tk.BOTH, expand=True)

    def refresh_id_and_name_list(self):
        """
        Fill out the list of players if possible.
        """
        self.listbox.delete(0,tk.END)
        self.id_and_name_list = fetch_data_from_db("SELECT * FROM Player_Selection_View")
        if not self.id_and_name_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None
        names = [item[1] for item in self.id_and_name_list] # Extract the names into a list
        for item in names:
            self.listbox.insert(tk.END, item)
        self.listbox.selection_clear(0,tk.END)
        return self

    def on_player_name_clicked(self, event, clickedfn):
        """
        Player selected by clicking.
        """
        selected_index = self.listbox.nearest(event.y)
        if selected_index is not None:
            self.listbox.selection_clear(0,tk.END)
            self.listbox.selection_set(selected_index) # ctrl-click won't select
            (player_id, name, balance) = self.id_and_name_list[selected_index]
            clickedfn(self.listbox, player_id, name, balance)


def create_session_start_time_label(start_time):
    """
    Create the start time label
    """
    if start_time is None:
        return None
    label_text = "Session Start Time " + start_time
    return tk.Label(root, text=label_text, font=('Arial', 12),
                    background=CAROLINA_BLUE_HEX, fg="light gray")


class SessionsView(tk.Frame):
    """
    Frame specialized to hold a treeview to show a sessions query result
    and allow interaction with a selected session.
    """
    def __init__(self, clickedfn):
        super().__init__(root)
        self.treeview = ttk.Treeview(self,
                         columns=("Column1",
                                  "Column2",
                                  "Column3",
                                  "Column4",
                                  "Column5" ),
                         show="headings")
        self.treeview.column("Column1", width=140, stretch=False)
        self.treeview.heading("Column1", text="Name")
        self.treeview.column("Column2", width=90, stretch=False)
        self.treeview.heading("Column2", text="Start Time")
        self.treeview.column("Column3", width=90, stretch=False)
        self.treeview.heading("Column3", text="Stop Time")
        self.treeview.column("Column4", width=75, stretch=False)
        self.treeview.heading("Column4", text="Duration")
        self.treeview.column("Column5", width=75, stretch=False)
        self.treeview.heading("Column5", text="Amount Due")
        self.treeview.tag_configure("courier", font=("Courier", 10))
        self.treeview.tag_configure("red_item", background="red", foreground="white")  # Red background, white text
        self.treeview.tag_configure("green_item", background="green", foreground="black") # Green background, black text
        self.treeview.tag_configure("bold_text", font=('Courier', 10, 'bold')) # You can apply other styling like bolding
        self.treeview.pack(padx=5,pady=5, fill=tk.BOTH, expand=True)

        self.next_update=None

        self.clickedfn  = clickedfn
        self.session_list = None


    def refresh_id_and_name_list(self):
        """
        Fill out the list of sessions if possible.
        """

        self.treeview.delete(*self.treeview.get_children())
        self.session_list = fetch_data_from_db("SELECT * FROM Session_List_View")
        if not self.session_list:
            messagebox.showinfo("No Data", "No items found in the database.")
            return None


        for (_session_id, _player_id, player_name,
             session_start_epoch, session_stop_epoch,
             _category, hourly_rate) in self.session_list:
            if session_stop_epoch is not None:
                tags=("courier",)
                effective_session_stop_epoch = session_stop_epoch
            else:
                tags=("courier", "green_item")
                effective_session_stop_epoch = int(datetime.datetime.now(timezone.utc).timestamp())
            seconds = effective_session_stop_epoch - session_start_epoch
            session_duration = f"{seconds//3600:d}h {(seconds%3600)//60:02d}m"
            session_seat_fee = round(hourly_rate * seconds / 3600)
            self.treeview.insert("", "end",
                                 text=player_name,
                                 values=(player_name,
                                         local_time(session_start_epoch),
                                         local_time(effective_session_stop_epoch),
                                         session_duration.rjust(8),
                                         locale.currency(session_seat_fee, grouping=True).rjust(8)),
                                 tags=tags)

        self.treeview.selection_clear()

        self.next_update = self.after(1000, self.refresh_id_and_name_list)

        return self

    def cancel_updating(self):
        """
        Cancel auto-updating.
        """
        self.after_cancel(self.next_update)

    def on_session_select(self, _event):
        """
        Session selected by clicking.
        """
        selected_items = self.treeview.selection()  # Get the IDs of selected items
        if selected_items is not None:
            for item_id in selected_items:
                item_data = self.treeview.item(item_id)  # Get the item's data dictionary
                print(f"Selected item text: {item_data['text']}")  # Access the 'text' key
                print(f"Selected item values: {item_data['values']}")  # Access the 'values' key
        else:
            print("No item selected.")

    def switch_to_running_session(self, player_id):
        """
        Session selected by player_id, if running.
        """
        self.refresh_id_and_name_list()
        self.cancel_updating()
        found=False

        for (item_id, session) in zip(self.treeview.get_children(), self.session_list):
            item_data = self.treeview.item(item_id)
#            print(f"Item ID: {item_id}, Text: {item_data['text']}, Values: {item_data['values']}")
            (item_player_name,
             session_start_epoch_string,
             effective_session_stop_epoch_string,
             session_duration_string,
             session_seat_fee_string) = item_data['values']
            (session_id, session_player_id, session_player_name, session_start_epoch, session_stop_epoch, session_player_category_name, session_rate) = session
#             print(f"""Item player name: {item_player_name} session: (
# session_id: {session_id} player_id: {player_id},
# session_player_name: {session_player_name}, session_start_epoch: {session_start_epoch},
# session_stop_epoch: {session_stop_epoch},
# session_player_category_name: {session_player_category_name},
# session_rate: {session_rate}
# )""")
            if player_id == session_player_id and session_stop_epoch is None:
                self.treeview.selection_set(item_id)
                found = True
                break

        self.refresh_id_and_name_list()
        return found



def create_sessions_treeview():
    """
    Create the sessions treeview, which accesses session-related functions
    """
    def clickedfn(_sessions_treeview, session_id, _player_id, player_name,
                   _session_start_time, _session_stop_time,
                  _session_duration, _session_seat_fee):
        print("selected session_id:", session_id, "player_name:", player_name)

    sessions_treeview = SessionsView(clickedfn)

    if sessions_treeview.refresh_id_and_name_list() is None:
        return None

    return sessions_treeview


def start_session(player_id, sessions_treeview):
    start_epoch=int(datetime.datetime.now(timezone.utc).timestamp())
    send_data_to_db("INSERT INTO Session (Player_ID, Start_Epoch) VALUES (?, ?)",
                    (player_id,start_epoch))
    sessions_treeview.switch_to_running_session(player_id)



def player_name_regular_clicked(player_id, name, balance, sessions_treeview):
    print("regular selected player_id:", player_id, "name:", name, "balance:", balance)
    if sessions_treeview.switch_to_running_session(player_id):
        return
    elif 0 <= balance:
        start_session(player_id, sessions_treeview)
    else:
        request_payment()


def player_name_control_clicked(player_id, name, balance):
    print("control selected player_id:", player_id, "name:", name, "balance:", balance)








def create_player_name_listbox(sessions_treeview):
    """
    Create the player name listbox which accesses player-related functions
    """
    def regular_clickedfn(_player_name_listbox, player_id, name, balance):
        player_name_regular_clicked(player_id, name, balance, sessions_treeview)

    def control_clickedfn(_player_name_listbox, player_id, name, balance):
        player_name_control_clicked(player_id, name, balance)

#    player_name_listbox = PlayerNameListbox(clickedfn)
    player_name_listbox = PlayerNameSelector(regular_clickedfn, control_clickedfn)

    if player_name_listbox.refresh_id_and_name_list() is None:
        return None

    return player_name_listbox


def create_session_close_button(treeview, close_window):
    """
    Create the session close button, which kills the app cleanly by invoking close_window
    """
    if treeview is None:
        return None
    root.update_idletasks()
    treeview_width = treeview.winfo_width()
    return tk.Button(root, text="Close Session",
                     width=round(treeview_width/10), command=close_window)


def create_bottom_banner_left():
    """
    Create the bottom banner copyright
    """
    return tk.Label(root, text='Copyright (c) 2025 Scott Marks',
                    bg=CAROLINA_BLUE_HEX, fg="black", font=("Arial",8))

def create_bottom_banner_center():
    """
    Create the bottom banner centerpiece, for decoration and spacing
    """
    return tk.Label(root, text='♠️♥️♦️♣️', bg=CAROLINA_BLUE_HEX, fg="white", font=(None,16))


carolina_font = create_carolina_font()
if carolina_font is None:
    sys.exit(1)


def show_session_panel():
    """
    Show and lay out the main session panel, the main program window.
    """
    # Define the hex code for Carolina Blue

    root.title("Carolina Card Club Session")
    root['bg']=CAROLINA_BLUE_HEX
    root.geometry('680x800')


    root.grid_columnconfigure(0, weight=1)  # Column 0 expands
    root.grid_columnconfigure(1, weight=1)  # Column 1 expands
    root.rowconfigure(0, weight=0) # Row 3 expands
    root.rowconfigure(1, weight=0) # Row 3 expands
    root.rowconfigure(2, weight=0) # Row 3 expands
    root.rowconfigure(3, weight=0) # Row 3 expands
    root.rowconfigure(4, weight=1) # Row 3 expands
    root.rowconfigure(5, weight=0) # Row 3 expands




    carolina_label=create_carolina_label("Carolina Card Club")
    session_start_time = get_session_start_time()
    session_start_time_label = create_session_start_time_label(session_start_time)
    sessions_treeview = create_sessions_treeview()
    player_name_listbox=create_player_name_listbox(sessions_treeview)

    if (digital_clock is None or
        carolina_label is None or
        session_start_time_label is None or
        sessions_treeview is None or
        player_name_listbox is None):
        close_window(1)


    close_button = create_session_close_button(sessions_treeview, close_window)
    bottom_banner_center = create_bottom_banner_center()
    bottom_banner_left = create_bottom_banner_left()

    if (close_button is None or
        bottom_banner_center is None or
        bottom_banner_left is None):
        close_window(1)

    digital_clock.            grid(row=0, column=1, sticky="e")

    carolina_label.           grid(row=1, column=0, columnspan=2, sticky='ew')

    session_start_time_label. grid(row=2, column=1, sticky="w")

    close_button.             grid(row=3, column=1, sticky="w")

    sessions_treeview.        grid(row=4, column=1, rowspan=1, sticky="nsw")
    player_name_listbox.      grid(row=4, column=0, rowspan=1, sticky="nse")

    bottom_banner_center.     grid(row=5, column=0, columnspan=2, sticky="nsew")

    bottom_banner_left.       grid(row=6, column=0, sticky="nsw")



if __name__ == "__main__":
    show_session_panel()

    root.mainloop()

    digital_clock.cancel_updating()
    sessions_treeview.cancel_updating()

    if exit_code != 0:
        sys.exit(exit_code)
