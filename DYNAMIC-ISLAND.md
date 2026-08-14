# Dynamic Island for Noctalia v4

A macOS-style dynamic island that replaces the workspace pills in the bar center. Built natively into the shell (no plugin), inspired by [Tide-island](https://github.com/enhaoswen/Tide-island).

## What it does

- Compact capsule with your workspace pills, plus a mini visualizer chip while music plays
- Swipe left/right on the capsule (drag or horizontal scroll) between three pages: info (clock, date, battery), workspaces, and now playing
- Volume/brightness changes morph the capsule into an inline OSD
- Notifications expand the island below the bar, iPhone style
- Rest the cursor on it (or click) while music plays and it expands into a full player card: album art, seek bar, controls, spectrum visualizer
- Everything follows your Noctalia color scheme; stock OSD and notification popups automatically step aside on screens where the island is active

## Install

You need a working Noctalia v4 setup (quickshell installed). Your existing config is safe: this is stock v4.7.7 plus the island, same settings version.

```bash
# 1. Clone this branch
git clone -b dynamic-island https://github.com/xevrion/noctalia.git ~/noctalia-island

# 2. Stop your running shell, then run this tree
pkill -x qs
qs -p ~/noctalia-island
```

Then open **Settings, Bar, Widgets** and swap the `Workspace` widget in the center section for `DynamicIsland`. Done.

To make it your daily shell (so autostart and `qs -c noctalia-shell ipc ...` keybinds use it):

```bash
mkdir -p ~/.config/quickshell
ln -s ~/noctalia-island ~/.config/quickshell/noctalia-shell
```

The user-level config wins over `/etc/xdg`, so your packaged noctalia stays installed and untouched. Delete the symlink to go back.

## Optional

- `cava` installed = visualizer chip and player card spectrum. Without it those stay quiet, everything else works.
- IPC control, bindable to keys:

```bash
qs -c noctalia-shell ipc call island toggle      # expand/collapse player card
qs -c noctalia-shell ipc call island swipeLeft   # info page
qs -c noctalia-shell ipc call island swipeRight  # music page
```

## Limitations

- Top horizontal bars only (vertical/bottom bars keep the normal widgets)
- v4 only; upstream v4 is EOL, so this lives here on the fork

Updates: `git -C ~/noctalia-island pull`
