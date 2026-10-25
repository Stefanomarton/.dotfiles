pragma Singleton
import Quickshell
import QtQuick

QtObject {
    // Main screen: the first of these that is connected (name or model), otherwise the first
    // screen. G9 on the desktop and on a docked laptop, else the laptop panel; never the Xiaomi.
    readonly property var monitors: ["Odyssey G91F", "eDP-1"]

    readonly property int width: 1500        // menu card; entries flow in columns
    readonly property int columns: 3        // sections side by side
    readonly property int bottomMargin: Theme.edge * 2   // which-key style: near the bottom edge
    readonly property int fontSize: Theme.fontSize
    readonly property int keyWidth: 130      // key column ("Ctrl+Shift+S" fits)

    // Hold Super this long (ms) and the menu opens; quicker Super+key combos never see it
    readonly property int holdDelay: 50

    // When holding Super must NOT open the menu:
    readonly property int moveTolerance: 20      // px the pointer moved meanwhile (Super+drag/resize)
    readonly property var blockers: [            // these panels are showing and have the keyboard
        "smart-picker",
        "expose", "notifications-history", "tofi", "launcher"
    ]
    // Opened by holding Super: after Super is released, closes by itself if no key comes (ms)
    readonly property int autoClose: 500
    readonly property int chordAutoClose: 1500    // second level (after Shift+L): more time to read

    // Written by modules/menu.lua at every Hyprland config load
    readonly property string menuFile: Quickshell.env("XDG_RUNTIME_DIR") + "/whichkey.json"
}
