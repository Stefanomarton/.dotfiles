import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: picker

    visible: WorkspaceManager.pickerVisible

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
    WlrLayershell.namespace: "workspaces-picker"

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Warm up the Wayland toplevel manager at shell startup so live window
    // captures in the workspace preview are ready the moment the picker opens.
    Component.onCompleted: { var warm = ToplevelManager.toplevels }

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
        onCleared: WorkspaceManager.hide()
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
                text: "Workspaces"
                color: Theme.pickerText
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 4
            }

            // Search/create input
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

                    text: WorkspaceManager.filterText
                    onTextChanged: WorkspaceManager.filterText = text

                    // Placeholder
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search or create workspace..."
                        color: Theme.pickerPlaceholder
                        font.pixelSize: Config.pickerFontSize
                        visible: !searchInput.text && !searchInput.activeFocus
                    }

                    Keys.onUpPressed: {
                        if (WorkspaceManager.selectedIndex > 0) {
                            WorkspaceManager.selectedIndex--
                        }
                    }

                    Keys.onDownPressed: {
                        if (WorkspaceManager.selectedIndex < WorkspaceManager.filteredWorkspaces.length - 1) {
                            WorkspaceManager.selectedIndex++
                        }
                    }

                    Keys.onReturnPressed: function(event) {
                        if (event.modifiers & Qt.AltModifier) {
                            handleMoveToCurrent()
                        } else {
                            handleSelect(event.modifiers & Qt.ControlModifier)
                        }
                    }

                    Keys.onEnterPressed: function(event) {
                        if (event.modifiers & Qt.AltModifier) {
                            handleMoveToCurrent()
                        } else {
                            handleSelect(event.modifiers & Qt.ControlModifier)
                        }
                    }

                    Keys.onEscapePressed: {
                        WorkspaceManager.hide()
                    }

                    Keys.onDeletePressed: {
                        handleDestroy()
                    }

                    // Ctrl+D for destroy
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
                            handleDestroy()
                            event.accepted = true
                        }
                    }

                    function handleSelect(moveToOtherMonitor) {
                        var filtered = WorkspaceManager.filteredWorkspaces
                        if (filtered.length > 0 && WorkspaceManager.selectedIndex < filtered.length) {
                            var ws = filtered[WorkspaceManager.selectedIndex]
                            if (moveToOtherMonitor) {
                                // Move to configured target monitor (or auto-detect)
                                WorkspaceManager.moveToMonitor(ws.name, Config.moveWorkspaceTargetMonitor)
                            } else {
                                // Switch to selected workspace
                                WorkspaceManager.switchTo(ws.name)
                            }
                        } else if (searchInput.text.trim()) {
                            // Create new workspace with input text
                            WorkspaceManager.createAndSwitch(searchInput.text.trim())
                        }
                    }

                    function handleMoveToCurrent() {
                        var filtered = WorkspaceManager.filteredWorkspaces
                        if (filtered.length > 0 && WorkspaceManager.selectedIndex < filtered.length) {
                            var ws = filtered[WorkspaceManager.selectedIndex]
                            WorkspaceManager.moveToCurrentAndFocus(ws.name)
                        }
                    }

                    function handleDestroy() {
                        var filtered = WorkspaceManager.filteredWorkspaces
                        if (filtered.length > 0 && WorkspaceManager.selectedIndex < filtered.length) {
                            var ws = filtered[WorkspaceManager.selectedIndex]
                            // Don't destroy excluded workspaces (they shouldn't appear anyway, but safety check)
                            var excluded = Config.pickerExcludedWorkspaces
                            var isExcluded = false
                            for (var i = 0; i < excluded.length; i++) {
                                if (ws.name === excluded[i]) {
                                    isExcluded = true
                                    break
                                }
                            }
                            if (!isExcluded) {
                                WorkspaceManager.destroyWorkspace(ws.name)
                            }
                        }
                    }

                    Component.onCompleted: {
                        forceActiveFocus()
                    }
                }

                // Ensure focus when picker becomes visible
                Connections {
                    target: WorkspaceManager
                    function onPickerVisibleChanged() {
                        if (WorkspaceManager.pickerVisible) {
                            searchInput.forceActiveFocus()
                        }
                    }
                }
            }

            // Workspace list
            Rectangle {
                id: listContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radius
                color: Theme.pickerListBackground
                clip: true

                implicitHeight: {
                    var natural = Math.max(workspaceList.contentHeight, 80)
                    var cap = Config.pickerMaxHeight - 30 - Config.pickerInputHeight - hintsRow.height - 56
                    // Cap to a few rows when the preview is shown, so the list
                    // stays a fixed height and the preview below doesn't shift.
                    if (Config.pickerWorkspacePreview)
                        cap = Math.min(cap, Config.pickerWorkspaceVisibleRows * 108)
                    return Math.min(natural, cap)
                }

                ListView {
                    id: workspaceList
                    anchors.fill: parent
                    anchors.margins: 4
                    model: WorkspaceManager.filteredWorkspaces
                    currentIndex: WorkspaceManager.selectedIndex
                    clip: true

                    // Keep the highlighted row scrolled into view.
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: itemDelegate
                        required property var modelData
                        required property int index

                        width: workspaceList.width
                        height: hasWindows ? expandedHeight : compactHeight
                        radius: Theme.radius
                        color: index === WorkspaceManager.selectedIndex
                               ? Theme.pickerItemSelected
                               : itemMouseArea.containsMouse
                                 ? Theme.pickerItemHover
                                 : "transparent"

                        readonly property bool hasWindows: itemDelegate.modelData.windowList && itemDelegate.modelData.windowList.length > 0
                        readonly property int windowCount: itemDelegate.modelData.windowList ? itemDelegate.modelData.windowList.length : 0
                        readonly property int compactHeight: 60
                        readonly property int expandedHeight: compactHeight + 48

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 4

                            // Top row: workspace name and window count
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // Workspace name
                                Text {
                                    Layout.fillWidth: true
                                    text: itemDelegate.modelData.name
                                    color: Theme.pickerText
                                    font.pixelSize: Config.pickerFontSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                // Window count
                                Text {
                                    text: itemDelegate.modelData.windows + " window" + (itemDelegate.modelData.windows !== 1 ? "s" : "")
                                    color: Theme.pickerSecondaryText
                                    font.pixelSize: Config.pickerFontSize - 4
                                }
                            }

                            // Window list row (icons + names)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                visible: itemDelegate.hasWindows

                                Repeater {
                                    model: Math.min(itemDelegate.windowCount, 4)  // Show up to 4 windows

                                    RowLayout {
                                        spacing: 6

                                        Image {
                                            Layout.preferredWidth: 18
                                            Layout.preferredHeight: 18
                                            source: Quickshell.iconPath(itemDelegate.modelData.windowList[index]?.icon ?? "application-x-executable")
                                            sourceSize: Qt.size(18, 18)
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            mipmap: true
                                        }

                                        Text {
                                            text: itemDelegate.modelData.windowList[index]?.title || 
                                                  itemDelegate.modelData.windowList[index]?.class || 
                                                  "Window"
                                            color: index === WorkspaceManager.selectedIndex ? Theme.pickerText : Theme.pickerSecondaryText
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 120
                                        }
                                    }
                                }

                                // "+N more" indicator if there are more windows
                                Text {
                                    visible: itemDelegate.windowCount > 4
                                    text: "+" + (itemDelegate.windowCount - 4) + " more"
                                    color: Theme.pickerHintText
                                    font.pixelSize: 12
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                WorkspaceManager.selectedIndex = itemDelegate.index
                                WorkspaceManager.switchTo(itemDelegate.modelData.name)
                            }
                        }
                    }

                    // Empty state
                    Text {
                        anchors.centerIn: parent
                        text: WorkspaceManager.filterText
                              ? "Press Enter to create \"" + WorkspaceManager.filterText + "\""
                              : "No workspaces"
                        color: Theme.pickerSecondaryText
                        font.pixelSize: Config.pickerFontSize
                        visible: workspaceList.count === 0
                    }
                }
            }

            // Hint keys row
            Row {
                id: hintsRow
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 14

                Text {
                    text: "↑↓ Navigate"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Enter Select"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: {
                        var target = Config.moveWorkspaceTargetMonitor
                        if (target === "auto") {
                            target = WorkspaceManager.availableMonitors.length > 0 ? WorkspaceManager.availableMonitors[0] : "other"
                        }
                        return "Ctrl+Enter → " + target
                    }
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                    visible: WorkspaceManager.availableMonitors.length > 0
                }
                Text {
                    text: "Alt+Enter → Here"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                    visible: WorkspaceManager.availableMonitors.length > 0
                }
                Text {
                    text: "Del Destroy"
                    color: Theme.base0A
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Esc Close"
                    color: Theme.pickerHintText
                    font.pixelSize: 13
                }
            }
        }
    }

    // === Workspace layout preview (live mini-map) ===
    // Draws the highlighted workspace's window layout beside the picker, each
    // window a tile filled with a live capture (icon fallback).
    Rectangle {
        id: previewPane

        property var wsItem: {
            var f = WorkspaceManager.filteredWorkspaces
            var idx = WorkspaceManager.selectedIndex
            if (f.length > 0 && idx >= 0 && idx < f.length) return f[idx]
            return null
        }
        property var wsWindows: wsItem ? WorkspaceManager.windowsForWorkspace(wsItem.name) : []
        property var mon: wsItem ? WorkspaceManager.monitorForWorkspace(wsItem.name) : null

        // Coordinate frame to normalize against: the real monitor, or (fallback)
        // the bounding box of the workspace's windows.
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

        visible: Config.pickerWorkspacePreview && wsItem !== null && wsWindows.length > 0 && frame !== null

        readonly property int pad: 16
        // Fit the monitor's aspect ratio within a max box, driven by height so
        // the preview stays big but fits below the list.
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
                    text: previewPane.wsItem ? previewPane.wsItem.name : ""
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

            // Mini-map canvas
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

                        x: f ? (modelData.x - f.x) / f.width * previewPane.mapW : 0
                        y: f ? (modelData.y - f.y) / f.height * previewPane.mapH : 0
                        width: f ? Math.max(8, modelData.w / f.width * previewPane.mapW) : 0
                        height: f ? Math.max(8, modelData.h / f.height * previewPane.mapH) : 0

                        radius: Theme.radius
                        color: Theme.pickerItemHover
                        border.color: Theme.pickerBorder
                        border.width: Theme.borderWidth
                        clip: true

                        property var tl: Config.pickerWorkspacePreviewLive
                            ? picker.findToplevel(modelData.class, modelData.title)
                            : null

                        ScreencopyView {
                            id: cap
                            anchors.fill: parent
                            anchors.margins: 1
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
}
