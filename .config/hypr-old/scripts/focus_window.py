#!/usr/bin/env python3
import pickle
from pathlib import Path
import sys
import argparse
import hyprpython as hp
import os
from plyer import notification


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("window_class", help="cycle focus to windows with window_class")
    args = parser.parse_args()

    client = hp.Clients

    client_ordered = client.byFocusID()

    current_window = client.focused()

    with open("/tmp/last_focus_adress.pkl", "wb") as file:
        pickle.dump(current_window, file)

    emacs_windows = [
        windows for windows in client_ordered if windows.wm_class == args.window_class
    ]

    focus_list = [w for w in emacs_windows if w.workspace.id > 0]

    if current_window.wm_class != args.window_class:
        file_path = f"/tmp/{args.window_class}.pkl"
        if os.path.exists(file_path):
            os.remove(file_path)
        hp.Hyprctl.focus_window(focus_list[0].address)

        # Serialize and write the list of objects to a file
        with open(f"/tmp/{args.window_class}.pkl", "wb") as file:
            pickle.dump(focus_list, file)
    else:
        # Read the list of objects from the file
        with open(f"/tmp/{args.window_class}.pkl", "rb") as file:
            loaded_items = pickle.load(file)

            index = next(
                (
                    i
                    for i, item in enumerate(loaded_items)
                    if item.address == current_window.address
                ),
                None,
            )

        if index == len(loaded_items) - 1:
            hp.Hyprctl.focus_window(loaded_items[0].address)

            file_path = f"/tmp/{args.window_class}.pkl"
            if os.path.exists(file_path):
                os.remove(file_path)

            # Serialize and write the list of objects to a file
            with open(f"/tmp/{args.window_class}.pkl", "wb") as file:
                pickle.dump(focus_list, file)

        if loaded_items[index].address == current_window.address:

            hp.Hyprctl.focus_window(loaded_items[index + 1].address)


if __name__ == "__main__":
    main()
