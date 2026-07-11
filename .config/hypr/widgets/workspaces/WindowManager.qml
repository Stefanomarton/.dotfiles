pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

QtObject {
    id: manager

    property bool pickerVisible: false
    property var windows: []           // [{address, title, class, workspace, icon, x,y,w,h, monitorID}...]
    property string filterText: ""
    property int selectedIndex: 0
    property var selectedWindows: []   // Array of selected window addresses for multi-select
    property var monitorsGeom: []      // [{id,name,x,y,width,height}] for preview scaling

    // === Preview helpers ===
    function windowsForWorkspace(wsName) {
        var out = []
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].workspace === wsName) out.push(windows[i])
        }
        return out
    }

    function monitorForWorkspace(wsName) {
        var wins = windowsForWorkspace(wsName)
        if (wins.length === 0) return null
        var monId = wins[0].monitorID
        for (var j = 0; j < monitorsGeom.length; j++) {
            if (monitorsGeom[j].id === monId) return monitorsGeom[j]
        }
        return null
    }

    // Filtered list based on filterText and excluded workspaces
    readonly property var filteredWindows: {
        var excluded = Config.windowPickerExcludedWorkspaces
        var list = windows.filter(function(win) {
            // Check exclusion list for workspaces
            for (var i = 0; i < excluded.length; i++) {
                if (win.workspace === excluded[i]) return false
            }
            return true
        })

        // Apply fuzzy filter
        if (!filterText) return list
        var lower = filterText.toLowerCase()
        return list.filter(function(win) {
            return win.title.toLowerCase().includes(lower) ||
                   win.class.toLowerCase().includes(lower) ||
                   win.workspace.toLowerCase().includes(lower)
        })
    }

    // Check if a window address is selected
    function isSelected(address) {
        for (var i = 0; i < selectedWindows.length; i++) {
            if (selectedWindows[i] === address) return true
        }
        return false
    }

    // Toggle selection of a window
    function toggleSelection(address) {
        var idx = -1
        for (var i = 0; i < selectedWindows.length; i++) {
            if (selectedWindows[i] === address) {
                idx = i
                break
            }
        }
        if (idx >= 0) {
            // Remove from selection
            var newSelection = selectedWindows.slice()
            newSelection.splice(idx, 1)
            selectedWindows = newSelection
        } else {
            // Add to selection
            selectedWindows = selectedWindows.concat([address])
        }
    }

    // Clear all selections
    function clearSelection() {
        selectedWindows = []
    }

    // Process for fetching windows
    property Process windowsProcess: Process {
        id: windowsProcess
        command: ["hyprctl", "clients", "-j"]
        running: false
        property string buffer: ""

        stdout: SplitParser {
            onRead: data => windowsProcess.buffer += data
        }

        onRunningChanged: {
            if (!running && buffer !== "") {
                try {
                    var clients = JSON.parse(buffer)
                    var result = []
                    for (var i = 0; i < clients.length; i++) {
                        var client = clients[i]
                        if (client.hidden) continue

                        var at = client.at ?? [0, 0]
                        var sz = client.size ?? [0, 0]
                        result.push({
                            address: client.address,
                            title: client.title ?? "",
                            class: client["class"] ?? "",
                            workspace: client.workspace?.name ?? "",
                            workspaceId: client.workspace?.id ?? 0,
                            icon: normalizeAppId(client["class"] ?? ""),
                            // Geometry for the mini-map preview
                            x: at[0], y: at[1], w: sz[0], h: sz[1],
                            monitorID: client.monitor ?? -1
                        })
                    }
                    // Sort by workspace, then by title
                    result.sort(function(a, b) {
                        if (a.workspace !== b.workspace) {
                            return a.workspace.localeCompare(b.workspace)
                        }
                        return a.title.localeCompare(b.title)
                    })
                    manager.windows = result
                } catch(e) {
                    console.log("windows parse error:", e)
                }
                buffer = ""
            }
        }
    }

    // Monitor geometry for the mini-map preview
    property Process monitorsProcess: Process {
        id: monitorsProcess
        command: ["hyprctl", "monitors", "-j"]
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => monitorsProcess.buffer += data
        }
        onRunningChanged: {
            if (!running && buffer !== "") {
                try {
                    var mons = JSON.parse(buffer)
                    var result = []
                    for (var i = 0; i < mons.length; i++) {
                        var mon = mons[i]
                        result.push({
                            id: mon.id,
                            name: mon.name ?? "",
                            x: mon.x ?? 0,
                            y: mon.y ?? 0,
                            width: (mon.width ?? 0) / (mon.scale ?? 1),
                            height: (mon.height ?? 0) / (mon.scale ?? 1)
                        })
                    }
                    manager.monitorsGeom = result
                } catch(e) {
                    console.log("monitors parse error:", e)
                }
                buffer = ""
            }
        }
    }

    // Process for focusing window
    property Process focusProcess: Process {
        id: focusProcess
        running: false

        onRunningChanged: {
            if (!running) {
                manager.hide()
            }
        }
    }

    // Process for previewing workspace (temporary focus, doesn't hide picker)
    property Process previewProcess: Process {
        id: previewProcess
        running: false
    }

    // Process for resetting to original workspace
    property Process resetProcess: Process {
        id: resetProcess
        running: false
    }

    // Process for moving window to current workspace
    property Process moveProcess: Process {
        id: moveProcess
        running: false
        property string addressToFocus: ""

        onRunningChanged: {
            if (!running && addressToFocus !== "") {
                // After moving, focus the window
                focusProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + addressToFocus + "' })"]
                focusProcess.running = true
                addressToFocus = ""
            }
        }
    }

    function normalizeAppId(appId) {
        if (!appId) return "application-x-executable"
        return appId.replace(/-browser$/, "")
                    .replace(/-wayland$/, "")
                    .replace(/-x11$/, "")
    }

    function refreshWindows() {
        windowsProcess.buffer = ""
        windowsProcess.running = true
        monitorsProcess.buffer = ""
        monitorsProcess.running = true
    }

    function show() {
        manager.filterText = ""
        manager.selectedIndex = 0
        // Store original workspace for preview reset
        manager.originalWorkspaceForPreview = Hyprland.activeWorkspace?.name ?? ""
        refreshWindows()
        manager.pickerVisible = true
    }

    // Store original workspace to return to when preview is cancelled
    property string originalWorkspaceForPreview: ""

    function hide() {
        manager.pickerVisible = false
        manager.filterText = ""
    }

    function toggle() {
        if (pickerVisible) {
            hide()
        } else {
            show()
        }
    }

    function focusWindow(address) {
        focusProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + address + "' })"]
        focusProcess.running = true
    }

    function previewWorkspace(workspaceName) {
        // Temporarily switch to workspace for preview (doesn't hide picker)
        previewProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 'name:" + workspaceName + "' })"]
        previewProcess.running = true
    }

    function resetToOriginalWorkspace() {
        // Return to original workspace when preview is cancelled
        var currentWs = Hyprland.activeWorkspace?.name ?? ""
        if (originalWorkspaceForPreview && originalWorkspaceForPreview !== currentWs) {
            resetProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 'name:" + originalWorkspaceForPreview + "' })"]
            resetProcess.running = true
        }
    }

    function moveToCurrentAndFocus(address) {
        // Move window to current workspace, then focus
        moveProcess.addressToFocus = address
        moveProcess.command = ["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = 'e+0', window = 'address:" + address + "' })"]
        moveProcess.running = true
    }

    // Move multiple windows to current workspace (no focus for multi)
    function moveMultipleToCurrent(addresses) {
        if (addresses.length === 0) return
        var commands = []
        for (var i = 0; i < addresses.length; i++) {
            commands.push("hl.dispatch(hl.dsp.window.move({ workspace = 'e+0', window = 'address:" + addresses[i] + "' }))")
        }
        multiMoveProcess.command = ["hyprctl", "eval", commands.join("; ")]
        multiMoveProcess.running = true
    }

    // Move multiple windows to a specific workspace
    function moveMultipleToWorkspace(addresses, workspaceName) {
        if (addresses.length === 0) return
        var commands = []
        for (var i = 0; i < addresses.length; i++) {
            commands.push("hl.dispatch(hl.dsp.window.move({ workspace = 'name:" + workspaceName + "', window = 'address:" + addresses[i] + "' }))")
        }
        multiMoveProcess.command = ["hyprctl", "eval", commands.join("; ")]
        multiMoveProcess.running = true
    }

    // Close multiple windows
    function closeMultipleWindows(addresses) {
        if (addresses.length === 0) return
        var commands = []
        for (var i = 0; i < addresses.length; i++) {
            commands.push("hl.dispatch(hl.dsp.window.close({ window = 'address:" + addresses[i] + "' }))")
        }
        multiCloseProcess.command = ["hyprctl", "eval", commands.join("; ")]
        multiCloseProcess.running = true
    }

    // Process for batch move operations
    property Process multiMoveProcess: Process {
        id: multiMoveProcess
        running: false
        onRunningChanged: {
            if (!running) {
                manager.hide()
            }
        }
    }

    // Process for batch close operations
    property Process multiCloseProcess: Process {
        id: multiCloseProcess
        running: false
        onRunningChanged: {
            if (!running) {
                manager.clearSelection()
                // Delay refresh to allow hyprland to actually close the windows
                closeRefreshDelayTimer.start()
            }
        }
    }

    // Timer to delay refresh after closing windows
    property Timer closeRefreshDelayTimer: Timer {
        interval: 200
        repeat: false
        onTriggered: manager.refreshWindows()
    }

    // Clamp selected index when filtered list changes
    onFilteredWindowsChanged: {
        if (selectedIndex >= filteredWindows.length) {
            selectedIndex = Math.max(0, filteredWindows.length - 1)
        }
    }
}
