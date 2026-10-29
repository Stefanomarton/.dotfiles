pragma Singleton
import Quickshell
import QtQuick

QtObject {
    // === Workspace Picker ===
    readonly property var startupWorkspaces: []        // Named workspaces to create on shell load, e.g., ["thesis", "work"]

    // Workspaces to exclude from picker (by exact name).
    // NOTE: all Hyprland "special:" workspaces are always hidden automatically,
    // so they don't need to be listed here.
    readonly property var pickerExcludedWorkspaces: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

    // Windows on these workspaces are excluded from window picker
    // Use strings: "1", "2", "special:scratch", etc. A trailing "*" matches a prefix.
    readonly property var windowPickerExcludedWorkspaces: ["special*", "w11"]

    function isWindowWorkspaceExcluded(ws) {
        return windowPickerExcludedWorkspaces.some(function(ex) {
            return ex.endsWith("*") ? ws.startsWith(ex.slice(0, -1)) : ws === ex
        })
    }

    // Target monitor for "move workspace" action (Ctrl+Enter in picker)
    // "auto" = move to first available other monitor
    // Or a monitor name ("DP-2") or model ("Mi Monitor": same screen whatever DP-x the laptop dock gives it)
    readonly property string moveWorkspaceTargetMonitor: "Mi Monitor"

    // Screen of the Smart picker and Exposé, like the other popups: the first of these (name or
    // model) that is connected: the G9 on the desktop and a docked laptop, else the laptop
    // panel (also at TM, with an HDMI monitor); otherwise the first screen.
    readonly property var pickerMonitors: ["Odyssey G91F", "eDP-1"]
    function pickerScreen() {
        for (var i = 0; i < pickerMonitors.length; i++) {
            var want = pickerMonitors[i]
            var s = Quickshell.screens.find(function(x) { return x.name === want || x.model === want })
            if (s) return s
        }
        return Quickshell.screens[0]
    }

    // Smart picker: workspace mini-map preview
    // Shows a scaled map of the highlighted workspace's window layout in a pane
    // beside the picker as you navigate.
    readonly property bool pickerWorkspacePreview: true
    // When true, each window tile shows a live capture of the window (Hyprland
    // toplevel export). When false, tiles show only the app icon (option 1).
    readonly property bool pickerWorkspacePreviewLive: true
    // Workspace preview sits beside the list (below on narrow screens). The mini-map keeps the monitor's
    // aspect ratio, fitted within these max dimensions (height is the usual
    // limit on a wide monitor; width caps it on a tall/square one).
    readonly property int pickerPreviewHeight: 520
    readonly property int pickerPreviewWidth: 2400
    // Rows of the Smart list (fixed height, so nothing moves while typing)
    readonly property int pickerSmartVisibleRows: 8

    // Picker UI
    readonly property int pickerWidth: Math.round(750 * Theme.textScale)   // grows with the text (Theme.textScale)
    readonly property int pickerFontSize: Theme.fontSize
    readonly property int pickerItemHeight: Math.round(60 * Theme.textScale)   // grows with the text (Theme.textScale)
    readonly property int pickerBorderRadius: Theme.radius
    readonly property int pickerInputHeight: Math.round(44 * Theme.textScale)   // grows with the text (Theme.textScale)
}
