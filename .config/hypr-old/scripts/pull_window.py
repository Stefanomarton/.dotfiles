#!/usr/bin/env python3
import hyprpyton as hp
import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("window_class", help="pull windows with window_class")
    args = parser.parse_args()

    activeWorkspace = hp.Workspaces.current()

    clients = hp.Clients.byFocusID()

    class_windows = [
        windows
        for windows in clients
        if windows.wm_class == args.window_class
        and windows.workspace.id != activeWorkspace.id
    ]

    if class_windows:
        hp.Hyprctl.move_to_workspace_silent(
            class_windows[0].address, activeWorkspace.id
        )
        hp.Hyprctl.focus_window(class_windows[0].address)


if __name__ == "__main__":
    main()
