pragma Singleton
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// macOS Exposé-style overview: every workspace as a live mini-map, grouped by
// monitor. Reuses WorkspaceManager's fetched data (no duplicate polling).
QtObject {
    id: manager

    property bool visible: false

    // Monitors to render sections for, and the workspaces on each.
    readonly property var monitors: WorkspaceManager.monitorsGeom

    function workspacesForMonitor(monId) {
        return WorkspaceManager.workspaces.filter(function(ws) {
            if (ws.name === "special" || ws.name.startsWith("special:")) return false
            return ws.monitorID === monId
        })
    }

    function windowsForWorkspace(name) { return WorkspaceManager.windowsForWorkspace(name) }

    function refresh() {
        WorkspaceManager.refreshWorkspaces()
        WorkspaceManager.refreshMonitors()
    }

    // Re-fetch shortly after a drag so tiles settle into their new workspace.
    property Timer refreshTimer: Timer {
        interval: 120
        onTriggered: manager.refresh()
    }

    property Process moveProcess: Process { running: false }
    property Process actionProcess: Process { running: false }

    // Drag-drop: move window to workspace WITHOUT following (view stays put, so
    // the overview doesn't jump). Then refresh the tiles in place.
    function moveWindow(address, wsName) {
        if (!address || !wsName) return
        moveProcess.running = false
        moveProcess.command = ["hyprctl", "dispatch",
            "hl.dsp.window.move({ workspace = 'name:" + wsName + "', window = 'address:" + address + "', follow = false })"]
        moveProcess.running = true
        refreshTimer.restart()
    }

    // Click a window: focus it (jumps to its workspace) and close the overview.
    function focusWindow(address) {
        if (!address) { hide(); return }
        actionProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + address + "' })"]
        actionProcess.running = true
        hide()
    }

    // Click an empty part of a workspace cell: switch to it and close.
    function switchTo(wsName) {
        if (!wsName) { hide(); return }
        actionProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 'name:" + wsName + "' })"]
        actionProcess.running = true
        hide()
    }

    function show() { refresh(); visible = true }
    function hide() { visible = false }
    function toggle() { visible ? hide() : show() }
}
