# Omarchy App: OmaFiles

A fast, keyboard-first file manager for Omarchy, built as a standalone
Quickshell app. It uses the active Omarchy `Color` and `Style` tokens, so it
automatically follows the current theme.

## Features

- Home, filesystem, and breadcrumb navigation
- Search the current folder
- Hidden-file toggle
- List, compact, and grid views
- File size, modified time, and creation/change time metadata
- Sort by name, size, modified time, or creation/change time in either direction
- Text preview for common source, config, markdown, and log files
- MIME-aware preview for extensionless and arbitrary text files
- PDF preview with first-page rendering and selectable text extraction
- New folder, rename, move to Trash, and open with the default application
- Keyboard navigation: arrows, Enter, Backspace, `/` search, `Ctrl+L` location,
  `Ctrl+Shift+N` new folder, `Delete` trash, and `Escape` close dialogs

## Run from a checkout

```bash
sudo pacman -S --needed quickshell python file poppler
./run.sh
```

## Install as a normal app

On Omarchy/Arch Linux:

```bash
sudo pacman -S --needed base-devel git quickshell python file poppler
git clone git@github.com:JakeWayneMurray/Omarchy-App-OmaFiles.git
cd Omarchy-App-OmaFiles
makepkg -si
```

After installation, launch **OmaFiles** from the Omarchy application launcher
or run:

```bash
omafiles
```

The package installs the desktop entry, the `omafiles` command, and the
`Alt+E` Hyprland binding can be added with:

```lua
o.bind("ALT + E", "OmaFiles", "omafiles")
```

Save that in `~/.config/hypr/bindings.lua`, then run `hyprctl reload`.

`./run.sh` remains available for development checkouts.
