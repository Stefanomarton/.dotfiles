import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: picker

    visible: SmartPickerManager.pickerVisible

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
    WlrLayershell.namespace: "smart-picker"

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Click-outside-to-close
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
        onCleared: SmartPickerManager.hide()
    }

    // Mode for workspace input (move to specific workspace)
    property string mode: "normal"  // "normal" or "workspaceInput"
    property string workspaceInputText: ""

    // Warm up the Wayland toplevel manager at shell startup so live window
    // captures in the workspace preview are ready the moment the picker opens
    // (the foreign-toplevel list takes ~1-2s to fill after first access).
    Component.onCompleted: { var warm = ToplevelManager.toplevels }

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
            var natural = 30 + searchContainer.height + listContainer.implicitHeight + hintsRow.height + 40
            var cap = Config.pickerMaxHeight
            // Leave room for the preview pane below when it is shown
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

            // Title (reflects the active narrow/move mode)
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 4
                spacing: 1

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        if (SmartPickerManager.moveMode) return "Move window → workspace"
                        if (SmartPickerManager.narrowLetter === "w") return "Workspaces"
                        if (SmartPickerManager.narrowLetter === "p") return "Windows"
                        if (SmartPickerManager.narrowLetter === "a") return "Applications"
                        return "Smart Picker"
                    }
                    color: SmartPickerManager.moveMode ? Theme.base0A : Theme.pickerText
                    font.pixelSize: 14
                    font.bold: true
                }

                // In move mode, show which window will be moved
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: SmartPickerManager.moveMode
                    text: "moving: " + (SmartPickerManager.currentWindowTitle || "(no focused window)")
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.maximumWidth: card.width - 40
                }
            }

            // Search input container
            Rectangle {
                id: searchContainer
                Layout.fillWidth: true
                Layout.preferredHeight: mode === "workspaceInput" ? Config.pickerInputHeight * 2 + 8 : Config.pickerInputHeight
                color: "transparent"

                // Main search input
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Config.pickerInputHeight
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
                        enabled: mode === "normal"

                        text: SmartPickerManager.filterText
                        onTextChanged: SmartPickerManager.filterText = text

                        // Placeholder
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search…   w· p· a· m + space to narrow"
                            color: Theme.pickerPlaceholder
                            font.pixelSize: Config.pickerFontSize
                            visible: !searchInput.text && mode === "normal"
                        }

                        // Column-aware navigation: ↑↓ move within the active
                        // column, ←→ switch columns (keeping the row position).
                        Keys.onUpPressed: {
                            var W = SmartPickerManager.workspaceCount
                            var i = SmartPickerManager.selectedIndex
                            var floor = i < W ? 0 : W
                            if (i - 1 >= floor) SmartPickerManager.selectedIndex = i - 1
                        }
                        Keys.onDownPressed: {
                            var W = SmartPickerManager.workspaceCount
                            var N = SmartPickerManager.results.length
                            var i = SmartPickerManager.selectedIndex
                            var ceil = i < W ? W : N
                            if (i + 1 < ceil) SmartPickerManager.selectedIndex = i + 1
                        }
                        Keys.onLeftPressed: function(event) {
                            var W = SmartPickerManager.workspaceCount
                            var i = SmartPickerManager.selectedIndex
                            if (i >= W && W > 0)
                                SmartPickerManager.selectedIndex = Math.min(i - W, W - 1)
                            event.accepted = true
                        }
                        Keys.onRightPressed: function(event) {
                            var W = SmartPickerManager.workspaceCount
                            var N = SmartPickerManager.results.length
                            var i = SmartPickerManager.selectedIndex
                            if (i < W && N > W)
                                SmartPickerManager.selectedIndex = Math.min(W + i, N - 1)
                            event.accepted = true
                        }

                        Keys.onReturnPressed: function(event) {
                            handleKeyActivation(event.modifiers)
                        }

                        Keys.onEnterPressed: function(event) {
                            handleKeyActivation(event.modifiers)
                        }

                        Keys.onEscapePressed: {
                            if (mode === "workspaceInput") {
                                mode = "normal"
                                workspaceInputText = ""
                                SmartPickerManager.clearSelection()
                                searchInput.forceActiveFocus()
                            } else {
                                SmartPickerManager.resetToOriginalWorkspace()
                                resetDelayTimer.start()
                            }
                        }

                        Keys.onTabPressed: {
                            var results = SmartPickerManager.results
                            var idx = SmartPickerManager.selectedIndex
                            if (results.length > 0 && idx < results.length) {
                                var item = results[idx]
                                if (item.type === SmartPickerManager.typeWindow) {
                                    // Toggle selection for windows
                                    SmartPickerManager.toggleSelection(item.address)
                                    event.accepted = true
                                    return
                                }
                            }
                            event.accepted = true
                        }

                        // Alt+Backspace to close window or destroy workspace
                        Keys.onPressed: function(event) {
                            if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) &&
                                (event.modifiers & Qt.AltModifier)) {
                                var results = SmartPickerManager.results
                                var idx = SmartPickerManager.selectedIndex
                                if (results.length > 0 && idx < results.length) {
                                    var item = results[idx]
                                    if (item.type === SmartPickerManager.typeWindow) {
                                        if (SmartPickerManager.selectedWindows.length > 0) {
                                            closeSelectedWindows()
                                        } else {
                                            SmartPickerManager.closeWindow(item.address)
                                        }
                                    } else if (item.type === SmartPickerManager.typeWorkspace) {
                                        // Destroy workspace - close all windows in it
                                        SmartPickerManager.destroyWorkspace(item.name)
                                    }
                                }
                                event.accepted = true
                            }
                        }

                        function handleKeyActivation(modifiers) {
                            // "m " mode: move the current window to a workspace.
                            // Enter = move (stay), Shift+Enter = move and follow.
                            if (SmartPickerManager.moveMode) {
                                var mResults = SmartPickerManager.results
                                var mIdx = SmartPickerManager.selectedIndex
                                var wsName = ""
                                if (mResults.length > 0 && mIdx < mResults.length &&
                                    mResults[mIdx].type === SmartPickerManager.typeWorkspace) {
                                    wsName = mResults[mIdx].name
                                } else if (SmartPickerManager.effectiveQuery.trim()) {
                                    wsName = SmartPickerManager.effectiveQuery.trim()
                                }
                                if (wsName) {
                                    SmartPickerManager.moveCurrentWindowToWorkspace(
                                        wsName, (modifiers & Qt.ShiftModifier) !== 0)
                                }
                                return
                            }
                            if (modifiers & Qt.ControlModifier) {
                                // Check if we should start workspace input mode
                                var results = SmartPickerManager.results
                                var idx = SmartPickerManager.selectedIndex
                                if (results.length > 0 && idx < results.length) {
                                    var item = results[idx]
                                    if (item.type === SmartPickerManager.typeWindow) {
                                        if (SmartPickerManager.selectedWindows.length === 0) {
                                            // Auto-select current
                                            SmartPickerManager.toggleSelection(item.address)
                                        }
                                        if (SmartPickerManager.selectedWindows.length > 0) {
                                            // Start workspace input mode
                                            mode = "workspaceInput"
                                            workspaceInputText = ""
                                            workspaceInputField.forceActiveFocus()
                                            return
                                        }
                                    }
                                }
                            }
                            activateCurrentItem(modifiers)
                        }

                        function activateCurrentItem(modifiers) {
                            var results = SmartPickerManager.results
                            var idx = SmartPickerManager.selectedIndex
                            if (results.length > 0 && idx < results.length) {
                                var item = results[idx]
                                // Handle multi-select for windows
                                if (item.type === SmartPickerManager.typeWindow &&
                                    SmartPickerManager.selectedWindows.length > 0 &&
                                    !SmartPickerManager.isSelected(item.address)) {
                                    // Move selected windows instead of focusing
                                    if (modifiers & Qt.ControlModifier) {
                                        SmartPickerManager.moveMultipleToCurrent(SmartPickerManager.selectedWindows)
                                    } else {
                                        SmartPickerManager.moveMultipleToWorkspace(
                                            SmartPickerManager.selectedWindows,
                                            SmartPickerManager.currentWorkspaceName
                                        )
                                    }
                                } else {
                                    SmartPickerManager.activateItem(item, modifiers)
                                }
                            } else if (SmartPickerManager.effectiveQuery.trim()) {
                                // No match - create workspace with the typed text
                                SmartPickerManager.createAndSwitchToWorkspace(SmartPickerManager.effectiveQuery.trim())
                            }
                        }

                        function closeSelectedWindows() {
                            if (SmartPickerManager.selectedWindows.length > 0) {
                                var commands = []
                                for (var i = 0; i < SmartPickerManager.selectedWindows.length; i++) {
                                    commands.push("hl.dispatch(hl.dsp.window.close({ window = 'address:" + SmartPickerManager.selectedWindows[i] + "' }))")
                                }
                                closeProcess.command = ["hyprctl", "eval", commands.join("; ")]
                                closeProcess.running = true
                            }
                        }

                        Timer {
                            id: resetDelayTimer
                            interval: 50
                            onTriggered: SmartPickerManager.hide()
                        }

                        Process {
                            id: closeProcess
                            running: false
                        }

                        Component.onCompleted: forceActiveFocus()

                        Connections {
                            target: SmartPickerManager
                            function onPickerVisibleChanged() {
                                if (SmartPickerManager.pickerVisible) {
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }

                        // Preview timer
                        Timer {
                            id: previewTimer
                            interval: 0
                            repeat: false
                            onTriggered: {
                                if (!Config.pickerPreviewOnNavigate) return
                                var textLength = searchInput.text.trim().length
                                if (textLength < Config.pickerPreviewMinChars) {
                                    SmartPickerManager.resetToOriginalWorkspace()
                                    return
                                }
                                var results = SmartPickerManager.results
                                var idx = SmartPickerManager.selectedIndex
                                if (results.length > 0 && idx < results.length) {
                                    var item = results[idx]
                                    if (item.type === SmartPickerManager.typeWindow && item.workspace) {
                                        SmartPickerManager.previewWorkspace(item.workspace)
                                    } else if (item.type === SmartPickerManager.typeWorkspace) {
                                        SmartPickerManager.previewWorkspace(item.name)
                                    }
                                }
                            }
                        }

                        Connections {
                            target: SmartPickerManager
                            function onSelectedIndexChanged() { previewTimer.start() }
                            function onResultsChanged() { previewTimer.start() }
                        }
                    }
                }

                // Workspace input field (for move to specific workspace)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Config.pickerInputHeight
                    radius: Theme.radius
                    color: Theme.pickerInputBackground
                    border.color: workspaceInputField.activeFocus ? Theme.pickerInputFocusBorder : Theme.pickerInputBorder
                    border.width: workspaceInputField.activeFocus ? 2 : 1
                    visible: mode === "workspaceInput"

                    TextInput {
                        id: workspaceInputField
                        anchors.fill: parent
                        anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.pickerText
                        font.pixelSize: Config.pickerFontSize
                        selectByMouse: true
                        clip: true

                        text: workspaceInputText
                        onTextChanged: workspaceInputText = text

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Enter target workspace..."
                            color: Theme.pickerPlaceholder
                            font.pixelSize: Config.pickerFontSize
                            visible: !workspaceInputField.text && !workspaceInputField.activeFocus
                        }

                        Keys.onReturnPressed: handleWorkspaceSelect()
                        Keys.onEnterPressed: handleWorkspaceSelect()

                        Keys.onEscapePressed: {
                            mode = "normal"
                            workspaceInputText = ""
                            SmartPickerManager.clearSelection()
                            searchInput.forceActiveFocus()
                        }

                        function handleWorkspaceSelect() {
                            var wsName = workspaceInputField.text.trim()
                            if (wsName && SmartPickerManager.selectedWindows.length > 0) {
                                SmartPickerManager.moveMultipleToWorkspace(SmartPickerManager.selectedWindows, wsName)
                            }
                        }
                    }
                }
            }

            // Results list
            Rectangle {
                id: listContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radius
                color: Theme.pickerListBackground
                clip: true

                implicitHeight: {
                    var natural = Math.max(wsColumn.contentHeight, winColumn.contentHeight, 80) + 26
                    var cap = Config.pickerMaxHeight - 30 - searchContainer.height - hintsRow.height - 56
                    // Cap to a few rows (+ column header) so the preview stays put
                    if (Config.pickerWorkspacePreview)
                        cap = Math.min(cap, Config.pickerSmartVisibleRows * Config.pickerItemHeight + 44)
                    return Math.min(natural, cap)
                }

                // Two independent columns: workspaces (left), windows + apps
                // (right). Each scrolls on its own; a column hides when empty.
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 10

                    // Left column — Workspaces
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2
                        visible: SmartPickerManager.workspaceResults.length > 0

                        Text {
                            Layout.leftMargin: 10
                            text: SmartPickerManager.moveMode ? "MOVE TO WORKSPACE" : "WORKSPACES"
                            color: Theme.pickerHintText
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 2
                        }
                        ListView {
                            id: wsColumn
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: SmartPickerManager.workspaceResults
                            readonly property int indexBase: 0
                            currentIndex: {
                                var r = SmartPickerManager.selectedIndex - indexBase
                                return (r >= 0 && r < count) ? r : -1
                            }
                            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                            delegate: resultDelegate
                        }
                    }

                    // Right column — Windows + Applications
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2
                        visible: SmartPickerManager.windowResults.length > 0

                        Text {
                            Layout.leftMargin: 10
                            text: "WINDOWS"
                            color: Theme.pickerHintText
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 2
                        }
                        ListView {
                            id: winColumn
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: SmartPickerManager.windowResults
                            readonly property int indexBase: SmartPickerManager.workspaceCount
                            currentIndex: {
                                var r = SmartPickerManager.selectedIndex - indexBase
                                return (r >= 0 && r < count) ? r : -1
                            }
                            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                            delegate: resultDelegate
                        }
                    }
                }

                // Empty state
                Text {
                    anchors.centerIn: parent
                    text: SmartPickerManager.effectiveQuery
                          ? "Press Enter to create workspace \"" + SmartPickerManager.effectiveQuery + "\""
                          : "Start typing to search workspaces, windows, or apps..."
                    color: Theme.pickerSecondaryText
                    font.pixelSize: Config.pickerFontSize
                    visible: SmartPickerManager.results.length === 0
                }

                // Shared row delegate for both columns
                Component {
                    id: resultDelegate
                    Rectangle {
                        id: itemDelegate
                        required property var modelData
                        required property int index
                        readonly property int globalIndex: ListView.view ? ListView.view.indexBase + index : index

                        width: ListView.view ? ListView.view.width : 0
                        height: Config.pickerItemHeight
                        radius: Theme.radius
                        color: {
                            var isWindowSelected = modelData.type === SmartPickerManager.typeWindow &&
                                                   SmartPickerManager.isSelected(modelData.address)
                            if (isWindowSelected) return Theme.base0B
                            if (globalIndex === SmartPickerManager.selectedIndex) return Theme.pickerItemSelected
                            if (itemMouseArea.containsMouse) return Theme.pickerItemHover
                            return "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Selection marker
                            Rectangle {
                                Layout.preferredWidth: 4
                                Layout.preferredHeight: 24
                                radius: Theme.radius
                                color: {
                                    if (modelData.type === SmartPickerManager.typeWindow &&
                                        SmartPickerManager.isSelected(modelData.address)) {
                                        return Theme.base00
                                    }
                                    return getTypeColor(modelData.type)
                                }
                                visible: modelData.type === SmartPickerManager.typeWindow &&
                                         SmartPickerManager.isSelected(modelData.address)
                                         ? true
                                         : itemDelegate.globalIndex === SmartPickerManager.selectedIndex
                            }

                            Image {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                source: Quickshell.iconPath(modelData.icon)
                                sourceSize: Qt.size(24, 24)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || modelData.name
                                    color: {
                                        if (modelData.type === SmartPickerManager.typeWindow &&
                                            SmartPickerManager.isSelected(modelData.address)) {
                                            return Theme.base00
                                        }
                                        return Theme.pickerText
                                    }
                                    font.pixelSize: Config.pickerFontSize
                                    font.bold: modelData.type === SmartPickerManager.typeWorkspace
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: getSubtitleText(modelData)
                                    color: {
                                        if (modelData.type === SmartPickerManager.typeWindow &&
                                            SmartPickerManager.isSelected(modelData.address)) {
                                            return Theme.base01
                                        }
                                        return Theme.pickerSecondaryText
                                    }
                                    font.pixelSize: Config.pickerFontSize - 4
                                    elide: Text.ElideRight
                                }
                            }

                            // Window count for workspaces (subtle)
                            Text {
                                visible: modelData.type === SmartPickerManager.typeWorkspace && modelData.windows > 0
                                text: modelData.windows
                                color: Theme.pickerHintText
                                font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: function(mouse) {
                                SmartPickerManager.selectedIndex = itemDelegate.globalIndex
                                if (mouse.modifiers & Qt.ControlModifier) {
                                    if (modelData.type === SmartPickerManager.typeWindow) {
                                        SmartPickerManager.toggleSelection(modelData.address)
                                    }
                                } else {
                                    SmartPickerManager.activateItem(modelData, mouse.modifiers)
                                }
                            }
                        }
                    }
                }
            }

            // Hints row
            Row {
                id: hintsRow
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 14
                visible: mode === "normal"

                Text {
                    text: "↑↓ Navigate"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "←→ Column"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                    visible: !SmartPickerManager.moveMode &&
                             SmartPickerManager.workspaceResults.length > 0 &&
                             SmartPickerManager.windowResults.length > 0
                }
                Text {
                    text: "Enter Move"
                    color: Theme.base0A
                    font.pixelSize: 13
                    font.bold: true
                    visible: SmartPickerManager.moveMode
                }
                Text {
                    text: "Shift+Enter Move+Focus"
                    color: Theme.base0A
                    font.pixelSize: 13
                    font.bold: true
                    visible: SmartPickerManager.moveMode
                }
                Text {
                    text: "Enter Activate"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                    visible: !SmartPickerManager.moveMode
                }
                Text {
                    text: "Tab Select"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                    visible: SmartPickerManager.results.length > 0 &&
                             SmartPickerManager.results[SmartPickerManager.selectedIndex]?.type === SmartPickerManager.typeWindow
                }
                Text {
                    text: "Ctrl+Enter Move→"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                    visible: !SmartPickerManager.moveMode &&
                             SmartPickerManager.results.length > 0 &&
                             SmartPickerManager.results[SmartPickerManager.selectedIndex]?.type === SmartPickerManager.typeWorkspace
                }
                Text {
                    text: "Ctrl+Enter →Current"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                    visible: SmartPickerManager.results.length > 0 &&
                             SmartPickerManager.results[SmartPickerManager.selectedIndex]?.type === SmartPickerManager.typeWindow &&
                             SmartPickerManager.selectedWindows.length === 0
                }
                Text {
                    text: "Alt+⌫ Close"
                    color: Theme.base0A
                    font.pixelSize: 13
                    font.bold: true
                    visible: SmartPickerManager.results.length > 0 &&
                             (SmartPickerManager.results[SmartPickerManager.selectedIndex]?.type === SmartPickerManager.typeWindow ||
                              SmartPickerManager.results[SmartPickerManager.selectedIndex]?.type === SmartPickerManager.typeWorkspace)
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
                visible: mode === "normal" && SmartPickerManager.selectedWindows.length > 0

                Text {
                    text: SmartPickerManager.selectedWindows.length + " windows selected"
                    color: Theme.base0B
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Ctrl+Enter →Workspace"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                }
            }

            // Workspace input hint
            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 14
                visible: mode === "workspaceInput"

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
                    text: SmartPickerManager.selectedWindows.length + " windows"
                    color: Theme.base0B
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }
    }

    // === Workspace layout preview (live mini-map) ===
    // Shown beside the card when a workspace is highlighted. Draws each window
    // as a tile at its real position/size, filled with a live capture of the
    // window (Hyprland toplevel export), falling back to the app icon.
    Rectangle {
        id: previewPane

        // Workspace to preview: the highlighted workspace, or the workspace the
        // highlighted window lives on (keeps the preview useful and the layout
        // stable while navigating windows too).
        property string wsName: {
            var results = SmartPickerManager.results
            var idx = SmartPickerManager.selectedIndex
            if (results.length > 0 && idx >= 0 && idx < results.length) {
                var it = results[idx]
                if (it.type === SmartPickerManager.typeWorkspace) return it.name
                if (it.type === SmartPickerManager.typeWindow) return it.workspace
            }
            return ""
        }
        property var wsWindows: wsName ? SmartPickerManager.windowsForWorkspace(wsName) : []
        property var mon: wsName ? SmartPickerManager.monitorForWorkspace(wsName) : null

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

        visible: Config.pickerWorkspacePreview && wsName !== "" && wsWindows.length > 0 && frame !== null

        readonly property int pad: 14
        // Fit the monitor's aspect ratio within a max box (width × height),
        // driven by height so the preview stays big but fits below the list.
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
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - countLabel.width - parent.spacing
                }
                Text {
                    id: countLabel
                    text: previewPane.wsWindows.length + (previewPane.wsWindows.length === 1 ? " window" : " windows")
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
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
                        width: f ? Math.max(6, modelData.w / f.width * previewPane.mapW) : 0
                        height: f ? Math.max(6, modelData.h / f.height * previewPane.mapH) : 0

                        radius: Theme.radius
                        color: Theme.pickerItemHover
                        border.color: Theme.pickerBorder
                        border.width: Theme.borderWidth
                        clip: true

                        // Matching Wayland toplevel for a live capture (or null)
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

                        // Fallback: app icon centered when there is no live capture
                        Image {
                            anchors.centerIn: parent
                            width: Math.min(28, parent.width * 0.6)
                            height: width
                            source: Quickshell.iconPath(modelData.icon)
                            sourceSize: Qt.size(32, 32)
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

    // Helper functions
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

    function getTypeColor(type) {
        if (type === SmartPickerManager.typeWorkspace) return Theme.base08
        if (type === SmartPickerManager.typeWindow) return Theme.base0D
        if (type === SmartPickerManager.typeApplication) return Theme.base0B
        return Theme.pickerSecondaryText
    }

    function getSubtitleText(item) {
        if (item.type === SmartPickerManager.typeWorkspace) {
            if (item.windowList && item.windowList.length > 0) {
                var names = []
                for (var i = 0; i < Math.min(item.windowList.length, 3); i++) {
                    names.push(item.windowList[i].title || item.windowList[i].class)
                }
                var result = names.join(", ")
                if (item.windowList.length > 3) {
                    result += " +" + (item.windowList.length - 3) + " more"
                }
                return result
            }
            return "Empty workspace"
        }
        if (item.type === SmartPickerManager.typeWindow) {
            return (item.className || "Window") + " — " + item.workspace
        }
        if (item.type === SmartPickerManager.typeApplication) {
            return item.className || "Application"
        }
        return ""
    }

    // Reset when hidden
    Connections {
        target: SmartPickerManager
        function onPickerVisibleChanged() {
            if (!SmartPickerManager.pickerVisible) {
                picker.mode = "normal"
                picker.workspaceInputText = ""
            }
        }
    }
}
