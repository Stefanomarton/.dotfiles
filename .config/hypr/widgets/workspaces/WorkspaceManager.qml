pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

QtObject {
    id: manager

    property bool pickerVisible: false
    property var workspaces: []        // [{id, name, windows}...]
    property string filterText: ""
    property int selectedIndex: 0
    property var windowsFlat: []       // flat window list w/ geometry, for the preview
    property var monitorsGeom: []      // [{id,name,x,y,width,height}] for preview scaling

    // Filtered list based on Config.pickerExcludedWorkspaces and filterText
    readonly property var filteredWorkspaces: {
        var excluded = Config.pickerExcludedWorkspaces
        var list = workspaces.filter(function(ws) {
            // Always hide Hyprland special workspaces ("special" / "special:<name>")
            if (ws.name === "special" || ws.name.startsWith("special:")) return false
            // Check exclusion list
            for (var i = 0; i < excluded.length; i++) {
                if (ws.name === excluded[i]) return false
            }
            return true
        })

        // Apply fuzzy filter
        if (!filterText) return list
        var lower = filterText.toLowerCase()
        return list.filter(function(ws) {
            return ws.name.toLowerCase().includes(lower)
        })
    }

    // Process for fetching workspaces
    property Process workspacesProcess: Process {
        id: workspacesProcess
        command: ["hyprctl", "workspaces", "-j"]
        running: false
        property string buffer: ""

        stdout: SplitParser {
            onRead: data => workspacesProcess.buffer += data
        }

        onRunningChanged: {
            if (!running && buffer !== "") {
                try {
                    var wsList = JSON.parse(buffer)
                    var result = []
                    for (var i = 0; i < wsList.length; i++) {
                        var ws = wsList[i]
                        result.push({
                            id: ws.id,
                            name: ws.name,
                            windows: ws.windows ?? 0,
                            monitor: ws.monitor ?? "",
                            monitorID: ws.monitorID ?? -1,
                            windowList: []  // Will be populated by clients fetch
                        })
                    }
                    manager.workspacesWithWindows = result
                    // Now fetch clients to populate window details
                    clientsProcess.running = true
                } catch(e) {
                    console.log("workspaces parse error:", e)
                }
                buffer = ""
            }
        }
    }

    // Intermediate storage while fetching
    property var workspacesWithWindows: []

    // Process for fetching clients to get window details
    property Process clientsProcess: Process {
        id: clientsProcess
        command: ["hyprctl", "clients", "-j"]
        running: false
        property string buffer: ""

        stdout: SplitParser {
            onRead: data => clientsProcess.buffer += data
        }

        onRunningChanged: {
            if (!running && buffer !== "") {
                try {
                    var clients = JSON.parse(buffer)
                    var baseList = manager.workspacesWithWindows
                    var result = []
                    
                    // Create new objects with window lists
                    for (var i = 0; i < baseList.length; i++) {
                        result.push({
                            id: baseList[i].id,
                            name: baseList[i].name,
                            windows: baseList[i].windows,
                            monitor: baseList[i].monitor,
                            monitorID: baseList[i].monitorID,
                            windowList: []
                        })
                    }
                    
                    // Populate window lists
                    for (var j = 0; j < clients.length; j++) {
                        var client = clients[j]
                        if (client.hidden) continue
                        
                        var wsName = client.workspace?.name ?? ""
                        for (var k = 0; k < result.length; k++) {
                            if (result[k].name === wsName) {
                                result[k].windowList.push({
                                    title: client.title ?? "",
                                    class: client["class"] ?? "",
                                    icon: normalizeAppId(client["class"] ?? "")
                                })
                                break
                            }
                        }
                    }
                    
                    // Flat window list w/ geometry for the mini-map preview
                    var flat = []
                    for (var w = 0; w < clients.length; w++) {
                        var fc = clients[w]
                        if (fc.hidden) continue
                        var at = fc.at ?? [0, 0]
                        var sz = fc.size ?? [0, 0]
                        flat.push({
                            address: fc.address,
                            title: fc.title ?? "",
                            class: fc["class"] ?? "",
                            workspace: fc.workspace?.name ?? "",
                            icon: normalizeAppId(fc["class"] ?? ""),
                            x: at[0], y: at[1], w: sz[0], h: sz[1],
                            monitorID: fc.monitor ?? -1
                        })
                    }
                    manager.windowsFlat = flat

                    // Sort: named workspaces first (alphabetically), then numbered
                    result.sort(function(a, b) {
                        var aNum = parseInt(a.name)
                        var bNum = parseInt(b.name)
                        var aIsNum = !isNaN(aNum)
                        var bIsNum = !isNaN(bNum)

                        if (!aIsNum && bIsNum) return -1
                        if (aIsNum && !bIsNum) return 1
                        if (!aIsNum && !bIsNum) return a.name.localeCompare(b.name)
                        return aNum - bNum
                    })
                    
                    manager.workspaces = result
                } catch(e) {
                    console.log("clients parse error for workspaces:", e)
                }
                buffer = ""
            }
        }
    }

    function normalizeAppId(appId) {
        if (!appId) return "application-x-executable"
        return appId.replace(/-browser$/, "")
                    .replace(/-wayland$/, "")
                    .replace(/-x11$/, "")
    }

    // === Preview helpers ===
    // Windows on a given workspace, including geometry, for the mini-map.
    function windowsForWorkspace(wsName) {
        var out = []
        for (var i = 0; i < windowsFlat.length; i++) {
            if (windowsFlat[i].workspace === wsName) out.push(windowsFlat[i])
        }
        return out
    }

    // Monitor bounds ({x, y, width, height}) for the monitor a workspace lives on
    // (derived from its windows, since the preview only shows non-empty workspaces).
    function monitorForWorkspace(wsName) {
        var wins = windowsForWorkspace(wsName)
        if (wins.length === 0) return null
        var monId = wins[0].monitorID
        for (var j = 0; j < monitorsGeom.length; j++) {
            if (monitorsGeom[j].id === monId) return monitorsGeom[j]
        }
        return null
    }

    // Process for switching workspaces
    property Process switchProcess: Process {
        id: switchProcess
        running: false

        onRunningChanged: {
            if (!running) {
                manager.hide()
            }
        }
    }

    // Process for closing windows (destroy)
    property Process clientsForDestroyProcess: Process {
        id: clientsForDestroyProcess
        command: ["hyprctl", "clients", "-j"]
        running: false
        property string buffer: ""
        property string targetWorkspace: ""

        stdout: SplitParser {
            onRead: data => clientsForDestroyProcess.buffer += data
        }

        onRunningChanged: {
            if (!running && buffer !== "" && targetWorkspace !== "") {
                try {
                    var clients = JSON.parse(buffer)
                    var commands = []
                    for (var i = 0; i < clients.length; i++) {
                        var client = clients[i]
                        var wsName = client.workspace?.name ?? ""
                        if (wsName === targetWorkspace) {
                            commands.push("hl.dispatch(hl.dsp.window.close({ window = 'address:" + client.address + "' }))")
                        }
                    }
                    // Close all windows using batch command
                    if (commands.length > 0) {
                        closeWindowProcess.command = ["hyprctl", "eval", commands.join("; ")]
                        closeWindowProcess.running = true
                    } else {
                        // No windows, just refresh
                        manager.refreshWorkspaces()
                    }
                } catch(e) {
                    console.log("clients parse error for destroy:", e)
                }
                buffer = ""
                targetWorkspace = ""
            }
        }
    }

    // Process for closing windows (batch)
    property Process closeWindowProcess: Process {
        id: closeWindowProcess
        running: false

        onRunningChanged: {
            if (!running) {
                // Refresh after windows are closed
                manager.refreshWorkspaces()
            }
        }
    }

    // Process for creating startup workspaces
    property Process startupProcess: Process {
        id: startupProcess
        running: false
    }

    // Process for moving workspace to monitor (step 1: move)
    property Process moveToMonitorProcess: Process {
        id: moveToMonitorProcess
        running: false
        onRunningChanged: {
            if (!running) {
                // Step 2: Focus the moved workspace (so we can see it on the other monitor)
                focusMovedWorkspaceProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 'name:" + moveWorkspaceName + "' })"]
                focusMovedWorkspaceProcess.running = true
            }
        }
    }

    // Step 2: Focus the moved workspace
    property Process focusMovedWorkspaceProcess: Process {
        id: focusMovedWorkspaceProcess
        running: false
        onRunningChanged: {
            if (!running) {
                // Keep focus on moved workspace, just hide picker
                manager.hide()
            }
        }
    }

    // Process for move to current monitor and focus
    property Process moveToCurrentProcess: Process {
        id: moveToCurrentProcess
        running: false
        onRunningChanged: {
            if (!running) {
                manager.hide()
            }
        }
    }

    // State for move workspace workflow
    property string moveWorkspaceName: ""
    property string originalWorkspaceName: ""

    // Available monitors for moving workspaces
    property var availableMonitors: []
    property string currentMonitor: ""

    // Process for fetching monitors
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
                    var monList = JSON.parse(buffer)
                    var result = []
                    var current = ""
                    var geom = []
                    for (var i = 0; i < monList.length; i++) {
                        var mon = monList[i]
                        geom.push({
                            id: mon.id,
                            name: mon.name ?? "",
                            x: mon.x ?? 0,
                            y: mon.y ?? 0,
                            width: (mon.width ?? 0) / (mon.scale ?? 1),
                            height: (mon.height ?? 0) / (mon.scale ?? 1)
                        })
                        if (mon.focused) {
                            current = mon.name
                        } else {
                            result.push(mon.name)
                        }
                    }
                    manager.availableMonitors = result
                    manager.currentMonitor = current
                    manager.monitorsGeom = geom
                } catch(e) {
                    console.log("monitors parse error:", e)
                }
                buffer = ""
            }
        }
    }

    function refreshWorkspaces() {
        workspacesProcess.buffer = ""
        workspacesProcess.running = true
    }

    function show() {
        manager.filterText = ""
        manager.selectedIndex = 0
        refreshWorkspaces()
        refreshMonitors()
        manager.pickerVisible = true
    }

    function refreshMonitors() {
        monitorsProcess.buffer = ""
        monitorsProcess.running = true
    }

    function moveToMonitor(workspaceName, monitorName) {
        var targetMonitor = monitorName

        // If "auto", resolve to first available other monitor
        if (targetMonitor === "auto" && availableMonitors.length > 0) {
            targetMonitor = availableMonitors[0]
        }

        // Validate: target monitor must be in availableMonitors (i.e., not current monitor)
        var isValid = false
        for (var i = 0; i < availableMonitors.length; i++) {
            if (availableMonitors[i] === targetMonitor) {
                isValid = true
                break
            }
        }

        if (isValid) {
            // Store workspace names for the workflow
            manager.moveWorkspaceName = workspaceName
            manager.originalWorkspaceName = Hyprland.activeWorkspace?.name ?? ""

            // Step 1: Move the workspace to target monitor
            moveToMonitorProcess.command = ["hyprctl", "dispatch", "hl.dsp.workspace.move({ workspace = 'name:" + workspaceName + "', monitor = '" + targetMonitor + "' })"]
            moveToMonitorProcess.running = true
        } else {
            console.log("Cannot move workspace: target monitor '" + targetMonitor + "' is not available or is the current monitor")
        }
    }

    function moveToCurrentAndFocus(workspaceName) {
        // Move workspace to current monitor and focus it
        // Get current monitor name
        var currentMon = Hyprland.focusedMonitor?.name ?? ""
        if (!currentMon) {
            console.log("Cannot determine current monitor")
            return
        }

        // Single batch command: move workspace to current monitor and focus it
        moveToCurrentProcess.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.workspace.move({ workspace = 'name:" + workspaceName + "', monitor = '" + currentMon + "' })); hl.dispatch(hl.dsp.focus({ workspace = 'name:" + workspaceName + "' }))"]
        moveToCurrentProcess.running = true
    }

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

    function switchTo(name) {
        switchProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 'name:" + name + "' })"]
        switchProcess.running = true
    }

    function createAndSwitch(name) {
        // In Hyprland, switching to a non-existent named workspace creates it
        switchTo(name)
    }

    function destroyWorkspace(name) {
        // Find all windows in the workspace and close them
        clientsForDestroyProcess.targetWorkspace = name
        clientsForDestroyProcess.buffer = ""
        clientsForDestroyProcess.running = true
    }

    function createStartupWorkspaces() {
        for (var i = 0; i < Config.startupWorkspaces.length; i++) {
            var wsName = Config.startupWorkspaces[i]
            // Create workspace by dispatching to it, then return to current
            startupProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 'name:" + wsName + "' })"]
            startupProcess.running = true
        }
    }

    // Clamp selected index when filtered list changes
    onFilteredWorkspacesChanged: {
        if (selectedIndex >= filteredWorkspaces.length) {
            selectedIndex = Math.max(0, filteredWorkspaces.length - 1)
        }
    }

    // Create startup workspaces when shell loads
    Component.onCompleted: {
        if (Config.startupWorkspaces.length > 0) {
            // Delay to ensure Hyprland is ready
            Qt.callLater(createStartupWorkspaces)
        }
    }
}
