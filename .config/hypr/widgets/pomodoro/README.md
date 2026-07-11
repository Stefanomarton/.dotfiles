# Pomodoro Widget for Hyprland

A QuickShell-based Pomodoro timer that displays a colored border overlay around your screen with a MacBook-style notch timer display.

- **Red border**: Focus time (25 minutes)
- **Green border**: Break time
- **Amber border**: Paused

## Features

- Screen border overlay with rounded corners
- MacBook-style notch timer display
- Color-coded states (focus/break/pause)
- Desktop notifications on phase changes
- Fully configurable via `Config.qml`
- Mouse input passthrough (doesn't block clicks)

## Installation

### Run directly (no install)

```bash
nix run .
# or from anywhere:
nix run /path/to/pomodoro-widget
```

### Development shell

```bash
direnv allow
# or
nix develop

quickshell -p .
```

### NixOS / Home-Manager

1. Add the flake input to your `flake.nix`:

```nix
{
  inputs = {
    # ... your other inputs
    pomodoro-widget = {
      url = "path:/path/to/pomodoro-widget";
      # or if pushed to git:
      # url = "github:yourusername/pomodoro-widget";
    };
  };
}
```

2. Add to your packages (in `home.nix` or `configuration.nix`):

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.pomodoro-widget.packages.${pkgs.system}.default
  ];
}
```

3. Optional: Auto-start on login (home-manager):

```nix
systemd.user.services.pomodoro-widget = {
  Unit.Description = "Pomodoro Widget";
  Install.WantedBy = [ "graphical-session.target" ];
  Service = {
    ExecStart = "${inputs.pomodoro-widget.packages.${pkgs.system}.default}/bin/pomodoro-widget";
    Restart = "on-failure";
  };
};
```

## Hyprland Keybindings

Add these to your `hyprland.conf`:

```conf
bind = , F9, global, quickshell:pomodoro-start
bind = , F10, global, quickshell:pomodoro-pause
bind = , F11, global, quickshell:pomodoro-stop
bind = , F12, global, quickshell:pomodoro-skip
```

Reload Hyprland after adding:
```bash
hyprctl reload
```

To verify shortcuts are registered:
```bash
hyprctl globalshortcuts
```

## Controls

| Shortcut | Action |
|----------|--------|
| F9 | Start a new Pomodoro or resume if paused |
| F10 | Toggle pause/resume |
| F11 | Stop and reset the timer |
| F12 | Skip to the next phase |

## Configuration

Edit `Config.qml` to customize:

```qml
QtObject {
    // Timer durations (in minutes)
    readonly property int focusMinutes: 25
    readonly property int shortBreakMinutes: 5
    readonly property int longBreakMinutes: 15
    readonly property int sessionsUntilLongBreak: 4

    // Colors
    readonly property color focusColor: "#F44336"       // Red
    readonly property color breakColor: "#4CAF50"       // Green
    readonly property color pauseColor: "#FFC107"       // Amber/Yellow

    // Border styling
    readonly property int borderWidth: 6
    readonly property int cornerRadius: 20

    // Timer display
    readonly property int timerFontSize: 22
    readonly property string timerFontFamily: "monospace"
    readonly property int timerPaddingH: 28
    readonly property int timerPaddingV: 14

    // Notifications
    readonly property bool notificationsEnabled: true
    readonly property int notificationDurationMs: 5000
}
```

## Project Structure

```
pomodoro-widget/
├── flake.nix          # Nix flake for dev shell and packaging
├── .envrc             # direnv integration
├── shell.qml          # Main widget with screen border overlay
├── PomodoroState.qml  # Timer logic (singleton)
├── Config.qml         # User configuration (singleton)
├── qmldir             # QML module definitions
└── README.md
```

## License

MIT
