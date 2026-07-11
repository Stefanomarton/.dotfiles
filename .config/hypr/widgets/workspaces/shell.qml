import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {

    // GlobalShortcut for workspace picker
    GlobalShortcut {
        name: "workspaces"
        description: "Toggle workspace picker"
        onPressed: WorkspaceManager.toggle()
    }

    // GlobalShortcut for window picker
    GlobalShortcut {
        name: "windows"
        description: "Toggle window picker"
        onPressed: WindowManager.toggle()
    }

    // GlobalShortcut for smart picker (unified)
    GlobalShortcut {
        name: "smart"
        description: "Toggle smart unified picker"
        onPressed: SmartPickerManager.toggle()
    }

    // Workspace picker popup
    WorkspacePicker {}

    // Window picker popup
    WindowPicker {}

    // Smart unified picker popup
    SmartPicker {}
}
