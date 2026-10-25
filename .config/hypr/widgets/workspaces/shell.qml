import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {

    // Smart picker (Super+S): workspaces, windows, apps, commands
    GlobalShortcut {
        name: "smart"
        description: "Toggle the smart picker"
        onPressed: SmartPickerManager.toggle()
    }

    // Exposé overview
    GlobalShortcut {
        name: "expose"
        description: "Toggle Exposé-style workspace overview"
        onPressed: ExposeManager.toggle()
    }

    // Close every picker (Super+Esc, "pulisci schermo" in modules/menu.lua)
    GlobalShortcut {
        name: "pickers-close"
        description: "Close every picker"
        onPressed: {
            SmartPickerManager.hide()
            ExposeManager.hide()
            clipboard.hide()
        }
    }

    // Clipboard history (Super+V)
    GlobalShortcut {
        name: "clipboard"
        description: "Toggle the clipboard picker"
        onPressed: clipboard.toggle()
    }

    SmartPicker {}
    Expose {}
    ClipboardPicker { id: clipboard }
}
