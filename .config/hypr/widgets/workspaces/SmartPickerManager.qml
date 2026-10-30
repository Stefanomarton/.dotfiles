pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "rank.js" as Rank

// Smart picker state and actions. Data comes from Quickshell's Hyprland IPC objects
// and DesktopEntries (no processes); actions go through Hyprland.dispatch with the
// Lua dispatchers of the Hyprland config (several at once = one Lua function).
QtObject {
    id: manager

    property bool pickerVisible: false
    property string filterText: ""        // what is typed, without the selector
    property string mode: ""              // selector: "" all · w · p · a · m · ">"
    property int selectedIndex: 0
    property var selectedWindows: []      // addresses picked with Tab

    // Captured when the picker opens: target of "m " and where to stay
    property string openedAddress: ""
    property string openedTitle: ""
    property string openedWorkspace: ""

    // Selector + text, in the prefix form rank.js understands ("w foo", ">ls")
    readonly property string fullText: mode === ">" ? ">" + filterText : mode ? mode + " " + filterText : filterText
    readonly property var parsed: Rank.parse(fullText)
    readonly property bool moveMode: parsed.letter === "m"
    readonly property string currentWorkspaceName: Hyprland.activeWorkspace?.name ?? ""
    readonly property string currentMonitorName: Hyprland.focusedMonitor?.name ?? ""

    // Visible windows, with geometry and focus order from the last IPC refresh (show()).
    // windows follows windowsLive once per event-loop turn: refreshToplevels() updates the
    // toplevels one at a time, and a plain binding rebuilt the list and the preview
    // captures once per window (18-36 times on every open: the stutter).
    property var windows: []
    onWindowsLiveChanged: Qt.callLater(syncWindows)
    Component.onCompleted: syncWindows()
    function syncWindows() { windows = windowsLive }
    readonly property var windowsLive: {
        var out = []
        var tls = Hyprland.toplevels.values
        for (var i = 0; i < tls.length; i++) {
            var t = tls[i]
            var o = t.lastIpcObject || {}
            if (o.hidden) continue
            var cls = o["class"] || ""
            var at = o.at || [0, 0], sz = o.size || [0, 0]
            out.push({
                address: hexAddress(t.address),
                title: t.title || o.title || "",
                cls: cls,
                workspace: t.workspace ? t.workspace.name : "",
                focus: o.focusHistoryID ?? 999,
                icon: normalizeAppId(cls),
                x: at[0], y: at[1], w: sz[0], h: sz[1],
                wayland: t.wayland
            })
        }
        return out
    }

    // "special" / "special:*" workspaces are always hidden
    readonly property var workspaces: Hyprland.workspaces.values.filter(function(ws) {
        return ws.name && ws.name !== "special" && !ws.name.startsWith("special:")
            && Config.pickerExcludedWorkspaces.indexOf(ws.name) < 0
    })

    readonly property var apps: DesktopEntries.applications.values
        .filter(function(e) { return !e.noDisplay })
        .map(function(e) {
            return { name: e.name, generic: e.genericName || "",
                     hay: ((e.genericName || "") + " " + (e.keywords || []).join(" ")).toLowerCase(),
                     id: e.id, wmClass: e.startupWmClass || "", ref: e,
                     icon: e.icon || "application-x-executable" }
        })

    readonly property var results: {
        if (!pickerVisible) return []
        var shown = windows.filter(function(w) { return !Config.isWindowWorkspaceExcluded(w.workspace) })
        return Rank.build(fullText, {
            windows: shown,
            workspaces: workspaces.map(function(ws) {
                return { name: ws.name, windowTitles: shown.filter(function(w) { return w.workspace === ws.name })
                                                           .map(function(w) { return w.title || w.cls }) }
            }),
            apps: apps,
            currentWorkspace: currentWorkspaceName,
            currentAddress: openedAddress
        })
    }
    readonly property var selected: results[selectedIndex] ?? null

    onFilterTextChanged: selectedIndex = 0   // Enter = first row
    onModeChanged: selectedIndex = 0
    onResultsChanged: if (selectedIndex >= results.length) selectedIndex = Math.max(0, results.length - 1)

    // === Helpers ===
    function hexAddress(a) { a = String(a); return a.startsWith("0x") ? a : "0x" + a }

    function normalizeAppId(appId) {
        if (!appId) return "application-x-executable"
        return appId.replace(/-browser$/, "").replace(/-wayland$/, "").replace(/-x11$/, "")
    }

    function windowsOn(wsName) {
        return windows.filter(function(w) { return w.workspace === wsName })
    }

    // Logical bounds of the monitor a workspace is on, for the preview
    function monitorFor(wsName) {
        var ws = Hyprland.workspaces.values.find(function(w) { return w.name === wsName })
        var m = ws ? ws.monitor : null
        if (!m || !m.width) return null
        var sc = m.scale || 1
        return { x: m.x, y: m.y, width: m.width / sc, height: m.height / sc }
    }

    // Alt+Enter target: Config.moveWorkspaceTargetMonitor (name or model) if it is another
    // monitor, else the first other one
    function otherMonitor() {
        var cfg = Config.moveWorkspaceTargetMonitor
        var others = Hyprland.monitors.values.filter(function(m) { return m.name !== currentMonitorName })
        var pick = others.find(function(m) {
            return m.name === cfg || (m.lastIpcObject && m.lastIpcObject.model === cfg)
        })
        return (pick || others[0])?.name ?? ""
    }

    function isSelected(address) { return selectedWindows.indexOf(address) >= 0 }

    function toggleSelection(address) {
        selectedWindows = isSelected(address)
            ? selectedWindows.filter(function(a) { return a !== address })
            : selectedWindows.concat([address])
    }

    function clearSelection() { selectedWindows = [] }

    // === Dispatch ===
    function q(s) { return "'" + String(s).replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'" }
    function focusWs(name)  { return "hl.dsp.focus({ workspace = " + q("name:" + name) + " })" }
    function focusWin(addr) { return "hl.dsp.focus({ window = " + q("address:" + addr) + " })" }
    function moveWin(addr, ws) { return "hl.dsp.window.move({ workspace = " + q(ws) + ", window = " + q("address:" + addr) + " })" }
    function closeWin(addr) { return "hl.dsp.window.close({ window = " + q("address:" + addr) + " })" }
    function moveWs(name, mon) { return "hl.dsp.workspace.move({ workspace = " + q("name:" + name) + ", monitor = " + q(mon) + " })" }

    // Lua in groups.lua: porta qui la finestra e ne fa la master (istruzione, non dispatcher)
    function bringMaster(addr) { return "bring_master(" + q(addr) + ")" }

    function run(calls) {
        if (calls.length === 0) return
        var lua = function(c) { return c.indexOf("hl.dsp.") === 0 ? "hl.dispatch(" + c + ")" : c }
        Hyprland.dispatch(calls.length === 1 && calls[0].indexOf("hl.dsp.") === 0 ? calls[0]
            : "function() " + calls.map(lua).join("; ") + " end")
    }

    // === Open / close ===
    function show() {
        Hyprland.refreshToplevels()
        Hyprland.refreshWorkspaces()
        Hyprland.refreshMonitors()
        var t = Hyprland.activeToplevel
        openedAddress = t ? hexAddress(t.address) : ""
        openedTitle = t ? t.title : ""
        openedWorkspace = currentWorkspaceName
        mode = ""
        filterText = ""
        selectedIndex = 0
        clearSelection()
        pickerVisible = true
    }

    function hide() {
        pickerVisible = false
        mode = ""
        filterText = ""
        clearSelection()
    }

    function toggle() { if (pickerVisible) hide(); else show() }

    // === Actions ===
    // Enter / click. Ctrl = bring here, Alt = workspace to the other monitor,
    // Shift = follow (move mode). With Tab-selected windows: a workspace row moves
    // them there, Ctrl+Enter anywhere brings them here.
    function activate(row, modifiers) {
        if (!row) return
        var ctrl = modifiers & Qt.ControlModifier, alt = modifiers & Qt.AltModifier
        var shift = modifiers & Qt.ShiftModifier
        var sel = selectedWindows

        if (ctrl && sel.length > 0) {
            run(sel.map(bringMaster))
        } else if (row.kind === "ws" || row.kind === "new") {
            if (moveMode) {
                if (!openedAddress) return
                var calls = [moveWin(openedAddress, "name:" + row.name)]
                calls = calls.concat(shift ? [focusWs(row.name), focusWin(openedAddress)] : [focusWs(openedWorkspace)])
                run(calls)
            } else if (sel.length > 0) {
                run(sel.map(function(a) { return moveWin(a, "name:" + row.name) }).concat([focusWs(openedWorkspace)]))
            } else if (ctrl && row.kind === "ws") {
                run([moveWs(row.name, currentMonitorName), focusWs(row.name)])
            } else if (alt && row.kind === "ws") {
                var mon = otherMonitor()
                if (mon) run([moveWs(row.name, mon)])
            } else {
                run([focusWs(row.name)])   // a missing named workspace is created
            }
        } else if (row.kind === "win") {
            run([ctrl ? bringMaster(row.address) : focusWin(row.address)])
        } else if (row.kind === "app") {
            row.ref.execute()
        } else if (row.kind === "cmd") {
            Quickshell.execDetached(["zsh", "-c", row.command])
        }
        hide()
    }

    // Alt+Backspace: close the window (or the selected ones), or every window of a
    // workspace. The picker stays open; the lists update from Hyprland's events.
    function closeItem(row) {
        if (!row) return
        if (row.kind === "win") {
            var addrs = selectedWindows.length > 0 ? selectedWindows : [row.address]
            run(addrs.map(closeWin))
            clearSelection()
        } else if (row.kind === "ws") {
            run(windowsOn(row.name).map(function(w) { return closeWin(w.address) }))
        }
    }
}
