import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: picker

    visible: WindowManager.pickerVisible

    // Show on configured monitor
    screen: {
        if (Config.pickerMonitor === "focused") {
            return Quickshell.screens.find(function(s) {
                return Hyprland.focusedMonitor !== null && s.name === Hyprland.focusedMonitor.name
            }) ?? Quickshell.screens[0]
        } else {
            return Quickshell.screens.find(function(s) {
                return s.name === Config.pickerMonitor
            }) ?? Quickshell.screens[0]
        }
    }

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "window-picker"

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Warm up the Wayland toplevel manager for live preview captures.
    Component.onCompleted: { var warm = ToplevelManager.toplevels }

    // Mode: "normal" or "workspaceInput" (for Ctrl+Return multi-move)
    property string mode: "normal"
    property string workspaceInputText: ""

    // Click-outside-to-close (delayed to allow focus to settle)
    property bool focusGrabActive: false
    Timer {
        id: focusGrabDelay
        interval: 100
        onTriggered: picker.focusGrabActive = true
    }
    onVisibleChanged: {
        if (visible) {
            focusGrabDelay.start()
        } else {
            focusGrabActive = false
        }
    }
    HyprlandFocusGrab {
        windows: [picker]
        active: picker.focusGrabActive
        onCleared: WindowManager.hide()
    }

    // Main card container
    Rectangle {
        id: card
        // List on top, preview pane below — center the whole stack vertically.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: previewPane.visible ? -(previewPane.height + 16) / 2 : 0
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
        width: Config.pickerWidth
        height: {
            var natural = 30 + Config.pickerInputHeight + 16 + listContainer.implicitHeight + hintsRow.height + 32
            var cap = Config.pickerMaxHeight
            if (previewPane.visible)
                cap = Math.min(cap, picker.height - previewPane.height - 60)
            return Math.min(cap, natural)
        }
        radius: Config.pickerBorderRadius
        color: Theme.pickerBackground

        // Border
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Theme.pickerBorder
            border.width: Theme.borderWidth
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Title
            Text {
                text: "Windows"
                color: Theme.pickerText
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 4
            }

            // Search input
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Config.pickerInputHeight
                radius: Theme.radius
                color: Theme.pickerInputBackground
                border.color: searchInput.activeFocus ? Theme.pickerInputFocusBorder : Theme.pickerInputBorder
                border.width: searchInput.activeFocus ? 2 : 1

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.pickerText
                    font.pixelSize: Config.pickerFontSize
                    selectByMouse: true
                    clip: true
                    enabled: picker.mode === "normal"

                    text: WindowManager.filterText
                    onTextChanged: {
                        WindowManager.filterText = text
                    }

                    // Placeholder
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search windows..."
                        color: Theme.pickerPlaceholder
                        font.pixelSize: Config.pickerFontSize
                        visible: !searchInput.text && !searchInput.activeFocus && picker.mode === "normal"
                    }

                    Keys.onUpPressed: {
                        if (WindowManager.selectedIndex > 0) {
                            WindowManager.selectedIndex--
                        }
                    }

                    Keys.onDownPressed: {
                        if (WindowManager.selectedIndex < WindowManager.filteredWindows.length - 1) {
                            WindowManager.selectedIndex++
                        }
                    }

                    // Space to toggle selection (when not at start of input)
                    Keys.onSpacePressed: {
                        if (text.length > 0) {
                            event.accepted = false
                            return
                        }
                        var filtered = WindowManager.filteredWindows
                        if (filtered.length > 0 && WindowManager.selectedIndex < filtered.length) {
                            var win = filtered[WindowManager.selectedIndex]
                            WindowManager.toggleSelection(win.address)
                        }
                        event.accepted = true
                    }

                    Keys.onReturnPressed: function(event) {
                        if (event.modifiers & Qt.ControlModifier) {
                            // Ctrl+Return: Move selected windows to current workspace
                            handleSelect()
                        } else {
                            // Return: Focus the selected window
                            handleFocus()
                        }
                    }

                    Keys.onEnterPressed: function(event) {
                        if (event.modifiers & Qt.ControlModifier) {
                            // Ctrl+Enter: Move selected windows to current workspace
                            handleSelect()
                        } else {
                            // Enter: Focus the selected window
                            handleFocus()
                        }
                    }

                    // Alt+Backspace to close selected/highlighted windows
                    Keys.onPressed: function(event) {
                        if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) && 
                            (event.modifiers & Qt.AltModifier)) {
                            // Close selected windows, or highlighted window if none selected
                            if (WindowManager.selectedWindows.length > 0) {
                                WindowManager.closeMultipleWindows(WindowManager.selectedWindows)
                            } else {
                                var filtered = WindowManager.filteredWindows
                                if (filtered.length > 0 && WindowManager.selectedIndex < filtered.length) {
                                    WindowManager.closeMultipleWindows([filtered[WindowManager.selectedIndex].address])
                                }
                            }
                            event.accepted = true
                        }
                    }

                    Keys.onEscapePressed: {
                        // Always restore original workspace before closing
                        WindowManager.resetToOriginalWorkspace()
                        resetDelayTimer.start()
                    }

                    // Timer to delay hide until reset is complete
                    Timer {
                        id: resetDelayTimer
                        interval: 50
                        onTriggered: WindowManager.hide()
                    }

                    function handleFocus() {
                        var filtered = WindowManager.filteredWindows
                        if (filtered.length > 0 && WindowManager.selectedIndex < filtered.length) {
                            var win = filtered[WindowManager.selectedIndex]
                            WindowManager.focusWindow(win.address)
                        }
                    }

                    function handleSelect() {
                        var filtered = WindowManager.filteredWindows
                        if (WindowManager.selectedWindows.length === 0 && 
                            filtered.length > 0 && 
                            WindowManager.selectedIndex < filtered.length) {
                            // Auto-select current if nothing selected, then move it
                            var win = filtered[WindowManager.selectedIndex]
                            WindowManager.moveToCurrentAndFocus(win.address)
                        } else if (WindowManager.selectedWindows.length > 0) {
                            // Multi-select mode: move all selected to current workspace
                            WindowManager.moveMultipleToCurrent(WindowManager.selectedWindows)
                        }
                    }

                    function startWorkspaceInput() {
                        var filtered = WindowManager.filteredWindows
                        if (WindowManager.selectedWindows.length === 0 && 
                            filtered.length > 0 && 
                            WindowManager.selectedIndex < filtered.length) {
                            // Auto-select current if nothing selected
                            WindowManager.toggleSelection(filtered[WindowManager.selectedIndex].address)
                        }
                        if (WindowManager.selectedWindows.length > 0) {
                            picker.mode = "workspaceInput"
                            picker.workspaceInputText = ""
                            workspaceInputField.forceActiveFocus()
                        }
                    }

                    Component.onCompleted: {
                        forceActiveFocus()
                    }
                }

                // Ensure focus when picker becomes visible
                Connections {
                    target: WindowManager
                    function onPickerVisibleChanged() {
                        if (WindowManager.pickerVisible) {
                            searchInput.forceActiveFocus()
                        }
                    }
                }

                // Preview workspace when selection or filter changes
                // Uses a delayed timer to avoid race conditions between signals
                Timer {
                    id: previewTimer
                    interval: 0
                    repeat: false
                    onTriggered: {
                        if (!Config.pickerPreviewOnNavigate) return

                        var textLength = searchInput.text.trim().length
                        if (textLength < Config.pickerPreviewMinChars) {
                            // Below threshold - reset to original workspace
                            WindowManager.resetToOriginalWorkspace()
                            return
                        }

                        var filtered = WindowManager.filteredWindows
                        if (filtered.length > 0 && WindowManager.selectedIndex < filtered.length) {
                            var win = filtered[WindowManager.selectedIndex]
                            if (win.workspace) {
                                WindowManager.previewWorkspace(win.workspace)
                            }
                        }
                    }
                }

                Connections {
                    target: WindowManager
                    function onSelectedIndexChanged() {
                        previewTimer.start()
                    }
                    function onFilteredWindowsChanged() {
                        previewTimer.start()
                    }
                }
            }

            // Workspace input (for Ctrl+Return multi-move)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Config.pickerInputHeight
                radius: Theme.radius
                color: Theme.pickerInputBackground
                border.color: workspaceInputField.activeFocus ? Theme.pickerInputFocusBorder : Theme.pickerInputBorder
                border.width: workspaceInputField.activeFocus ? 2 : 1
                visible: picker.mode === "workspaceInput"

                TextInput {
                    id: workspaceInputField
                    anchors.fill: parent
                    anchors.margins: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.pickerText
                    font.pixelSize: Config.pickerFontSize
                    selectByMouse: true
                    clip: true

                    text: picker.workspaceInputText
                    onTextChanged: picker.workspaceInputText = text

                    // Placeholder
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Enter workspace name..."
                        color: Theme.pickerPlaceholder
                        font.pixelSize: Config.pickerFontSize
                        visible: !workspaceInputField.text && !workspaceInputField.activeFocus
                    }

                    Keys.onReturnPressed: {
                        handleWorkspaceSelect()
                    }

                    Keys.onEnterPressed: {
                        handleWorkspaceSelect()
                    }

                    Keys.onEscapePressed: {
                        picker.mode = "normal"
                        picker.workspaceInputText = ""
                        WindowManager.clearSelection()
                        searchInput.forceActiveFocus()
                    }

                    function handleWorkspaceSelect() {
                        var wsName = workspaceInputField.text.trim()
                        if (wsName) {
                            WindowManager.moveMultipleToWorkspace(WindowManager.selectedWindows, wsName)
                            picker.mode = "normal"
                            picker.workspaceInputText = ""
                        }
                    }
                }
            }

            // Window list
            Rectangle {
                id: listContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radius
                color: Theme.pickerListBackground
                clip: true

                implicitHeight: {
                    var natural = Math.max(windowList.contentHeight, 80)
                    var cap = Config.pickerMaxHeight - 30 - Config.pickerInputHeight - hintsRow.height - 56
                    // Cap to a few rows so the preview below stays put
                    if (Config.pickerWorkspacePreview)
                        cap = Math.min(cap, Config.pickerWindowVisibleRows * Config.pickerItemHeight)
                    return Math.min(natural, cap)
                }

                ListView {
                    id: windowList
                    anchors.fill: parent
                    anchors.margins: 4
                    model: WindowManager.filteredWindows
                    currentIndex: WindowManager.selectedIndex
                    clip: true

                    // Keep the highlighted row scrolled into view.
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: itemDelegate
                        required property var modelData
                        required property int index

                        width: windowList.width
                        height: Config.pickerItemHeight
                        radius: Theme.radius
                        color: {
                            var isSelected = WindowManager.isSelected(itemDelegate.modelData.address)
                            if (isSelected) return Theme.base0B  // Use accent color for selection
                            if (index === WindowManager.selectedIndex) return Theme.pickerItemSelected
                            if (itemMouseArea.containsMouse) return Theme.pickerItemHover
                            return "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Selection indicator
                            Rectangle {
                                Layout.preferredWidth: 4
                                Layout.preferredHeight: 24
                                radius: Theme.radius
                                color: WindowManager.isSelected(itemDelegate.modelData.address) ? Theme.base00 : "transparent"
                                visible: WindowManager.isSelected(itemDelegate.modelData.address)
                            }

                            // App icon
                            Image {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                source: Quickshell.iconPath(itemDelegate.modelData.icon)
                                sourceSize: Qt.size(24, 24)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }

                            // Window info
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                // Title
                                Text {
                                    Layout.fillWidth: true
                                    text: itemDelegate.modelData.title || itemDelegate.modelData.class
                                    color: WindowManager.isSelected(itemDelegate.modelData.address) ? Theme.base00 : Theme.pickerText
                                    font.pixelSize: Config.pickerFontSize
                                    elide: Text.ElideRight
                                }

                                // Class and workspace
                                Text {
                                    Layout.fillWidth: true
                                    text: itemDelegate.modelData.class + " — " + itemDelegate.modelData.workspace
                                    color: WindowManager.isSelected(itemDelegate.modelData.address) ? Theme.base01 : Theme.pickerSecondaryText
                                    font.pixelSize: Config.pickerFontSize - 4
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: function(mouse) {
                                WindowManager.selectedIndex = itemDelegate.index
                                if (mouse.modifiers & Qt.ControlModifier) {
                                    WindowManager.toggleSelection(itemDelegate.modelData.address)
                                } else {
                                    // Single click: focus window
                                    WindowManager.focusWindow(itemDelegate.modelData.address)
                                }
                            }
                        }
                    }

                    // Empty state
                    Text {
                        anchors.centerIn: parent
                        text: WindowManager.filterText
                              ? "No windows match \"" + WindowManager.filterText + "\""
                              : "No windows open"
                        color: Theme.pickerSecondaryText
                        font.pixelSize: Config.pickerFontSize
                        visible: windowList.count === 0
                    }
                }
            }

            // Hint keys row
            Row {
                id: hintsRow
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 14
                visible: picker.mode === "normal"

                Text {
                    text: "↑↓ Navigate"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Space Select"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Enter Focus"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Ctrl+Enter → Current"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Alt+⌫ Close"
                    color: Theme.base0A
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Esc Cancel"
                    color: Theme.pickerHintText
                    font.pixelSize: 13
                }
            }

            // Multi-select hint
            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 8
                visible: picker.mode === "normal" && WindowManager.selectedWindows.length > 0

                Text {
                    text: WindowManager.selectedWindows.length + " selected"
                    color: Theme.base0B
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            // Workspace input hint
            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 14
                visible: picker.mode === "workspaceInput"

                Text {
                    text: "Enter Confirm"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Esc Cancel"
                    color: Theme.pickerHintText
                    font.pixelSize: 13
                }
                Text {
                    text: WindowManager.selectedWindows.length + " windows"
                    color: Theme.base0B
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }
    }

    // === Window's-workspace preview (live mini-map) ===
    // Below the card: the layout of the highlighted window's workspace, with the
    // highlighted window's tile outlined.
    Rectangle {
        id: previewPane

        property string wsName: {
            var f = WindowManager.filteredWindows
            var idx = WindowManager.selectedIndex
            if (f.length > 0 && idx >= 0 && idx < f.length) return f[idx].workspace
            return ""
        }
        property string selectedAddress: {
            var f = WindowManager.filteredWindows
            var idx = WindowManager.selectedIndex
            if (f.length > 0 && idx >= 0 && idx < f.length) return f[idx].address
            return ""
        }
        property var wsWindows: wsName ? WindowManager.windowsForWorkspace(wsName) : []
        property var mon: wsName ? WindowManager.monitorForWorkspace(wsName) : null

        property var frame: {
            if (mon && mon.width > 0 && mon.height > 0) return mon
            if (wsWindows.length === 0) return null
            var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
            for (var i = 0; i < wsWindows.length; i++) {
                var w = wsWindows[i]
                minX = Math.min(minX, w.x); minY = Math.min(minY, w.y)
                maxX = Math.max(maxX, w.x + w.w); maxY = Math.max(maxY, w.y + w.h)
            }
            return { x: minX, y: minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) }
        }

        visible: Config.pickerWorkspacePreview && wsName !== "" && wsWindows.length > 0 && frame !== null

        readonly property int pad: 16
        readonly property real aspect: frame ? (frame.height / frame.width) : (9 / 16)
        readonly property real mapW: Math.min(Config.pickerPreviewWidth - pad * 2, Config.pickerPreviewHeight / aspect)
        readonly property real mapH: mapW * aspect

        width: mapW + pad * 2
        height: pad + previewHeader.height + 8 + mapH + pad
        radius: Config.pickerBorderRadius
        color: Theme.pickerBackground

        anchors.top: card.bottom
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Theme.pickerBorder
            border.width: Theme.borderWidth
        }

        Column {
            anchors.fill: parent
            anchors.margins: previewPane.pad
            spacing: 8

            Row {
                id: previewHeader
                width: parent.width
                spacing: 8
                Text {
                    text: previewPane.wsName
                    color: Theme.pickerText
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - countLabel.width - parent.spacing
                }
                Text {
                    id: countLabel
                    text: previewPane.wsWindows.length + (previewPane.wsWindows.length === 1 ? " window" : " windows")
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: previewPane.mapW
                height: previewPane.mapH
                radius: Theme.radius
                color: Theme.pickerListBackground
                clip: true

                Repeater {
                    model: previewPane.wsWindows

                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        property var f: previewPane.frame
                        readonly property bool isSelected: modelData.address === previewPane.selectedAddress

                        x: f ? (modelData.x - f.x) / f.width * previewPane.mapW : 0
                        y: f ? (modelData.y - f.y) / f.height * previewPane.mapH : 0
                        width: f ? Math.max(8, modelData.w / f.width * previewPane.mapW) : 0
                        height: f ? Math.max(8, modelData.h / f.height * previewPane.mapH) : 0

                        radius: Theme.radius
                        color: Theme.pickerItemHover
                        border.color: isSelected ? Theme.base0B : Theme.pickerBorder
                        border.width: isSelected ? 3 : 1
                        clip: true
                        z: isSelected ? 1 : 0

                        property var tl: Config.pickerWorkspacePreviewLive
                            ? picker.findToplevel(modelData.class, modelData.title)
                            : null

                        ScreencopyView {
                            id: cap
                            anchors.fill: parent
                            anchors.margins: tile.isSelected ? 3 : 1
                            captureSource: tile.tl
                            live: true
                            paintCursor: false
                            constraintSize: Qt.size(Math.max(1, tile.width), Math.max(1, tile.height))
                            visible: tile.tl !== null && hasContent
                        }

                        Image {
                            anchors.centerIn: parent
                            width: Math.min(40, parent.width * 0.6)
                            height: width
                            source: Quickshell.iconPath(modelData.icon)
                            sourceSize: Qt.size(48, 48)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            visible: !cap.visible
                        }
                    }
                }
            }
        }
    }

    // Match a Wayland toplevel to a Hyprland window for a live capture.
    function findToplevel(appId, title) {
        if (!appId) return null
        var tls = ToplevelManager.toplevels.values
        var appOnly = null
        for (var i = 0; i < tls.length; i++) {
            var t = tls[i]
            if (t.appId === appId && t.title === title) return t
            if (t.appId === appId && appOnly === null) appOnly = t
        }
        return appOnly
    }

    // Clear selection when picker is hidden
    Connections {
        target: WindowManager
        function onPickerVisibleChanged() {
            if (!WindowManager.pickerVisible) {
                picker.mode = "normal"
                picker.workspaceInputText = ""
                WindowManager.clearSelection()
            }
        }
    }
}
