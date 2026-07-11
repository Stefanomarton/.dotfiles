pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

QtObject {
    id: manager

    // === State ===
    property bool pickerVisible: false
    property string filterText: ""
    property int selectedIndex: 0

    // === Raw Data ===
    property var workspaces: []
    property var windows: []
    property var applications: []
    property var monitors: []   // [{id, name, x, y, width, height}] — for preview scaling

    // === Original workspace for preview reset ===
    property string originalWorkspaceForPreview: ""
    property var selectedWindows: []  // For multi-select mode

    // Window that was focused when the picker opened (target of "m " move mode)
    property string currentWindowAddress: ""
    property string currentWindowTitle: ""

    // === Item Types ===
    readonly property int typeWorkspace: 0
    readonly property int typeWindow: 1
    readonly property int typeApplication: 2
    readonly property int typeAction: 3

    // === Ranking weights ===
    // On equal relevance: workspaces beat windows beat apps, so a project
    // workspace is always the first Enter target.
    readonly property int catWorkspace: 100
    readonly property int catWindow: 10
    // The current workspace is a no-op switch target, so push it down the list.
    readonly property int currentWorkspacePenalty: 300

    // === Narrowing / mode (vertico-style prefixes) ===
    // "w " workspaces · "p " windows · "a " apps · "m " move current window → workspace
    readonly property string narrowLetter: {
        var m = filterText.match(/^([wpam]) /)
        return m ? m[1] : ""
    }
    readonly property string effectiveQuery: narrowLetter ? filterText.substring(2) : filterText
    readonly property bool moveMode: narrowLetter === "m"
    readonly property int narrowType: {
        if (narrowLetter === "w" || narrowLetter === "m") return typeWorkspace
        if (narrowLetter === "p") return typeWindow
        if (narrowLetter === "a") return typeApplication
        return -1  // no narrowing: show everything
    }
    // === Filtered & Scored Results (two columns) ===
    // Left column = workspaces; right column = windows + applications.
    readonly property var workspaceResults: {
        if (narrowType >= 0 && narrowType !== typeWorkspace) return []
        var list = []
        var lower = effectiveQuery.toLowerCase().trim()

        // Workspaces ("special:" workspaces are always hidden)
        var excludedWs = Config.pickerExcludedWorkspaces
        for (var i = 0; i < workspaces.length; i++) {
            var ws = workspaces[i]
            if (isSpecialWorkspace(ws.name)) continue
            // Check exclusion
            var isExcluded = false
            for (var e = 0; e < excludedWs.length; e++) {
                if (ws.name === excludedWs[e]) {
                    isExcluded = true
                    break
                }
            }
            if (isExcluded) continue

            // Rank project workspaces first so a single Enter switches fast.
            var isCurrentWs = ws.name === currentWorkspaceName
            var wsScore
            if (lower.length === 0) {
                // Browse mode: all project workspaces on top, current one last
                wsScore = isCurrentWs ? 1 : 900
            } else {
                wsScore = scoreItem(ws.name, lower, 0)
                if (wsScore > 0) {
                    wsScore += catWorkspace
                    if (isCurrentWs) wsScore -= currentWorkspacePenalty
                }
            }
            if (lower.length === 0 || wsScore > 0) {
                list.push({
                    type: typeWorkspace,
                    id: ws.id,
                    name: ws.name,
                    workspace: ws.name,
                    windows: ws.windows,
                    windowList: ws.windowList || [],
                    icon: "folder",
                    title: ws.name,
                    className: "",
                    score: wsScore,
                    executable: "",
                    desktopFile: ""
                })
            }
        }
        list.sort(function(a, b) {
            if (b.score !== a.score) return b.score - a.score
            return a.name.localeCompare(b.name)
        })
        return list
    }

    readonly property var windowResults: {
        var list = []
        var lower = effectiveQuery.toLowerCase().trim()

        // Windows
        var excludedWinWs = Config.windowPickerExcludedWorkspaces
        if (narrowType < 0 || narrowType === typeWindow)
        for (var j = 0; j < windows.length; j++) {
            var win = windows[j]
            // Check workspace exclusion
            var winExcluded = false
            for (var we = 0; we < excludedWinWs.length; we++) {
                if (win.workspace === excludedWinWs[we]) {
                    winExcluded = true
                    break
                }
            }
            if (winExcluded) continue

            var winScore = scoreItem(win.title + " " + win.class, lower, 0)
            // Boost score for windows on current workspace
            if (win.workspace === currentWorkspaceName) {
                winScore += 50
            }
            // Keep windows above apps but below workspaces on ties
            if (winScore > 0) {
                winScore += catWindow
            }
            if (lower.length === 0 || winScore > 0) {
                list.push({
                    type: typeWindow,
                    id: 0,
                    name: win.title,
                    workspace: win.workspace,
                    windows: 0,
                    windowList: [],
                    icon: win.icon,
                    title: win.title,
                    className: win.class,
                    score: winScore,
                    address: win.address,
                    executable: "",
                    desktopFile: ""
                })
            }
        }

        // Add applications
        if (narrowType < 0 || narrowType === typeApplication)
        for (var k = 0; k < applications.length; k++) {
            var app = applications[k]
            var appScore = scoreItem(app.name + " " + app.genericName + " " + app.categories.join(" "), lower, 0)
            // Only surface apps when searching (or narrowed to apps) — keeps the
            // browse view to just workspaces | windows.
            if (lower.length > 0 ? appScore > 0 : narrowType === typeApplication) {
                list.push({
                    type: typeApplication,
                    id: 0,
                    name: app.name,
                    workspace: "",
                    windows: 0,
                    windowList: [],
                    icon: app.icon,
                    title: app.name,
                    className: app.genericName,
                    score: appScore,
                    executable: app.executable,
                    desktopFile: app.desktopFile
                })
            }
        }

        list.sort(function(a, b) {
            if (b.score !== a.score) return b.score - a.score
            return a.name.localeCompare(b.name)
        })
        return list
    }

    // Combined list (workspaces, then windows/apps) + the column split point.
    readonly property var results: workspaceResults.concat(windowResults)
    readonly property int workspaceCount: workspaceResults.length

    // === Current context ===
    readonly property string currentWorkspaceName: Hyprland.activeWorkspace?.name ?? ""
    readonly property string currentMonitorName: Hyprland.focusedMonitor?.name ?? ""

    // === Scoring function ===
    function scoreItem(text, query, baseScore) {
        if (!query || query.length === 0) return baseScore + 1

        var lowerText = text.toLowerCase()
        var score = 0

        // Exact match gets highest score
        if (lowerText === query) {
            score = 1000
        }
        // Starts with query gets high score
        else if (lowerText.startsWith(query)) {
            score = 500
        }
        // Contains query gets medium score
        else if (lowerText.includes(query)) {
            score = 100
        }
        // Fuzzy match gets lower score
        else if (fuzzyMatch(lowerText, query)) {
            score = 50
        }

        return score > 0 ? score + baseScore : 0
    }

    // Hyprland special workspaces are named "special" or "special:<name>".
    function isSpecialWorkspace(name) {
        return name === "special" || name.startsWith("special:")
    }

    function fuzzyMatch(text, query) {
        var textIdx = 0
        var queryIdx = 0
        while (textIdx < text.length && queryIdx < query.length) {
            if (text[textIdx] === query[queryIdx]) {
                queryIdx++
            }
            textIdx++
        }
        return queryIdx === query.length
    }

    // === Multi-select functions ===
    function isSelected(address) {
        for (var i = 0; i < selectedWindows.length; i++) {
            if (selectedWindows[i] === address) return true
        }
        return false
    }

    function toggleSelection(address) {
        var idx = -1
        for (var i = 0; i < selectedWindows.length; i++) {
            if (selectedWindows[i] === address) {
                idx = i
                break
            }
        }
        if (idx >= 0) {
            var newSel = selectedWindows.slice()
            newSel.splice(idx, 1)
            selectedWindows = newSel
        } else {
            selectedWindows = selectedWindows.concat([address])
        }
    }

    function clearSelection() {
        selectedWindows = []
    }

    // === Data Fetching Processes ===
    property Process workspacesProcess: Process {
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
                            monitorID: ws.monitorID ?? 0,
                            windowList: []
                        })
                    }
                    manager.workspaces = result
                    // Now fetch clients to populate window details
                    clientsProcess.running = true
                } catch(e) {
                    console.log("workspaces parse error:", e)
                }
                buffer = ""
            }
        }
    }

    property Process clientsProcess: Process {
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
                    // Update workspaces with window lists
                    var wsList = manager.workspaces
                    for (var i = 0; i < wsList.length; i++) {
                        wsList[i].windowList = []
                    }
                    // Populate window lists
                    for (var j = 0; j < clients.length; j++) {
                        var client = clients[j]
                        if (client.hidden) continue
                        var wsName = client.workspace?.name ?? ""
                        for (var k = 0; k < wsList.length; k++) {
                            if (wsList[k].name === wsName) {
                                wsList[k].windowList.push({
                                    title: client.title ?? "",
                                    class: client["class"] ?? "",
                                    icon: normalizeAppId(client["class"] ?? "")
                                })
                                break
                            }
                        }
                    }
                    manager.workspaces = wsList
                    // Build windows list
                    var winList = []
                    for (var m = 0; m < clients.length; m++) {
                        var c = clients[m]
                        if (c.hidden) continue
                        var at = c.at ?? [0, 0]
                        var sz = c.size ?? [0, 0]
                        winList.push({
                            address: c.address,
                            title: c.title ?? "",
                            class: c["class"] ?? "",
                            workspace: c.workspace?.name ?? "",
                            icon: normalizeAppId(c["class"] ?? ""),
                            // Geometry (global compositor coords) for the mini-map preview
                            x: at[0], y: at[1], w: sz[0], h: sz[1],
                            monitorID: c.monitor ?? -1,
                            floating: c.floating ?? false
                        })
                    }
                    manager.windows = winList
                } catch(e) {
                    console.log("clients parse error:", e)
                }
                buffer = ""
            }
        }
    }

    property Process appsProcess: Process {
        command: ["sh", "-c", "find /usr/share/applications ~/.local/share/applications -name '*.desktop' 2>/dev/null | head -200"]
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => appsProcess.buffer += data
        }
        onRunningChanged: {
            if (!running) {
                if (buffer.trim() !== "") {
                    var files = buffer.trim().split("\n")
                    parseDesktopFiles(files)
                }
                buffer = ""
            }
        }
    }

    // Monitor geometry, used to scale the workspace mini-map preview.
    property Process monitorsProcess: Process {
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
                    manager.monitors = result
                } catch(e) {
                    console.log("monitors parse error:", e)
                }
                buffer = ""
            }
        }
    }

    // === Preview helpers ===
    // Windows on a given workspace, including geometry, for the mini-map.
    function windowsForWorkspace(wsName) {
        var out = []
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].workspace === wsName) out.push(windows[i])
        }
        return out
    }

    // Monitor bounds ({x, y, width, height}) for the monitor a workspace lives on.
    function monitorForWorkspace(wsName) {
        var monId = -1
        var monName = ""
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i].name === wsName) {
                monId = workspaces[i].monitorID
                monName = workspaces[i].monitor
                break
            }
        }
        for (var j = 0; j < monitors.length; j++) {
            if (monitors[j].id === monId || (monName && monitors[j].name === monName)) {
                return monitors[j]
            }
        }
        return null
    }

    function parseDesktopFiles(files) {
        var apps = []
        var parsedCount = 0

        for (var i = 0; i < files.length; i++) {
            var file = files[i].trim()
            if (!file) continue

            // Parse each desktop file
            parseDesktopFile(file, function(app) {
                if (app && app.name && app.executable && !app.noDisplay && app.showInDesktop) {
                    apps.push(app)
                }
                parsedCount++
                if (parsedCount >= files.length) {
                    // Sort alphabetically
                    apps.sort(function(a, b) {
                        return a.name.localeCompare(b.name)
                    })
                    manager.applications = apps
                }
            })
        }

        // Handle empty case
        if (files.length === 0) {
            manager.applications = []
        }
    }

    function parseDesktopFile(filePath, callback) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["cat", "' + filePath + '"] }', manager)
        var buffer = ""

        var splitParser = Qt.createQmlObject('import Quickshell.Io; SplitParser {}', manager)
        splitParser.onRead.connect(function(data) {
            buffer += data
        })
        proc.stdout = splitParser

        proc.onRunningChanged.connect(function() {
            if (!proc.running) {
                var app = parseDesktopEntry(buffer, filePath)
                callback(app)
                proc.destroy()
                splitParser.destroy()
            }
        })

        proc.running = true
    }

    function parseDesktopEntry(content, filePath) {
        var lines = content.split("\n")
        var inDesktopEntry = false
        var app = {
            name: "",
            genericName: "",
            executable: "",
            icon: "application-x-executable",
            categories: [],
            desktopFile: filePath,
            noDisplay: false,
            showInDesktop: true
        }

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "[Desktop Entry]") {
                inDesktopEntry = true
                continue
            }
            if (line.startsWith("[")) {
                inDesktopEntry = false
                continue
            }
            if (!inDesktopEntry) continue

            if (line.startsWith("Name=")) {
                app.name = line.substring(5)
            } else if (line.startsWith("GenericName=")) {
                app.genericName = line.substring(12)
            } else if (line.startsWith("Exec=")) {
                app.executable = line.substring(5).replace(/%[fFuUdDnNickvm]/g, "")
            } else if (line.startsWith("Icon=")) {
                app.icon = line.substring(5)
            } else if (line.startsWith("Categories=")) {
                app.categories = line.substring(11).split(";")
            } else if (line.startsWith("NoDisplay=")) {
                app.noDisplay = (line.substring(10).toLowerCase() === "true")
            } else if (line.startsWith("OnlyShowIn=")) {
                var onlyIn = line.substring(11).toLowerCase()
                app.showInDesktop = onlyIn.includes("hyprland") || onlyIn.includes("wayland") || onlyIn.includes("gnome") || onlyIn.includes("kde")
            } else if (line.startsWith("NotShowIn=")) {
                var notIn = line.substring(10).toLowerCase()
                if (notIn.includes("hyprland")) {
                    app.showInDesktop = false
                }
            } else if (line.startsWith("Terminal=")) {
                var isTerminal = line.substring(9).toLowerCase() === "true"
                if (isTerminal && !app.icon.includes("terminal")) {
                    app.icon = "utilities-terminal"
                }
            }
        }

        return app
    }

    function normalizeAppId(appId) {
        if (!appId) return "application-x-executable"
        return appId.replace(/-browser$/, "")
                    .replace(/-wayland$/, "")
                    .replace(/-x11$/, "")
    }

    // === Action Processes ===
    property Process switchProcess: Process {
        running: false
        onRunningChanged: if (!running) manager.hide()
    }

    property Process focusProcess: Process {
        running: false
        onRunningChanged: if (!running) manager.hide()
    }

    property Process launchProcess: Process {
        running: false
        onRunningChanged: if (!running) manager.hide()
    }

    property Process moveProcess: Process {
        running: false
        onRunningChanged: if (!running) manager.hide()
    }

    property Process multiMoveProcess: Process {
        running: false
        onRunningChanged: if (!running) manager.hide()
    }

    property Process closeProcess: Process {
        running: false
        onRunningChanged: {
            if (!running) {
                clearSelection()
                refreshData()
            }
        }
    }

    // Captures the focused window when the picker opens (target for "m " move mode).
    property Process activeWindowProcess: Process {
        command: ["hyprctl", "activewindow", "-j"]
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => activeWindowProcess.buffer += data
        }
        onRunningChanged: {
            if (!running) {
                try {
                    var w = JSON.parse(activeWindowProcess.buffer)
                    manager.currentWindowAddress = w.address ?? ""
                    manager.currentWindowTitle = w.title ?? ""
                } catch(e) {
                    manager.currentWindowAddress = ""
                    manager.currentWindowTitle = ""
                }
                activeWindowProcess.buffer = ""
            }
        }
    }

    // === Public Methods ===
    function refreshData() {
        workspacesProcess.buffer = ""
        workspacesProcess.running = true
        // Also refresh applications (less frequently needed, but good for updates)
        appsProcess.buffer = ""
        appsProcess.running = true
        // Monitor geometry for the workspace mini-map preview
        monitorsProcess.buffer = ""
        monitorsProcess.running = true
    }

    function show() {
        manager.filterText = ""
        manager.selectedIndex = 0
        manager.originalWorkspaceForPreview = currentWorkspaceName
        clearSelection()
        // Capture the focused window before we steal keyboard focus
        manager.currentWindowAddress = ""
        manager.currentWindowTitle = ""
        activeWindowProcess.buffer = ""
        activeWindowProcess.running = true
        refreshData()
        manager.pickerVisible = true
    }

    function hide() {
        manager.pickerVisible = false
        manager.filterText = ""
        clearSelection()
    }

    function toggle() {
        if (pickerVisible) {
            hide()
        } else {
            show()
        }
    }

    // === Actions ===
    function activateItem(item, modifiers) {
        if (!item) return

        var isCtrl = modifiers & Qt.ControlModifier
        var isAlt = modifiers & Qt.AltModifier

        switch (item.type) {
            case typeWorkspace:
                if (isCtrl) {
                    // Move workspace to other monitor
                    moveWorkspaceToMonitor(item.name)
                } else if (isAlt) {
                    // Move workspace to current monitor
                    moveWorkspaceToCurrent(item.name)
                } else {
                    // Switch to workspace
                    switchToWorkspace(item.name)
                }
                break

            case typeWindow:
                if (isAlt) {
                    // Close window
                    closeWindow(item.address)
                } else if (selectedWindows.length > 0 && !isSelected(item.address)) {
                    // If we have other windows selected, move them instead
                    if (isCtrl) {
                        moveMultipleToCurrent(selectedWindows)
                    } else {
                        moveMultipleToWorkspace(selectedWindows, currentWorkspaceName)
                    }
                } else if (isCtrl) {
                    // Move window to current workspace
                    moveWindowToCurrent(item.address)
                } else {
                    // Focus window
                    focusWindow(item.address)
                }
                break

            case typeApplication:
                // Launch application
                launchApplication(item.executable)
                break
        }
    }

    // Move the window that was focused when the picker opened to a workspace.
    // follow=false: move but keep the current view (return to original workspace).
    // follow=true:  move, then switch to that workspace and focus the window.
    function moveCurrentWindowToWorkspace(wsName, follow) {
        var addr = currentWindowAddress
        if (!wsName || !addr) { hide(); return }
        var cmds = "hl.dispatch(hl.dsp.window.move({ workspace = 'name:" + wsName + "', window = 'address:" + addr + "' }))"
        if (follow) {
            cmds += "; hl.dispatch(hl.dsp.focus({ workspace = 'name:" + wsName + "' }))"
            cmds += "; hl.dispatch(hl.dsp.focus({ window = 'address:" + addr + "' }))"
        } else {
            cmds += "; hl.dispatch(hl.dsp.focus({ workspace = 'name:" + originalWorkspaceForPreview + "' }))"
        }
        moveWindowProcess.command = ["hyprctl", "eval", cmds]
        moveWindowProcess.running = true
    }

    property Process moveWindowProcess: Process {
        running: false
        onRunningChanged: if (!running) manager.hide()
    }

    function switchToWorkspace(name) {
        switchProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 'name:" + name + "' })"]
        switchProcess.running = true
    }

    function createAndSwitchToWorkspace(name) {
        // In Hyprland, switching to a non-existent named workspace creates it
        switchToWorkspace(name)
    }

    function focusWindow(address) {
        focusProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + address + "' })"]
        focusProcess.running = true
    }

    function launchApplication(executable) {
        // Use hyprctl to dispatch exec
        launchProcess.command = ["hyprctl", "dispatch", "hl.dsp.exec_cmd('" + executable.trim().replace(/'/g, "\\'") + "')"]
        launchProcess.running = true
    }

    function moveWindowToCurrent(address) {
        moveProcess.command = ["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = 'e+0', window = 'address:" + address + "' })"]
        moveProcess.running = true
    }

    function moveMultipleToCurrent(addresses) {
        if (addresses.length === 0) return
        var commands = []
        for (var i = 0; i < addresses.length; i++) {
            commands.push("hl.dispatch(hl.dsp.window.move({ workspace = 'e+0', window = 'address:" + addresses[i] + "' }))")
        }
        multiMoveProcess.command = ["hyprctl", "eval", commands.join("; ")]
        multiMoveProcess.running = true
    }

    function moveMultipleToWorkspace(addresses, workspaceName) {
        if (addresses.length === 0) return
        var commands = []
        for (var i = 0; i < addresses.length; i++) {
            commands.push("hl.dispatch(hl.dsp.window.move({ workspace = 'name:" + workspaceName + "', window = 'address:" + addresses[i] + "' }))")
        }
        multiMoveProcess.command = ["hyprctl", "eval", commands.join("; ")]
        multiMoveProcess.running = true
    }

    function closeWindow(address) {
        closeProcess.command = ["hyprctl", "dispatch", "hl.dsp.window.close({ window = 'address:" + address + "' })"]
        closeProcess.running = true
    }

    function destroyWorkspace(workspaceName) {
        // Close all windows in the workspace
        destroyWsClientsProcess.targetWorkspace = workspaceName
        destroyWsClientsProcess.running = true
    }

    property Process destroyWsClientsProcess: Process {
        command: ["hyprctl", "clients", "-j"]
        running: false
        property string buffer: ""
        property string targetWorkspace: ""
        stdout: SplitParser {
            onRead: data => destroyWsClientsProcess.buffer += data
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
                    if (commands.length > 0) {
                        destroyWsBatchProcess.command = ["hyprctl", "eval", commands.join("; ")]
                        destroyWsBatchProcess.running = true
                    } else {
                        refreshData()
                    }
                } catch(e) {
                    console.log("clients parse error for destroy:", e)
                }
                buffer = ""
                targetWorkspace = ""
            }
        }
    }

    property Process destroyWsBatchProcess: Process {
        running: false
        onRunningChanged: {
            if (!running) {
                refreshData()
            }
        }
    }

    function moveWorkspaceToMonitor(workspaceName) {
        // Get available monitors
        monitorCheckProcess.running = true
        monitorCheckProcess.targetWorkspace = workspaceName
    }

    property Process monitorCheckProcess: Process {
        command: ["hyprctl", "monitors", "-j"]
        running: false
        property string buffer: ""
        property string targetWorkspace: ""
        stdout: SplitParser {
            onRead: data => monitorCheckProcess.buffer += data
        }
        onRunningChanged: {
            if (!running && buffer !== "") {
                try {
                    var monitors = JSON.parse(buffer)
                    var otherMonitor = ""
                    for (var i = 0; i < monitors.length; i++) {
                        if (!monitors[i].focused) {
                            otherMonitor = monitors[i].name
                            break
                        }
                    }
                    if (otherMonitor && targetWorkspace) {
                        moveWsProcess.command = ["hyprctl", "dispatch", "hl.dsp.workspace.move({ workspace = 'name:" + targetWorkspace + "', monitor = '" + otherMonitor + "' })"]
                        moveWsProcess.running = true
                    }
                } catch(e) {
                    console.log("monitors parse error:", e)
                }
                buffer = ""
                targetWorkspace = ""
            }
        }
    }

    property Process moveWsProcess: Process {
        running: false
        onRunningChanged: if (!running) manager.hide()
    }

    function moveWorkspaceToCurrent(workspaceName) {
        if (!currentMonitorName) {
            hide()
            return
        }
        moveProcess.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.workspace.move({ workspace = 'name:" + workspaceName + "', monitor = '" + currentMonitorName + "' })); hl.dispatch(hl.dsp.focus({ workspace = 'name:" + workspaceName + "' }))"]
        moveProcess.running = true
    }

    function previewWorkspace(workspaceName) {
        if (!Config.pickerPreviewOnNavigate) return
        if (!workspaceName || workspaceName === currentWorkspaceName) return
        previewProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 'name:" + workspaceName + "' })"]
        previewProc.running = true
    }

    property Process previewProc: Process {
        running: false
    }

    function resetToOriginalWorkspace() {
        if (originalWorkspaceForPreview && originalWorkspaceForPreview !== currentWorkspaceName) {
            resetProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 'name:" + originalWorkspaceForPreview + "' })"]
            resetProc.running = true
        }
    }

    property Process resetProc: Process {
        running: false
    }

    // === Clamp selected index ===
    onResultsChanged: {
        if (selectedIndex >= results.length) {
            selectedIndex = Math.max(0, results.length - 1)
        }
    }
}
