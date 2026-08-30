pragma Singleton
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Dedicated picker: move the currently-focused window to a chosen workspace.
// Enter = move (stay), Shift+Enter = move + follow. Reuses WorkspaceManager's
// fetched workspace/window data so there is no duplicate hyprctl polling here.
QtObject {
    id: manager

    property bool pickerVisible: false
    property string filterText: ""
    property int selectedIndex: 0

    // The window that was focused when the picker opened (the move target).
    property string currentWindowAddress: ""
    property string currentWindowTitle: ""
    // Workspace to return to after a non-following move.
    property string originalWorkspace: ""

    // All real workspaces (special ones hidden), fuzzy-filtered. Numbered
    // workspaces are kept — unlike the switch picker — since they are valid
    // move targets.
    readonly property var filteredWorkspaces: {
        var list = WorkspaceManager.workspaces.filter(function(ws) {
            return ws.name !== "special" && !ws.name.startsWith("special:")
        })
        if (!filterText) return list
        var lower = filterText.toLowerCase()
        return list.filter(function(ws) { return ws.name.toLowerCase().includes(lower) })
    }

    // Preview helpers delegate to WorkspaceManager's cached geometry.
    function windowsForWorkspace(name) { return WorkspaceManager.windowsForWorkspace(name) }
    function monitorForWorkspace(name) { return WorkspaceManager.monitorForWorkspace(name) }

    // Capture the focused window before the overlay steals keyboard focus.
    property Process activeWindowProcess: Process {
        command: ["hyprctl", "activewindow", "-j"]
        running: false
        property string buffer: ""
        stdout: SplitParser { onRead: data => activeWindowProcess.buffer += data }
        onRunningChanged: {
            if (!running) {
                try {
                    var w = JSON.parse(activeWindowProcess.buffer)
                    manager.currentWindowAddress = w.address ?? ""
                    manager.currentWindowTitle = w.title ?? ""
                } catch (e) {
                    manager.currentWindowAddress = ""
                    manager.currentWindowTitle = ""
                }
                activeWindowProcess.buffer = ""
            }
        }
    }

    property Process moveProcess: Process {
        running: false
        onRunningChanged: if (!running) manager.hide()
    }

    // Move the captured window to wsName. follow=false moves but returns the
    // view to the original workspace; follow=true switches to the target and
    // refocuses the window there.
    function moveToWorkspace(wsName, follow) {
        var addr = currentWindowAddress
        if (!wsName || !addr) { hide(); return }
        var cmds = "hl.dispatch(hl.dsp.window.move({ workspace = 'name:" + wsName + "', window = 'address:" + addr + "' }))"
        if (follow) {
            cmds += "; hl.dispatch(hl.dsp.focus({ workspace = 'name:" + wsName + "' }))"
            cmds += "; hl.dispatch(hl.dsp.focus({ window = 'address:" + addr + "' }))"
        } else {
            cmds += "; hl.dispatch(hl.dsp.focus({ workspace = 'name:" + originalWorkspace + "' }))"
        }
        moveProcess.command = ["hyprctl", "eval", cmds]
        moveProcess.running = true
    }

    // Move to the highlighted workspace, or to the typed name if nothing matches.
    function moveToSelected(follow) {
        var f = filteredWorkspaces
        if (f.length > 0 && selectedIndex < f.length) {
            moveToWorkspace(f[selectedIndex].name, follow)
        } else if (filterText.trim()) {
            moveToWorkspace(filterText.trim(), follow)
        }
    }

    function show() {
        filterText = ""
        selectedIndex = 0
        originalWorkspace = Hyprland.activeWorkspace?.name ?? ""
        currentWindowAddress = ""
        currentWindowTitle = ""
        activeWindowProcess.buffer = ""
        activeWindowProcess.running = true
        WorkspaceManager.refreshWorkspaces()
        WorkspaceManager.refreshMonitors()
        pickerVisible = true
    }

    function hide() {
        pickerVisible = false
        filterText = ""
    }

    function toggle() { pickerVisible ? hide() : show() }

    onFilteredWorkspacesChanged: {
        if (selectedIndex >= filteredWorkspaces.length)
            selectedIndex = Math.max(0, filteredWorkspaces.length - 1)
    }
}
