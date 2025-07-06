import tkinter as tk
from tkinter import messagebox
import sqlite3

def fetch_data_from_db():
    """Fetches data from an SQLite database."""
    conn = None
    try:
        conn = sqlite3.connect('CarolinaCardClub.db')
        cursor = conn.cursor()
        cursor.execute("""SELECT p.ID, p.Played_Super_Bowl, IFNULL(p.NickName, p.Name), p.Name, p.Email_address, p.Phone_number, p.Other_phone_number_1, p.Other_phone_number_2, p.Other_phone_number_3, p.Prepaid_balance, p.Flag, c.Name, c.Hourly_Rate FROM Player as p INNER JOIN Player_Category as c WHERE p.Player_Category_ID = c.ID""")
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

def show_popup_list():
    """Displays a popup list populated with data from the database."""
    data_list = fetch_data_from_db()
    if not data_list:
        messagebox.showinfo("No Data", "No items found in the database.")
        return

    popup = tk.Toplevel()
    popup.title("Select an Item")

    names = [item[2] for item in data_list] # Extract the names into a list
    listbox = tk.Listbox(popup)
    for item in names:
        listbox.insert(tk.END, item)
    listbox.pack(padx=10, pady=10)

    def on_select(event):
        selected_index = listbox.curselection()
        if selected_index:
            selected_item = listbox.get(selected_index[0])
            messagebox.showinfo("Selected Item", f"You selected: {selected_item}")
            messagebox.showinfo(f"Data for {selected_item}",  data_list[selected_index[0]] );
            popup.destroy()

    listbox.bind('<<ListboxSelect>>', on_select)

    # Optional: Add a close button
    close_button = tk.Button(popup, text="Close", command=close_window)
    close_button.pack(pady=5)

    popup.grab_set() # Make the popup modal
    popup.wait_window() # Wait for the popup to close before continuing


# Example usage:
if __name__ == "__main__":

    root = tk.Tk()
    root.withdraw() # Hide the main window

    show_popup_list()
