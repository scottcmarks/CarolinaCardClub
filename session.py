#!/usr/bin/env python3
import tkinter as tk
from tkinter import messagebox, ttk
import tkinter.font as tkFont # Import the font module for custom fonts
import sqlite3
import datetime
import time

#Useful color chart at https://cs111.wellesley.edu/archive/cs111_fall14/public_html/labs/lab12/tkintercolor.html
root = tk.Tk()

def fetch_data_from_db():
    """Fetches data from an SQLite database."""
    conn = None
    try:
        conn = sqlite3.connect('CarolinaCardClub.db')
        cursor = conn.cursor()
        cursor.execute("""SELECT p.ID,
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
                                WHERE p.Player_Category_ID = c.ID""")
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

class InputPopup(tk.Toplevel):
    def __init__(self, parent, title, prompt, default=None):
        super().__init__(parent)
        self.title(title)
        self.grab_set()  # Make the popup modal

        self.user_input = None

        ttk.Label(self, text=prompt).pack(padx=10, pady=5)
        self.entry = ttk.Entry(self)
        self.entry.pack(padx=10, pady=5)
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

class SessionStartTimeInputPopup(InputPopup):
    def __init__(self):
        super().__init__(root, "Session Start Time", "Enter start time:", today_at_1930())

def show_custom_input():
    popup = InputPopup(root, "Custom Input", "Enter your data:")
    root.wait_window(popup) # Wait for the popup window to close

    if popup.user_input is not None:
        print("User entered:", popup.user_input)
    else:
        print("Popup closed without input.")

digital_clock_resolution="minutes"
if digital_clock_resolution == "seconds" :
    digital_clock_time_format = '%H:%M:%S'
    digital_clock_delay = 1000
elif digital_clock_resolution == "minutes" :
    digital_clock_time_format = '%H:%M'
    digital_clock_delay = 60 * 1000
else:
    print("Unrecognized digital clock resolution", digital_clock_resolution)
    exit( 1 )

def update_time(digital_clock):
    """Updates the digital_clock label with the current time."""
    # Get the current time and format it
    string_time = time.strftime(digital_clock_time_format)  # Example: 15:03:00
    digital_clock.config(text=string_time)  # Update the label's text

    # Schedule the update_time function to run again after 1000 milliseconds (1 second)
    digital_clock.after(digital_clock_delay, update_time, digital_clock)

def draw_session_panel_background():
    # Define the hex code for Carolina Blue
    carolina_blue_hex = "#4B9CD3"
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
        print("Warning: 'Academy Engraved' not found, using Arial (bold) as a fallback.") # Add a warning

    # Create the small digital clock
    digital_clock = tk.Label(root, font=('Arial', 20), background=carolina_blue_hex, foreground='light gray')
    digital_clock.grid(row=0,column=1,pady=10)
    update_time(digital_clock)

    # Create the big label
    label_text = "Carolina Card Club"
    carolina_label = tk.Label(root, text=label_text, font=carolina_font,
                              bg=carolina_blue_hex, fg="white")

    # Place the label in the grid, spanning the available width (sticky='ew')
    carolina_label.grid(row=1, column=0, columnspan=2, sticky='ew', pady=20)




def configure_session_panel_grid():
    # Use the grid layout manager to place the label
    # Configure the column to expand when the window is resized
    root.grid_columnconfigure(0, weight=1)



def set_session_start_time():
    popup = SessionStartTimeInputPopup()
    root.wait_window(popup) # Wait for the popup window to close
    return popup.user_input



def show_session_panel():
    # Define the hex code for Carolina Blue

    root.title("Carolina Card Club Session")
    root.geometry('640x480')
    configure_session_panel_grid()

    draw_session_panel_background()

    # Add more widgets here if needed

    sessionStartTime = set_session_start_time()
    if sessionStartTime is not None:
        print("Session Start Time set to:", sessionStartTime)
    else:
        print("Popup closed without input.")
        return

    root.mainloop()


if __name__ == "__main__":
    show_session_panel()
