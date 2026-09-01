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

## Install

The included desktop entry is packaged as `omarchy-app-omafiles`. After
installation, launch **OmaFiles** from the Omarchy application launcher or
run `omafiles`. `./run.sh` remains available for development checkouts.
