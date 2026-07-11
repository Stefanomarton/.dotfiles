pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: state

    // Configuration (in seconds) - from Config
    readonly property int focusDuration: Config.focusMinutes * 60
    readonly property int shortBreakDuration: Config.shortBreakMinutes * 60
    readonly property int longBreakDuration: Config.longBreakMinutes * 60
    readonly property int sessionsUntilLongBreak: Config.sessionsUntilLongBreak

    // State
    property bool running: false
    property bool isPaused: false
    property bool isBreak: false
    property int remainingSeconds: focusDuration
    property int completedSessions: 0

    // Current color based on state
    readonly property color currentColor: {
        if (isPaused) return Config.pauseColor
        if (isBreak) return Config.breakColor
        return Config.focusColor
    }

    // Display
    readonly property string timeDisplay: {
        const minutes = Math.floor(remainingSeconds / 60)
        const seconds = remainingSeconds % 60
        return String(minutes).padStart(2, '0') + ":" + String(seconds).padStart(2, '0')
    }

    readonly property string phaseDisplay: {
        if (!running) return "Stopped"
        if (isPaused) return "Paused"
        if (isBreak) return "Break"
        return "Focus"
    }

    property Timer timer: Timer {
        interval: 1000
        repeat: true
        running: state.running && !state.isPaused

        onTriggered: {
            if (state.remainingSeconds > 0) {
                state.remainingSeconds--
            } else {
                state.onPhaseComplete()
            }
        }
    }

    signal showMessage(string text)

    property Process notifier: Process {
        id: notifyProcess
    }

    property Process soundPlayer: Process {
        id: soundProcess
    }

    function playSound(path) {
        if (path === "") return
        // Use sh to ensure PATH is resolved; $1 safely passes paths with spaces
        soundProcess.command = ["sh", "-c", Config.soundCommand + ' "$1"', "--", path]
        soundProcess.running = false
        soundProcess.running = true
    }

    function triggerEvent(message, sound) {
        if (message !== "") showMessage(message)
        playSound(sound)
    }

    property Timer intervalTimer: Timer {
        interval: Config.intervalMinutes * 60 * 1000
        running: state.running && !state.isPaused && !state.isBreak && Config.intervalEnabled
        repeat: true
        onTriggered: state.triggerEvent(Config.intervalMessage, Config.intervalSound)
    }

    function start() {
        if (running && isPaused) {
            isPaused = false
            triggerEvent(Config.focusStartMessage, Config.focusStartSound)
            return
        }

        if (!running) {
            running = true
            isPaused = false
            isBreak = false
            remainingSeconds = focusDuration
            completedSessions = 0
            intervalTimer.restart()
            triggerEvent(Config.focusStartMessage, Config.focusStartSound)
            notifyPhaseChange("Pomodoro Started", "Focus time begins!")
        }
    }

    function togglePause() {
        if (running) {
            isPaused = !isPaused
            if (isPaused) {
                triggerEvent(Config.pauseMessage, Config.pauseSound)
                notifyPhaseChange("Paused", "Timer paused")
            } else {
                triggerEvent(Config.focusStartMessage, Config.focusStartSound)
                notifyPhaseChange("Resumed", "Timer resumed")
            }
        }
    }

    function stop() {
        running = false
        isPaused = false
        isBreak = false
        remainingSeconds = focusDuration
        completedSessions = 0
        notifyPhaseChange("Stopped", "Pomodoro timer stopped")
    }

    function skip() {
        if (running) {
            onPhaseComplete()
        }
    }

    function onPhaseComplete() {
        if (isBreak) {
            isBreak = false
            remainingSeconds = focusDuration
            intervalTimer.restart()
            triggerEvent(Config.focusStartMessage, Config.focusStartSound)
            notifyPhaseChange("Focus Time", "Time to concentrate!")
        } else {
            completedSessions++

            if (completedSessions % sessionsUntilLongBreak === 0) {
                isBreak = true
                remainingSeconds = longBreakDuration
                triggerEvent(Config.breakMessage, Config.breakSound)
                notifyPhaseChange("Long Break", "Great work! Take a longer break.")
            } else {
                isBreak = true
                remainingSeconds = shortBreakDuration
                triggerEvent(Config.breakMessage, Config.breakSound)
                notifyPhaseChange("Short Break", "Good job! Take a short break.")
            }
        }
    }

    function notifyPhaseChange(title: string, message: string) {
        if (!Config.notificationsEnabled) return
        notifyProcess.command = [
            "notify-send", "-u", "normal",
            "-t", String(Config.notificationDurationMs),
            "-a", "Pomodoro", title, message
        ]
        notifyProcess.startDetached()
    }
}
