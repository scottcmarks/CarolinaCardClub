#!/usr/bin/env python3
# Copyright (c) 2025 Scott Marks
"""
Run a session management module for Carolina Card Club
"""

import tkinter as tk
import datetime
from zoneinfo import ZoneInfo
from enum import Enum
from inputpopup import *

local_tz = ZoneInfo("America/New_York")

class ClockResolution(Enum):
    """ Enum for selecting clock resolution """
    SECONDS = 1000
    MINUTES = SECONDS * 60

digital_clock_resolution = ClockResolution.SECONDS

HICKORY_CLICKABLE_CLOCK = True

class DigitalClock(tk.Label):
    """
       Label specialized to show time
       and allow interaction to reset clock
    """

    def __init__(self, parent, resolution, bgcolor):
        super().__init__(parent,
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
        self.running = False
        self.update_time()

    def update_time(self):
        """
        Updates the digital_clock label with the current time.
        """

        # Get the current time and format it

        self.config(text=self.now())  # Update the label's text

        one_millisecond_in_microseconds = 1000
        one_second_in_milliseconds = 1000


        # Get the current datetime object
        current_datetime = datetime.datetime.now(local_tz)

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
        delay_in_milliseconds = max ( ( next_tick_time_in_seconds * one_second_in_milliseconds )
                                         -  current_time_in_milliseconds ,
                                      1 )

        # Schedule the update_time function to run again after 1000 milliseconds (1 second)
        if self.running:
            if self.next_update:
                self.after_cancel(self.next_update)
            self.next_update = self.after(delay_in_milliseconds, self.update_time)
        else:
            self.next_update = None

    def start(self):
        """
        Start the clock running
        """
        self.running = True
        self.update_time()

    def cancel_updating(self):
        """
        Stop the clock updating.
        Do this before stopping the program to avoid a messy error on sys.exiting.
        """
        self.running = False
        if self.next_update:
            self.after_cancel(self.next_update)
            self.next_update = None

    def reset_clock(self, event):
        """
        Reset the system clock
        """
        clock_time_from_user = self.get_clock_time()
        actual_local_clock_time = int(datetime.datetime.now(local_tz).timestamp())
        self.clock_offset = clock_time_from_user - actual_local_clock_time
        self.update_time()

    def get_clock_time(self):
        """
        Use the get_user_input popup to set the clock time
        """
        try:
            time_input = get_user_input(self, "Set Clock Time", "Enter clock time:", self.now())
            if time_input is None or time_input == '':
                return None
            naive_time = datetime.datetime.strptime(time_input, "%Y-%m-%d " + self.digital_clock_time_format )
            local_aware_time = naive_time.replace(tzinfo=local_tz)
            unix_epoch=local_aware_time.timestamp()
            return int(unix_epoch)
        except tk.TclError:
            return None

    def now_datetime(self):
        """
        Get the current time in the current digital clock time format
        """
        return datetime.datetime.now(local_tz)+datetime.timedelta(seconds=self.clock_offset)


    def now_epoch(self):
        """
        Get the current time in the current digital clock time format
        """
        return int(self.now_datetime().timestamp())


    def now(self):
        """
        Get the current time in the current digital clock time format
        """
        return self.now_datetime().strftime("%Y-%m-%d "+self.digital_clock_time_format)


    def today_at_1930(self):
        """
        Compute the time for today at 7:30 PM for the default session start time
        """
        # Get today's date
        today = self.now_datetime()

        # Create a time object for 7:30 PM
        time_730pm = datetime.time(19, 30)  # Use 24-hour format for the time object

        # Combine the date and time into a datetime object
        datetime_730pm = datetime.datetime.combine(today, time_730pm)

        # Format the datetime object as a string
        # %I for 12-hour clock, %M for minutes, %p for AM/PM
        time_string = datetime_730pm.strftime("%Y-%m-%d %H:%M")
        return time_string


if __name__ == "__main__":
    root = tk.Tk()
    root.title("Digital Clock Test")
    root['bg']='ivory3'
    root.geometry('240x120')

    digital_clock = DigitalClock(root,digital_clock_resolution, 'slate gray')

    digital_clock.pack(pady=40)

    digital_clock.start()

    root.mainloop()
