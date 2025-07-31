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
from zoneinfo import ZoneInfo
import time
from enum import Enum
import locale
import sys
from inputpopup import *
from digitalclock import *


#Useful color chart at
#https://cs111.wellesley.edu/archive/cs111_fall14/public_html/labs/lab12/tkintercolor.html
CAROLINA_BLUE_HEX = "#4B9CD3"


root = tk.Tk()

exit_code = 0

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
    finally:
        if conn:
            conn.close()

def strip_time(time_string):
    return (datetime.datetime.strptime(time_string, "%Y-%m-%d %H:%M:%S.000")
                             .strftime("%-m/%-d %H:%M"))


def local_time(epoch):
    dt_object_local = datetime.datetime.fromtimestamp(epoch)
    # Format the datetime object into a human-readable string
    # Customize the format using strftime codes (similar to SQLite)
    formatted_time = dt_object_local.strftime('%-m/%-d %H:%M')
    return formatted_time

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


class PlayerNameSelector(tk.Frame):
    """
       Frame containing a Listbox set up
       to show a players selection view
       and allow interaction with a selected player via
       either a regular click (usually just to start a session)
       or a control click (to purchase time or edit player data)
    """

    def __init__(self, parent, regular_clickedfn, control_clickedfn):
        super().__init__(parent)
        self['bg'] = CAROLINA_BLUE_HEX
        self.id_and_name_list = None
        self.listbox = tk.Listbox(self, selectmode=tk.SINGLE)
        self.listbox['bg'] = CAROLINA_BLUE_HEX
        self.regular_clickedfn = regular_clickedfn
        self.listbox.bind('<Button-1>', self.on_player_name_clicked_lambda(self.regular_clickedfn))
        self.control_clickedfn = control_clickedfn
        self.listbox.bind('<Control-Button-1>', self.on_player_name_clicked_lambda(self.control_clickedfn))
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

    def on_player_name_clicked_lambda(self, clickedfn):
        """
        Player selected by clicking.
        """
        return lambda event: self.on_player_name_clicked(event,clickedfn)


class SessionView(tk.Frame):
    """
    Frame specialized to hold a treeview to show a sessions query result
    and allow interaction with a selected session.
    """
    def __init__(self, parent, digital_clock):
        super().__init__(parent)
        self.digital_clock = digital_clock
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

        self.next_update = None
        self.updating = True

        self.regular_clickedfn = self.session_clickedfn
        self.treeview.bind('<ButtonRelease-1>', self.on_session_clicked_lambda(self.regular_clickedfn))
        self.control_clickedfn = self.session_clickedfn
        self.treeview.bind('<Control-ButtonRelease-1>', self.on_session_clicked_lambda(self.control_clickedfn))

        self.selected_session_id = None
        self.session_list = None



    def on_session_clicked(self, event, clickedfn):
        """
        Session selected by clicking.
        """
        selected_index = self.treeview.identify_row(event.y)
        if selected_index is  None:
            return

        tree_ids = self.treeview.get_children()
        if tree_ids is None or self.session_list is None:
            return

        for (tree_id, session) in zip(tree_ids, self.session_list):
            if tree_id == selected_index:
                self.treeview.selection_clear()
                self.treeview.selection_set(selected_index) # ctrl-click won't select
                item_data = self.treeview.item(tree_id)
                (_item_player_name,
                 _session_start_epoch_string,
                 _effective_session_stop_epoch_string,
                 session_duration_string,
                 session_seat_fee_string) = item_data['values']
                (session_id, session_player_id, session_player_name,
                 session_start_epoch, session_stop_epoch,
                 _session_player_category_name, _session_rate) = session
                self.selected_session_id = session_id
                clickedfn(session_id, session_player_id, session_player_name,
                          session_start_epoch, session_stop_epoch,
                          session_duration_string, session_seat_fee_string)

    def on_session_clicked_lambda(self, clickedfn):
        """
        Player selected by clicking.
        """
        return lambda event: self.on_session_clicked(event,clickedfn)


    def refresh_session_list(self):
        """
        Fill out the list of sessions if possible.
        """

        self.treeview.delete(*self.treeview.get_children())
        self.session_list = fetch_data_from_db("SELECT * FROM Session_List_View")
        if not self.session_list:
            return None

        selected_tree_id = None

        for (session_id, _player_id, player_name,
             session_start_epoch, session_stop_epoch,
             _category, hourly_rate) in self.session_list:
            if session_stop_epoch is not None:
                tags=("courier",)
                effective_session_stop_epoch = session_stop_epoch
            else:
                tags=("courier", "green_item")
                effective_session_stop_epoch = self.digital_clock.now_epoch()
            seconds = max(effective_session_stop_epoch - session_start_epoch, 0)
            session_duration = f"{seconds//3600:d}h {(seconds%3600)//60:02d}m"
            session_seat_fee = round(hourly_rate * seconds / 3600)
            tree_id = self.treeview.insert("", "end",
                                 text=player_name,
                                 values=(player_name,
                                         local_time(session_start_epoch),
                                         local_time(effective_session_stop_epoch),
                                         session_duration.rjust(8),
                                         locale.currency(session_seat_fee, grouping=True).rjust(8)),
                                 tags=tags)
            if session_id == self.selected_session_id:
                selected_tree_id = tree_id

        self.treeview.selection_clear()
        if selected_tree_id is not None:
            self.treeview.selection_set(selected_tree_id)

        if self.updating:
            if self.next_update:
                self.after_cancel(self.next_update)
            self.next_update = self.after(1000, self.refresh_session_list)
        else:
            self.next_update = None
        return self

    def start(self):
        """
        Start the clock running
        """
        self.updating = True
        self.refresh_session_list()

    def cancel_updating(self):
        """
        Cancel auto-updating.
        """
        self.updating = False
        if self.next_update:
            self.after_cancel(self.next_update)
            self.next_update = None

    def on_session_select(self, _event):
        """
        Session selected by clicking.
        """
        selected_items = self.treeview.selection()  # Get the IDs of selected items
        if selected_items is not None:
            for selected_item_id in selected_items:
                for (item_id, session) in zip(self.treeview.get_children(), self.session_list):
                    if item_id == selected_item_id:
                        item_data = self.treeview.item(item_id)  # Get the item's data dictionary
                        print(f"Selected item text: {item_data['text']}")  # Access the 'text' key
                        print(f"Selected item values: {item_data['values']}")  # Access the 'values' key
                        (item_player_name,
                         session_start_epoch_string,
                         effective_session_stop_epoch_string,
                         session_duration_string,
                         session_seat_fee_string) = item_data['values']
                        (session_id, session_player_id, session_player_name, session_start_epoch, session_stop_epoch, session_player_category_name, session_rate) = session
                        self.selected_session_id = session_id
        else:
            print("No item selected.")

    def switch_to_running_session(self, player_id):
        """
        Session selected by player_id, if running.
        """
        self.selected_session_id = None
        self.refresh_session_list()
        self.cancel_updating()
        found=False

        for (item_id, session) in zip(self.treeview.get_children(), self.session_list):
            item_data = self.treeview.item(item_id)
#            print(f"Item ID: {item_id}, Text: {item_data['text']}, Values: {item_data['values']}")
            (_item_player_name,
             _session_start_epoch_string,
             _effective_session_stop_epoch_string,
             _session_duration_string,
             _session_seat_fee_string) = item_data['values']
            (session_id,
             session_player_id, _session_player_name,
             _session_start_epoch, session_stop_epoch,
             _session_player_category_name, _session_rate) = session
#             print(f"""Item player name: {item_player_name} session: (
# session_id: {session_id} player_id: {player_id},
# session_player_name: {session_player_name}, session_start_epoch: {session_start_epoch},
# session_stop_epoch: {session_stop_epoch},
# session_player_category_name: {session_player_category_name},
# session_rate: {session_rate}
# )""")
            if player_id == session_player_id and session_stop_epoch is None:
                self.selected_session_id = session_id
                found = True
                break

        self.start()
        return found


    def session_clickedfn(self,
                          session_id, _player_id, player_name,
                          session_start_time_epoch, session_stop_time_epoch,
                          _session_duration, _session_seat_fee):
        print("selected session_id:", session_id, "player_name:", player_name)
        if session_stop_time_epoch is None:
            if True: # TODO: Ask first!  Also, prompt for session payout.
                print("Stopping session selected session_id:", session_id,
                      "player_name:", player_name)
                self.stop_session(session_id)



    def start_session(self, player_id, session_start_time):
        start_epoch=((self.digital_clock.now_epoch()+ 59) // 60) * 60
        start = max(start_epoch, session_start_time)
        send_data_to_db("INSERT INTO Session (Player_ID, Start_Epoch) VALUES (?, ?)",
                        (player_id,start))
        self.switch_to_running_session(player_id)



    def stop_session(self, session_id):
        stop_epoch = (self.digital_clock.now_epoch() // 60) * 60
        send_data_to_db("UPDATE Session SET Stop_Epoch = ? WHERE Session_ID == ?",
                        (stop_epoch, session_id))
        self.refresh_session_list()



def player_name_regular_clicked(player_id, name, balance, session_start_time, session_view):
    print("regular selected player_id:", player_id, "name:", name, "balance:", balance)
    if session_view.switch_to_running_session(player_id):
        return
    elif 0 <= balance:
        session_view.start_session(player_id, session_start_time)
    else:
        session_view.request_payment()


def player_name_control_clicked(player_id, name, balance, session_view):
    print("control selected player_id:", player_id, "name:", name, "balance:", balance)







carolina_font = create_carolina_font()
if carolina_font is None:
    sys.exit(1)


class SessionPanel(tk.Frame):
    """
    Frame specialize to lay out the session app
    """
    def __init__(self, master):
        """
        Simple initialization
        """
        super().__init__(master)
        self['bg']=CAROLINA_BLUE_HEX
        self.session_view = None
        self.digital_clock = None



    def populate(self):
        """
        Actual filling-out of the panel, that might fail along the way.
        """
        self.digital_clock = DigitalClock(self,digital_clock_resolution, CAROLINA_BLUE_HEX)

        self.carolina_label = self.create_carolina_label("Carolina Card Club")
        self.session_start_time = self.get_session_start_time()
        if self.session_start_time is None:
            self.close_window(1)
            return False

        self.session_start_time_label = \
            self.create_session_start_time_label(self.session_start_time)
        self.session_view = SessionView(self, self.digital_clock)
        self.player_name_listbox=self.create_player_name_listbox(self.session_start_time,
                                                                 self.session_view)

        if (self.digital_clock is None or
            self.carolina_label is None or
            self.session_start_time_label is None or
            self.session_view is None or
            self.player_name_listbox is None):
            self.close_window(1)
            return False

        self.close_button = self.create_session_close_button(self.session_view)
        self.bottom_banner_center = self.create_bottom_banner_center()
        self.bottom_banner_left = self.create_bottom_banner_left()

        if (self.close_button is None or
            self.bottom_banner_center is None or
            self.bottom_banner_left is None):
            self.close_window(1)
            return False


        self.grid_columnconfigure(0, weight=1)  # Column 0 expands
        self.grid_columnconfigure(1, weight=1)  # Column 1 expands
        self.rowconfigure(0, weight=0) # Row 3 expands
        self.rowconfigure(1, weight=0) # Row 3 expands
        self.rowconfigure(2, weight=0) # Row 3 expands
        self.rowconfigure(3, weight=0) # Row 3 expands
        self.rowconfigure(4, weight=1) # Row 3 expands
        self.rowconfigure(5, weight=0) # Row 3 expands
        self.rowconfigure(6, weight=0) # Row 3 expands


        self.digital_clock.            grid(row=0, column=1, sticky="e")

        self.carolina_label.           grid(row=1, column=0, columnspan=2, sticky='ew')

        self.session_start_time_label. grid(row=2, column=1, sticky="w")

        self.close_button.             grid(row=3, column=1, sticky="w")

        self.player_name_listbox.      grid(row=4, column=0, rowspan=1, sticky="nse")
        self.session_view.             grid(row=4, column=1, rowspan=1, sticky="nsw")

        self.bottom_banner_center.     grid(row=5, column=0, columnspan=2, sticky="ew")

        self.bottom_banner_left.       grid(row=6, column=0, sticky="w")

        self.digital_clock.start()
        self.session_view.refresh_session_list()

        return True


    def create_carolina_label(self, label_text):
        """
        Create the Carolina Card Club label at the top
        """
        # Create a custom font for the label
        # Replace "Old English Text MT" with an available font on your system
        # You might need to experiment or use a font like "Blackletter"
        # You can also adjust the size as needed
        # Create the big label
        return tk.Label(self, text=label_text, font=carolina_font,
                        bg=CAROLINA_BLUE_HEX, fg="white")

    def get_session_start_time(self):
        """
        Use the get_user_input popup to set the session start time
        """
        try:
            time_input = get_user_input(root, "Session Start Time", "Enter start time:",
                                        self.digital_clock.today_at_1930())
            if time_input is None or time_input == '':
                return None
            naive_time = datetime.datetime.strptime(time_input, "%Y-%m-%d %H:%M")
            local_aware_time = naive_time.replace(tzinfo=local_tz)
            unix_epoch=local_aware_time.timestamp()
            return int(unix_epoch)
        except tk.TclError:
            return None


    def create_session_start_time_label(self, start_time):
        """
        Create the start time label
        """
        if start_time is None:
            return None
        start_datetime = datetime.datetime.fromtimestamp(start_time)
        label_text = start_datetime.strftime("Session Start Time %Y-%m-%d %H:%M")

        return tk.Label(self, text=label_text, font=('Arial', 12),
                        background=CAROLINA_BLUE_HEX, fg="light gray")


    def create_player_name_listbox(self, session_start_time, session_view):
        """
        Create the player name listbox which accesses player-related functions
        """
        def regular_clickedfn(_player_name_listbox, player_id, name, balance):
            player_name_regular_clicked(player_id, name, balance, session_start_time, session_view)

        def control_clickedfn(_player_name_listbox, player_id, name, balance):
            player_name_control_clicked(player_id, name, balance, session_view)

        player_name_listbox = PlayerNameSelector(self, regular_clickedfn, control_clickedfn)

        if player_name_listbox.refresh_id_and_name_list() is None:
            return None

        return player_name_listbox


    def create_session_close_button(self, treeview):
        """
        Create the session close button, which kills the app cleanly by invoking close_window
        """
        if treeview is None:
            return None
        self.update_idletasks()
        treeview_width = treeview.winfo_width()
        return tk.Button(self, text="Close Session",
                         width=round(treeview_width/10), command=self.close_window)



    def create_bottom_banner_center(self):
        """
        Create the bottom banner centerpiece, for decoration and spacing
        """
        return tk.Label(self, text='♠️♥️♦️♣️', bg=CAROLINA_BLUE_HEX, fg="white", font=(None,16))


    def create_bottom_banner_left(self):
        """
        Create the bottom banner copyright
        """
        return tk.Label(self, text='Copyright (c) 2025 Scott Marks',
                        bg=CAROLINA_BLUE_HEX, fg="black", font=("Arial",8))


    def stop_updating(self):
        """
        Stop things that are updating
        from updating for clean exit
        """
        if self.digital_clock:
            self.digital_clock.cancel_updating()
        if self.session_view:
            self.session_view.cancel_updating()



    def close_window(self, ex_cd=0):
        """
        Close the main window.
        Stop the updating to end the program cleanly.
        """
        self.stop_updating()
        exit_code = ex_cd
        root.update_idletasks()
        root.destroy()



def show_session_panel():
    """
    Show and lay out the main session panel, the main program window.
    """
    # Define the hex code for Carolina Blue

    root.title("Carolina Card Club Session")
    root['bg']=CAROLINA_BLUE_HEX
    root.geometry('680x800')
    root.grid_rowconfigure(0, weight=1)  # Make row 0 expand vertically
    root.grid_columnconfigure(0, weight=1) # Make column 0 expand horizontally

    session_panel = SessionPanel(root)
    if session_panel.populate():
        session_panel.grid(row=0, column=0, sticky="nsew")
    return session_panel

if __name__ == "__main__":
    session_panel = show_session_panel()

    root.mainloop()

    session_panel.stop_updating()

    if exit_code != 0:
        sys.exit(exit_code)
