#!/usr/bin/env python3
# Copyright (c) 2025 Scott Marks
"""
InputPopup class with input string entry and Cancel and OK buttons
Responds to Enter/Return as OK and Escape as Cancel
"""

import tkinter as tk
from tkinter import ttk, messagebox

class Popup(tk.Toplevel):
    """
    Specialize TopLevel to popup correctly even in macOS 11
    """
    def __init__(self, parent, title=None):
#debug        super().__init__(parent)
        super().__init__(parent)
        if title:
            self.title(title)
        # Next two lines essential to work on macOS 11.7, not necessary on current macOS
        self.lift() # Bring it to the front
        self.attributes('-topmost', True) # Keep it on top
        self.grab_set()  # Make the popup modal
        # Center the popup over the parent window (if available)
        if parent:
            parent.update_idletasks() # Ensure parent geometry is calculated
            x = parent.winfo_x() + (parent.winfo_width() // 2) - (self.winfo_width() // 2)
            y = parent.winfo_y() + (parent.winfo_height() // 2) - (self.winfo_height() // 2)
            self.geometry(f"+{x}+{y}")
            self.transient(parent)  # Keep popup on top of the parent window


class InputPopup(Popup):
    """
    Specialize TopLevel to package a user Entry with
    a Cancel Button and an OK Button
    """
    def __init__(self, parent, title, prompt, default=None):
#debug        super().__init__(parent)
        super().__init__(parent, title)
        ttk.Label(self, text=prompt).pack(padx=10)

        self.user_input = None

        self.entry = ttk.Entry(self)
        self.entry.pack(padx=10)
        self.entry.focus_set()  # Set focus to the entry field
        if default is not None:
            self.entry.insert(0,default)

        # Create the buttons and pack them into the frame
        button_frame = ttk.Frame(self)
        button_frame.pack(pady=10) # Pack the frame in the popup

        self.button1 = ttk.Button(button_frame, text="Cancel", command=self.on_cancel)
        self.button2 = ttk.Button(button_frame, text="OK",     command=self.on_ok, default='active')
        self.button1.pack(side=tk.LEFT, padx=5) # Place Button 1 to the left
        self.button2.pack(side=tk.LEFT, padx=5) # Place Button 2 to the left (next to Button 1)
         # Bind the spacebar event to the Toplevel window
        self.bind('<space>', self.on_spacebar_press)
         # Bind the Enter/Return event to the Toplevel window
        self.bind('<Return>', self.on_enter_press)
        self.bind('<Escape>', self.on_escape_press)


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
        current_content =self.entry.get()
        # Check if the string is not empty and its last character is a space
        if current_content and current_content[-1] == ' ':
            self.entry.delete(self.entry.index(tk.END) - 1) # Delete the character at the position just before the end
        self.button2.invoke()

    def on_enter_press(self, _event):
        """
        Enter is an assistive shortcut for button2=OK.
        """
        self.button2.invoke()

    def on_escape_press(self, _event):
        """
        Escape is an assistive shortcut for button1=Cancel.
        """
        self.button1.invoke()

    def done(self):
        """
        Clean up this instance.
        """
        self.unbind('<Escape>')
        self.unbind('<Return>')
        self.unbind('<space>')
        self.destroy()


def get_user_input(parent, label, prompt, default):
    """
    Use an InputPopup to get a user input
    """
    popup = InputPopup(parent, label, prompt, default)
    parent.wait_window(popup) # Wait for the popup window to close
    return popup.user_input

if __name__ == "__main__":
    root = tk.Tk()
    root.title("Input Popup Test")
    root['bg']='ivory3'
    root.geometry('340x400')

    answer = get_user_input(root,
                            "Input from the User",
                            "Type something",
                            "replace this with something smart!")

    if answer:
        messagebox.showinfo("Answered", f"Your answer was \"{answer}\"")
    else:
        messagebox.showerror("Cancelled", f"No answer?!")

    root.destroy()
