#!/usr/bin/env python3
import tkinter as tk
from tkinter import messagebox, ttk
import tkinter.font as tkFont # Import the font module for custom fonts
import sqlite3
import datetime
import time
from enum import Enum

#Useful color chart at https://cs111.wellesley.edu/archive/cs111_fall14/public_html/labs/lab12/tkintercolor.html
carolina_blue_hex = "#4B9CD3"

class ClockResolution(Enum):
    SECONDS = 1000
    MINUTES = SECONDS * 60

digital_clock_resolution = ClockResolution.MINUTES

player_data_query = """
SELECT p.ID,
       p.Played_Super_Bowl,
       IFNULL(p.NickName, p.Name),
       p.Name,
       p.Email_address,
       p.Phone_number,
       p.Other_phone_number_1,
       p.Other_phone_number_2,
       p.Other_phone_number_3,
       p.Prepaid_balance,
       p.Flag,
       c.Name,
       c.Hourly_Rate
FROM Player as p
       INNER JOIN
     Player_Category as c
       WHERE p.Player_Category_ID = c.ID
"""


non_flagged_player_data_query = """
SELECT p.ID,
       p.Played_Super_Bowl,
       IFNULL(p.NickName, p.Name),
       p.Name,
       p.Email_address,
       p.Phone_number,
       p.Other_phone_number_1,
       p.Other_phone_number_2,
       p.Other_phone_number_3,
       p.Prepaid_balance,
       p.Flag,
       c.Name,
       c.Hourly_Rate
FROM Player as p
       INNER JOIN
     Player_Category as c
       WHERE p.Player_Category_ID = c.ID
         AND p.Flag IS NULL
"""




root = tk.Tk()
digital_clock = None


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

def close_window():
    root.destroy()
    exit(0)

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
        self.bind("<Button-1>", self.reset_clock)
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
        current_time_in_milliseconds = ( current_time_in_microseconds + (one_millisecond_in_microseconds // 2) ) // one_millisecond_in_microseconds
        # Compute the next second's tick
        next_tick_time_in_seconds = (current_time_in_milliseconds + one_second_in_milliseconds) // one_second_in_milliseconds

        # Delay for that in milliseconds
        delay_in_milliseconds = next_tick_time_in_seconds * one_second_in_milliseconds - current_time_in_milliseconds


        # Schedule the update_time function to run again after 1000 milliseconds (1 second)
        self.after(delay_in_milliseconds, self.update_time)


    def now(self):
        # Get the current time
        time_now = datetime.datetime.now()
        time_string = time_now.strftime("%Y-%m-%d "+self.digital_clock_time_format)
        return time_string


    def today_at_1930(self):
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


    def reset_clock(self, event):
        print("RESET CLOCK", event, self.resolution, self.digital_clock_time_format)
        self.update_time()



class SessionStartTimeInputPopup(InputPopup):
    def __init__(self):
        super().__init__(root, "Session Start Time", "Enter start time:", DigitalClock.today_at_1930(self))


class ClockSetTimeInputPopup(InputPopup):
    def __init__(self):
        super().__init__(root, "Set Clock Time", "Enter clock time:", DigitalClock.now(self))



def draw_session_panel_background():
    # Define the hex code for Carolina Blue
    root['bg']=carolina_blue_hex

    # Create a custom font for the label
        # Replace "Old English Text MT" with an available font on your system
        # You might need to experiment or use a font like "Blackletter"
        # You can also adjust the size as needed
    try:
        carolina_font = tkFont.Font(family="Academy Engraved LET", size=48)
    except tkFont.TclError:
        # Fallback to a different font if Old English is not available
        carolina_font = tkFont.Font(family="Arial, size=48, weight=bold")
        print("Warning: 'Academy Engraved LET' not found, using Arial (bold) as a fallback.") # Add a warning

    # Create the small digital clock
    digital_clock = DigitalClock(digital_clock_resolution, carolina_blue_hex)
    digital_clock.grid(row=0,column=3)


    # Create the big label
    label_text = "Carolina Card Club"
    carolina_label = tk.Label(root, text=label_text, font=carolina_font,
                              bg=carolina_blue_hex, fg="white")

    # Place the label in the grid, spanning the available width (sticky='ew')
    carolina_label.grid(row=1, column=0, columnspan=3, sticky='ew')




def configure_session_panel_grid():
    # Use the grid layout manager to place the label
    # Configure the column to expand when the window is resized
    root.grid_columnconfigure(0, weight=1)



def set_session_start_time():
    popup = SessionStartTimeInputPopup()
    root.wait_window(popup) # Wait for the popup window to close
    return popup.user_input



def show_session_start_time(sessionStartTime):
    # Create the start time label
    label_text = "Session Start Time " + sessionStartTime
    start_time_label = tk.Label(root, text=label_text, font=('Arial', 12),
                                background=carolina_blue_hex, fg="light gray")

    # Place the label in the grid, spanning the available width (sticky='ew')
    start_time_label.grid(row=2, column=1)

    print("Session Start Time set to", sessionStartTime)
    return



def show_session_close_button():
#    style = ttk.Style()

    # Configure the 'TButton' style
    # You can use a specific theme to ensure the style applies
    # style.theme_use('clam')  # Example theme
#    style.configure('TButton', background='blue', foreground='white', font=('Arial', 12))

    # Create a ttk Button and apply the style
    close_button = ttk.Button(root, text="Close Session",command=close_window)
    close_button.grid(row=2,column=2)


def show_player_sessions():
    data_list = fetch_data_from_db(non_flagged_player_data_query)
    if not data_list:
        messagebox.showinfo("No Data", "No items found in the database.")
        return


    names = [item[2] for item in data_list] # Extract the names into a list
    listbox = tk.Listbox(root)
    for item in names:
        listbox.insert(tk.END, item)
    listbox['bg']=carolina_blue_hex
    listbox.grid(row=3,column=0)
    listbox.selection_clear(0,tk.END)

    def on_select(event):
        selected_index = listbox.curselection()
        if selected_index:
            selected_item = listbox.get(selected_index[0])
        else:
            selected_item = None

    listbox.bind('<<ListboxSelect>>', on_select)


def show_session_panel():
    # Define the hex code for Carolina Blue

    root.title("Carolina Card Club Session")
    root.geometry('640x480')
    configure_session_panel_grid()

    draw_session_panel_background()

    # Add more widgets here if needed

    sessionStartTime = set_session_start_time()
    if sessionStartTime is None:
        print("Popup closed without input.")
        return

    show_session_start_time(sessionStartTime)

    show_session_close_button()

    show_player_sessions()

    root.mainloop()


if __name__ == "__main__":
    show_session_panel()
