# Sway Config — Maintenance Guide

The rendered overview is in `config.html` (open in any browser). Keybindings are in `keybindings.html`.

## File naming convention

Files are numbered so they load in the right order:

```
config                    — entry point (do not rename)
10-variables-config       — variables (must load first)
20-inputs-outputs-config  — hardware
30-theme-config           — colors, fonts
40-statusbars-config      — waybar
50-settings-config        — sway behavior
60-bindings-config        — keybindings
70-modes-config           — modes
80-*-rules-config         — window rules
90-execs-config           — startup programs
99-last-config            — last-run commands
```

The entry point includes system defaults first, then user config:
```
include /etc/sway/config.d/*     # system defaults (background, systemd env)
include ~/.config/sway/*-config  # all numbered user files
```

## Where to edit what

| What you want to change | File |
|------------------------|------|
| Modifier key, terminal, workspace names | `10-variables-config` |
| Keyboard layout, mouse, Wacom tablet | `20-inputs-outputs-config` |
| Monitor resolution / scale / position | `20-inputs-outputs-config` |
| Colors, borders, fonts | `30-theme-config` |
| Waybar config | `40-statusbars-config` |
| Focus behavior, wrapping, opacity | `50-settings-config` |
| Keybindings | `60-bindings-config` |
| Resize / move / system / nag modes | `70-modes-config` |
| Which app opens on which workspace | `80-rules-config` |
| Floating rules, title bar | `80-rules-config` |
| Inhibit idle (fullscreen, etc.) | `82-rules-inhibit` |
| Game / Steam / RDP rules | `85-rules-config` |
| Startup programs | `90-execs-config` |

## Adding a new output

1. Find the output name: `swaymsg -t get_outputs | jq '.[].name'`
2. Set a variable in `20-inputs-outputs-config`: `set $myoutput DP-X`
3. Add an `output $myoutput { … }` block.
4. Assign workspaces: `workspace N output $myoutput`

## Updating config.html

`config.html` is hand-maintained. When the config changes significantly:

- **New file**: add a row to the File Inventory table.
- **New variable**: add a row to the Variables table.
- **New output**: add a row to the Outputs table.
- **New startup exec**: add a row to the Startup table.
- **New issue found**: add a row to the Issues table with appropriate severity badge.

Severity badge classes: `critical`, `moderate`, `minor`, `design`, `ok`.

## Reload and validate

```bash
# Validate config without reloading
sway --validate

# Reload live (keybinding)
# Super+Shift+r

# Check for undefined variables or parse errors in output
journalctl --user -u sway -n 50
```

## Known issues

Tracked in `config.html`'s [Issues](config.html#issues) section, not duplicated here —
keeping the same table in two places is exactly how it went stale before (all 5 issues
listed here as of 2026-05-20 were fixed long before this note was corrected on 2026-08-04).
