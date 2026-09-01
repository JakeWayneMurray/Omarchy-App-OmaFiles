# Omarchy App: OmaFiles

A fast, keyboard-first file manager for Omarchy, built as a standalone
Quickshell app. It uses the active Omarchy `Color` and `Style` tokens, so it
automatically follows the current theme.

## Features

- Home, filesystem, and breadcrumb navigation
- Search the current folder
- Hidden-file toggle
- List, compact, and grid views
- Text preview for common source, config, markdown, and log files
- New folder, rename, move to Trash, and open with the default application
- Keyboard navigation: arrows, Enter, Backspace, `/` search, `Ctrl+L` location,
  `Ctrl+Shift+N` new folder, `Delete` trash, and `Escape` close dialogs

## Run from a checkout

```bash
sudo pacman -S --needed quickshell python
./run.sh
```

## Install as a normal app

On Omarchy/Arch Linux:

```bash
sudo pacman -S --needed base-devel git quickshell python
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
