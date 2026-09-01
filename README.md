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
- Multi-select with `Space`/`s`, Shift + arrows or Shift + `hjkl`, and `Escape`
  to clear selection; `Ctrl+C`/`Ctrl+X`/`Ctrl+V` operate on all selected items
- `C` compresses selected items to a ZIP archive and `U` uncompresses ZIP/tar archives
- `l` or `→` on a ZIP/tar archive extracts it directly; on folders they open the folder
- `r` renames the current item, `t` focuses and selects the location field, and `C` asks for an archive filename (default `archive.zip`)
- Right-click any item for the full action menu

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

## Keybind configuration

OmaFiles creates `~/.config/omafiles/config.json` on first launch. Edit the
`keybinds` values there to change the in-app shortcuts, then restart OmaFiles.
Supported names include `Space`, `Escape`, `Left`, `Right`, `Up`, `Down`, and
modifier combinations such as `Ctrl+Shift+L`.

The default configuration is:

```json
{
  "keybinds": {
    "parent": "h",
    "open": "l",
    "moveDown": "j",
    "moveUp": "k",
    "select": "Space",
    "copy": "Ctrl+C",
    "cut": "Ctrl+X",
    "paste": "Ctrl+V",
    "localSend": "Ctrl+Shift+L",
    "compress": "C",
    "uncompress": "U",
    "rename": "r",
    "quickPath": "t",
    "clearSelection": "Escape"
  }
}
```
