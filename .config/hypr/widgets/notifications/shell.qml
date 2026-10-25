import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// Notifications — the notification server (replaces dunst): popups top center on the
// main monitor, history panel. Keys (modules/keybindings.lua):
//   Super+N last one back · Super+Shift+N close all · Super+Ctrl+N action of the top one
//   Super+Alt+N history (↑↓, Enter = action or back on screen, Canc = delete, Esc)
//   Super+D do not disturb (moon in the corner, with the count of what arrived meanwhile)
// Popups: left click = action + close, right click = close; hover or idle pauses the timeout.
// Run with: qs -p .
ShellRoot {
    id: root

    // Every notification seen, newest first, live or not. Plain objects
    // {key, n, app, summary, body, icon, urgency, time, shown, expiresAt}: after
    // changing one, reassign `entries` so the views update.
    property var entries: []
    property int nextKey: 0
    readonly property var shownEntries: entries.filter(function(e) { return e.shown })

    property bool dnd: false
    property int missed: 0       // arrived during do-not-disturb, history only
    onDndChanged: missed = 0

    function touch() { entries = entries.slice() }
    readonly property var mainScreen: {
        for (var i = 0; i < Config.monitors.length; i++) {
            var want = Config.monitors[i]
            var s = Quickshell.screens.find(function(x) { return x.name === want || x.model === want })
            if (s) return s
        }
        return Quickshell.screens[0]
    }

    function show(e) {
        e.shown = true
        e.expiresAt = Date.now() + Config.timeout
        // newest on top
        entries = [e].concat(entries.filter(function(x) { return x !== e }))
    }
    function hide(e) { e.shown = false; touch() }
    function remove(e) {
        entries = entries.filter(function(x) { return x !== e })
        if (e.n) e.n.dismiss()
    }
    function defaultAction(e) {
        if (!e.n) return null
        var a = e.n.actions
        for (var i = 0; i < a.length; i++) if (a[i].identifier === "default") return a[i]
        return a.length > 0 ? a[0] : null
    }
    function activate(e) {
        var a = defaultAction(e)
        if (a) a.invoke()
        hide(e)
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        persistenceSupported: true

        onNotification: function(n) {
            n.tracked = true
            var r = Config.rule(n)
            var e = {
                key: root.nextKey++, n: n, app: n.appName, summary: n.summary, body: n.body,
                icon: n.appIcon, time: new Date(),
                urgency: r === "critical" ? NotificationUrgency.Critical : n.urgency,
                shown: false, expiresAt: 0
            }
            // App closed it, or it was dismissed: keep the text, lose the actions.
            n.closed.connect(function() {
                e.n = null
                if (e.shown) e.shown = false
                root.touch()
            })
            // Same notification updated in place (replaces_id): back on screen, fresh text.
            n.summaryChanged.connect(function() { e.summary = n.summary; root.show(e) })
            n.bodyChanged.connect(function() { e.body = n.body; root.show(e) })

            var all = [e].concat(root.entries)
            while (all.length > Config.historyLength) {
                var old = all.pop()
                if (old.n) old.n.dismiss()
            }
            root.entries = all
            if (r === "hide") return
            if (root.dnd && !(Config.dndAllowCritical && e.urgency === NotificationUrgency.Critical)) root.missed++
            else root.show(e)
        }
    }

    // Expiry: one clock for every popup; paused while hovered or while away from the PC.
    IdleMonitor { id: idle; timeout: Config.idleSeconds }
    Timer {
        interval: 250; repeat: true; running: root.shownEntries.length > 0
        onTriggered: {
            var now = Date.now(), changed = false
            root.entries.forEach(function(e) {
                if (!e.shown || e.expiresAt === 0) return
                if (idle.isIdle || popupHover.hovered) e.expiresAt += interval
                else if (e.expiresAt <= now) { e.shown = false; changed = true }
            })
            if (changed) root.touch()
        }
    }

    GlobalShortcut {
        name: "notif-pop"
        description: "Last hidden notification back on screen"
        onPressed: {
            var e = root.entries.find(function(x) { return !x.shown })
            if (e) root.show(e)
        }
    }
    GlobalShortcut {
        name: "notif-close-all"
        description: "Close every notification popup"
        onPressed: { root.entries.forEach(function(e) { e.shown = false }); root.touch() }
    }
    GlobalShortcut {
        name: "notif-clean"
        description: "Close the popups and the history (Super+Esc)"
        onPressed: {
            history.visible = false
            root.entries.forEach(function(e) { e.shown = false })
            root.touch()
        }
    }
    GlobalShortcut {
        name: "notif-action"
        description: "Default action of the top notification"
        onPressed: if (root.shownEntries.length > 0) root.activate(root.shownEntries[0])
    }
    GlobalShortcut {
        name: "notif-dnd"
        description: "Toggle do not disturb"
        onPressed: {
            root.dnd = !root.dnd
            if (root.dnd) { root.entries.forEach(function(e) { e.shown = false }); root.touch() }
        }
    }
    GlobalShortcut {
        name: "notif-history"
        description: "Toggle the notification history"
        onPressed: history.visible = !history.visible
    }

    // ── Popups ──────────────────────────────────────────────────────────────
    PanelWindow {
        screen: root.mainScreen
        visible: root.shownEntries.length > 0
        anchors.top: true
        margins.top: Config.topMargin
        implicitWidth: Math.round(Config.width * Theme.textScale)
        implicitHeight: popupColumn.implicitHeight
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "notifications"
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        // Hover pauses the timeouts. Recreated every time the popups appear: a window that
        // disappears under the pointer never gets the leave event, so `hovered` stayed stuck
        // at true and no popup ever expired again.
        Loader {
            id: popupHover
            anchors.fill: parent
            active: parent.visible
            readonly property bool hovered: item ? item.hovered : false
            sourceComponent: Item {
                readonly property alias hovered: hh.hovered
                HoverHandler { id: hh }
            }
        }

        ColumnLayout {
            id: popupColumn
            width: parent.width
            spacing: Config.spacing

            Repeater {
                model: root.shownEntries.slice(0, Config.maxVisible)
                delegate: NotificationCard {
                    required property var modelData
                    entry: modelData
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                visible: root.shownEntries.length > Config.maxVisible
                Layout.fillWidth: true
                implicitHeight: moreText.implicitHeight + 12
                color: Theme.pickerBackground
                border.color: Theme.outline
                border.width: Theme.borderWidthInner
                Text {
                    id: moreText
                    anchors.centerIn: parent
                    text: "+" + (root.shownEntries.length - Config.maxVisible)
                    color: Theme.pickerSecondaryText
                    font.pixelSize: Math.round((Config.fontSize - 2) * Theme.textScale)
                    font.family: Theme.fontFamily
                }
            }
        }
    }

    component NotificationCard: Rectangle {
        id: card
        property var entry
        readonly property var n: entry.n
        readonly property color tint: entry.urgency === NotificationUrgency.Critical ? Theme.warning
                                    : Theme.pickerSecondaryText   // the app name stays quiet; only critical is coloured
        readonly property string iconSource: {
            if (n && n.image) return n.image
            var i = entry.icon || ""
            if (i.startsWith("/")) return "file://" + i
            if (i.startsWith("file://")) return i
            return i ? Quickshell.iconPath(i, true) : ""
        }
        readonly property var extraActions: n ? n.actions.filter(function(a) { return a.identifier !== "default" }) : []

        implicitHeight: cardRow.implicitHeight + 32
        color: Theme.pickerBackground
        border.color: entry.urgency === NotificationUrgency.Critical ? Theme.warning : Theme.outline
        border.width: Theme.borderWidth
        radius: Theme.radius

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(m) {
                if (m.button === Qt.RightButton) root.hide(card.entry)
                else root.activate(card.entry)
            }
        }

        RowLayout {
            id: cardRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad
            spacing: Theme.gap

            Image {
                visible: card.iconSource !== "" && status !== Image.Error
                source: card.iconSource
                Layout.preferredWidth: Config.iconSize
                Layout.preferredHeight: Config.iconSize
                Layout.alignment: Qt.AlignTop
                sourceSize.width: Config.iconSize
                sourceSize.height: Config.iconSize
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: card.entry.app
                        color: card.tint
                        font.pixelSize: Math.round((Config.fontSize - 3) * Theme.textScale)
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                    Text {
                        text: Qt.formatTime(card.entry.time, "hh:mm")
                        color: Theme.pickerSecondaryText
                        font.pixelSize: Math.round((Config.fontSize - 3) * Theme.textScale)
                        font.family: Theme.fontFamily
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: card.entry.summary
                    color: Theme.pickerText
                    font.pixelSize: Math.round((Config.fontSize + 1) * Theme.textScale)
                    font.family: Theme.fontFamily
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                Text {
                    visible: text !== ""
                    Layout.fillWidth: true
                    text: card.entry.body
                    color: Theme.pickerText
                    font.pixelSize: Math.round((Config.fontSize) * Theme.textScale)
                    font.family: Theme.fontFamily
                    wrapMode: Text.Wrap
                    maximumLineCount: Config.bodyLines
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    linkColor: Theme.accent
                    onLinkActivated: function(url) { Qt.openUrlExternally(url) }
                }
                Flow {
                    visible: card.extraActions.length > 0
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 8
                    Repeater {
                        model: card.extraActions
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: actText.implicitWidth + 24
                            implicitHeight: actText.implicitHeight + 10
                            color: actMouse.containsMouse ? Theme.pickerItemSelected : Theme.pickerInputBackground
                            border.color: Theme.pickerInputBorder
                            border.width: Theme.borderWidthInner
                            Text {
                                id: actText
                                anchors.centerIn: parent
                                text: modelData.text
                                color: Theme.pickerText
                                font.pixelSize: Math.round((Config.fontSize - 2) * Theme.textScale)
                                font.family: Theme.fontFamily
                            }
                            MouseArea {
                                id: actMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { modelData.invoke(); root.hide(card.entry) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Do not disturb: moon in the corner (click-through) ─────────────────
    PanelWindow {
        screen: root.mainScreen
        visible: root.dnd
        anchors.top: Config.dndCorner.startsWith("top")
        anchors.bottom: Config.dndCorner.startsWith("bottom")
        anchors.left: Config.dndCorner.endsWith("left")
        anchors.right: Config.dndCorner.endsWith("right")
        margins.top: Config.dndMargin
        margins.bottom: Config.dndMargin
        margins.left: Config.dndMargin
        margins.right: Config.dndMargin
        implicitWidth: dndRow.implicitWidth + 28
        implicitHeight: dndRow.implicitHeight + 20
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "notifications-dnd"
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.pickerBackground
            border.color: Theme.outline
            border.width: Theme.borderWidth

            RowLayout {
                id: dndRow
                anchors.centerIn: parent
                spacing: 12

                // Hand-drawn crescent (theme-independent, like the volume speaker)
                Canvas {
                    Layout.preferredWidth: Config.dndSize
                    Layout.preferredHeight: Config.dndSize
                    antialiasing: true
                    onPaint: {
                        var ctx = getContext("2d"), r = width / 2
                        ctx.reset()
                        ctx.fillStyle = Theme.accent
                        ctx.beginPath(); ctx.arc(r, r, r * 0.9, 0, 2 * Math.PI); ctx.fill()
                        ctx.globalCompositeOperation = "destination-out"
                        ctx.beginPath(); ctx.arc(r * 1.45, r * 0.7, r * 0.8, 0, 2 * Math.PI); ctx.fill()
                    }
                }
                Text {
                    visible: root.missed > 0
                    text: root.missed
                    color: Theme.pickerText
                    font.pixelSize: Math.round((Config.fontSize + 2) * Theme.textScale)
                    font.family: Theme.fontFamily
                    font.bold: true
                }
            }
        }
    }

    // ── History (Super+Alt+N) ───────────────────────────────────────────────
    PanelWindow {
        id: history
        visible: false
        screen: root.mainScreen
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "notifications-history"
        exclusionMode: ExclusionMode.Ignore
        color: Qt.rgba(0, 0, 0, Theme.dimAround)

        // Click outside closes (delayed so the grab doesn't catch the opening keypress)
        property bool grab: false
        Timer { id: grabDelay; interval: 100; onTriggered: history.grab = true }
        onVisibleChanged: {
            if (visible) { list.currentIndex = 0; list.forceActiveFocus(); grabDelay.start() }
            else grab = false
        }
        HyprlandFocusGrab { windows: [history]; active: history.grab; onCleared: history.visible = false }

        function choose(e) {
            history.visible = false
            if (root.defaultAction(e)) root.activate(e)
            else root.show(e)
        }

        Rectangle {
            anchors.centerIn: parent
            width: Config.width
            height: Math.min(parent.height * 0.7, list.contentHeight + header.height + 40)
            color: Theme.pickerBackground
            border.color: Theme.pickerBorder
            border.width: Theme.borderWidth
            radius: Theme.radius

            Text {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Theme.pad
                text: root.entries.length > 0 ? "Notifiche · " + root.entries.length : "Nessuna notifica"
                color: Theme.pickerSecondaryText
                font.pixelSize: Math.round((Config.fontSize - 2) * Theme.textScale)
                font.family: Theme.fontFamily
            }

            ListView {
                id: list
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                clip: true
                model: root.entries
                focus: true
                keyNavigationWraps: true
                highlightMoveDuration: 0

                Keys.onEscapePressed: history.visible = false
                Keys.onReturnPressed: if (currentIndex >= 0) history.choose(root.entries[currentIndex])
                Keys.onEnterPressed: if (currentIndex >= 0) history.choose(root.entries[currentIndex])
                Keys.onDeletePressed: {
                    if (currentIndex < 0) return
                    var i = currentIndex
                    root.remove(root.entries[i])
                    currentIndex = Math.min(i, root.entries.length - 1)
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    implicitHeight: histCol.implicitHeight + 16
                    color: ListView.isCurrentItem ? Theme.pickerItemSelected
                         : histMouse.containsMouse ? Theme.pickerItemHover : "transparent"

                    ColumnLayout {
                        id: histCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: Qt.formatTime(modelData.time, "hh:mm")
                                color: Theme.pickerSecondaryText
                                font.pixelSize: Math.round((Config.fontSize - 3) * Theme.textScale)
                                font.family: Theme.fontFamily
                            }
                            Text {
                                text: modelData.app
                                color: modelData.urgency === NotificationUrgency.Critical ? Theme.warning : Theme.accent
                                font.pixelSize: Math.round((Config.fontSize - 3) * Theme.textScale)
                                font.family: Theme.fontFamily
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.summary
                                color: Theme.pickerText
                                font.pixelSize: Math.round((Config.fontSize) * Theme.textScale)
                                font.family: Theme.fontFamily
                                font.bold: true
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                        }
                        Text {
                            visible: text !== ""
                            Layout.fillWidth: true
                            text: modelData.body.replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
                            color: Theme.pickerSecondaryText
                            font.pixelSize: Math.round((Config.fontSize - 2) * Theme.textScale)
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }
                    MouseArea {
                        id: histMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: history.choose(modelData)
                    }
                }
            }
        }
    }
}
