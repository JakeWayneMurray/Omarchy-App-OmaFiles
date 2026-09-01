#!/usr/bin/env python3
import hashlib, json, os, shutil, subprocess, sys, tempfile, tarfile, zipfile

HOME = os.path.expanduser("~")
CONFIG_FILE = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "omafiles", "config.json")
DEFAULT_KEYBINDS = {
    "parent": "h", "open": "l", "moveDown": "j", "moveUp": "k",
    "select": "Space", "copy": "Ctrl+C", "cut": "Ctrl+X", "paste": "Ctrl+V",
    "localSend": "Ctrl+Shift+L", "compress": "C", "uncompress": "U", "rename": "r", "quickPath": "t", "clearSelection": "Escape"
}
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".svg", ".avif", ".ico"}
PDF_EXTENSIONS = {".pdf"}
ARCHIVE_SUFFIXES = (".zip", ".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tbz2", ".tar.xz", ".txz")

def clean(path):
    return os.path.realpath(os.path.expanduser(path or HOME))

def read_config():
    try:
        with open(CONFIG_FILE, encoding="utf-8") as config_file: value = json.load(config_file)
        keybinds = value.get("keybinds", {}) if isinstance(value, dict) else {}
    except (OSError, json.JSONDecodeError):
        keybinds = {}
    merged = dict(DEFAULT_KEYBINDS)
    if isinstance(keybinds, dict):
        for key in merged:
            if isinstance(keybinds.get(key), str) and keybinds[key].strip(): merged[key] = keybinds[key].strip()
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True, mode=0o700)
    if not os.path.exists(CONFIG_FILE) or not isinstance(keybinds, dict) or any(key not in keybinds for key in merged):
        with open(CONFIG_FILE, "w", encoding="utf-8") as config_file: json.dump({"keybinds": merged}, config_file, indent=2); config_file.write("\n")
    return {"keybinds": merged, "path": CONFIG_FILE}

def item(path):
    try:
        st = os.stat(path)
        is_dir = os.path.isdir(path)
        return {"name": os.path.basename(path) or path, "path": path,
                "directory": is_dir, "size": 0 if is_dir else st.st_size,
                "modified": st.st_mtime, "created": getattr(st, "st_birthtime", st.st_ctime), "hidden": os.path.basename(path).startswith("."),
                "image": (not is_dir and os.path.splitext(path)[1].lower() in IMAGE_EXTENSIONS),
                "pdf": (not is_dir and os.path.splitext(path)[1].lower() in PDF_EXTENSIONS),
                "archive": (not is_dir and path.lower().endswith(ARCHIVE_SUFFIXES))}
    except OSError:
        return None

def listing(path, show_hidden=False, query="", sort_key="name", ascending=True):
    path = clean(path)
    query = query.lower().strip()
    try: names = sorted(os.listdir(path), key=lambda n: (not os.path.isdir(os.path.join(path, n)), n.lower()))
    except OSError as e: return {"ok": False, "error": str(e), "items": []}
    out = []
    for name in names:
        if not show_hidden and name.startswith("."): continue
        if query and query not in name.lower(): continue
        value = item(os.path.join(path, name))
        if value: out.append(value)
    def sort_value(value):
        if sort_key == "size": return value["size"]
        if sort_key == "modified": return value["modified"]
        if sort_key == "created": return value["created"]
        return value["name"].lower()
    out.sort(key=lambda value: (not value["directory"], sort_value(value)), reverse=not ascending)
    return {"ok": True, "path": path, "items": out}

def response(value):
    sys.stdout.write(json.dumps(value) + "\n"); sys.stdout.flush()

def is_text_file(path):
    try:
        mime = subprocess.run(["file", "--brief", "--mime-type", path], capture_output=True, text=True, timeout=3).stdout.strip().lower()
        return mime.startswith("text/") or mime in {"application/json", "application/xml", "application/javascript", "application/x-sh", "inode/x-empty"}
    except Exception:
        return False

def pdf_preview(path):
    preview_dir = os.path.join(tempfile.gettempdir(), "omafiles-previews")
    os.makedirs(preview_dir, exist_ok=True)
    stem = os.path.join(preview_dir, hashlib.sha256(path.encode()).hexdigest()[:24])
    image_path = stem + ".png"
    if not os.path.exists(image_path):
        try:
            subprocess.run(["pdftoppm", "-png", "-f", "1", "-singlefile", "-r", "120", path, stem], check=True, capture_output=True, timeout=12)
        except Exception:
            image_path = ""
    try:
        text = subprocess.run(["pdftotext", "-f", "1", "-l", "3", "-layout", path, "-"], capture_output=True, text=True, errors="replace", timeout=12).stdout[:12000]
    except Exception as error:
        text = "PDF preview tools are unavailable: " + str(error)
    return {"ok": True, "text": text or "This PDF has no selectable text.", "image": bool(image_path), "imagePath": image_path}

def complete_path(value):
    raw = os.path.expanduser(str(value or ""))
    if raw.endswith(os.sep): parent, prefix = raw.rstrip(os.sep) or os.sep, ""
    else: parent, prefix = os.path.dirname(raw) or ".", os.path.basename(raw)
    parent = clean(parent)
    try: names = sorted(name for name in os.listdir(parent) if name.startswith(prefix))
    except OSError: names = []
    matches = []
    for name in names:
        path = os.path.join(parent, name)
        matches.append(path + os.sep if os.path.isdir(path) else path)
    common = os.path.commonprefix(matches) if matches else raw
    return {"ok": True, "completions": matches, "common": common}

def unique_path(path):
    if not os.path.exists(path): return path
    stem, ext = os.path.splitext(path)
    number = 2
    while os.path.exists(stem + " " + str(number) + ext): number += 1
    return stem + " " + str(number) + ext

def main(req):
    op = req.get("op")
    if op == "config": return {"ok": True, "config": read_config()}
    if op == "complete": return complete_path(req.get("text", ""))
    if op == "list": return listing(req.get("path"), req.get("hidden", False), req.get("query", ""), req.get("sort", "name"), req.get("ascending", True))
    if op == "preview":
        path = clean(req.get("path"));
        if os.path.isdir(path): return {"ok": True, "text": "Folder\n\n" + path, "image": False}
        if os.path.splitext(path)[1].lower() in IMAGE_EXTENSIONS: return {"ok": True, "text": "", "image": True}
        if os.path.splitext(path)[1].lower() in PDF_EXTENSIONS: return pdf_preview(path)
        if not is_text_file(path): return {"ok": True, "text": "No preview available for this file type.", "image": False}
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f: data = f.read(12000)
            return {"ok": True, "text": data, "truncated": len(data) >= 12000}
        except Exception as e: return {"ok": False, "error": str(e)}
    if op == "mkdir":
        os.mkdir(os.path.join(clean(req.get("path")), req.get("name", "New Folder"))); return {"ok": True}
    if op == "rename":
        old = clean(req.get("path")); new = os.path.join(os.path.dirname(old), req.get("name", "")); os.rename(old, new); return {"ok": True}
    if op == "trash":
        paths = [clean(value) for value in req.get("paths", [req.get("path")]) if value]
        trash = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share")), "Trash/files"); os.makedirs(trash, exist_ok=True)
        for path in paths:
            if not os.path.exists(path): continue
            target = os.path.join(trash, os.path.basename(path))
            if os.path.exists(target): target += "." + next(tempfile._get_candidate_names())
            shutil.move(path, target)
        return {"ok": True, "deleted": len(paths)}
    if op == "paste":
        sources = [clean(value) for value in req.get("sources", [req.get("source")]) if value]
        destination = clean(req.get("destination")); mode = req.get("mode", "copy")
        for source in sources:
            if not os.path.exists(source): return {"ok": False, "error": "A source item no longer exists."}
            target = os.path.join(destination, os.path.basename(source))
            if clean(target) == source or clean(target).startswith(source + os.sep): return {"ok": False, "error": "An item cannot be pasted inside itself."}
            target = unique_path(target)
            if mode == "cut": shutil.move(source, target)
            elif os.path.isdir(source): shutil.copytree(source, target)
            else: shutil.copy2(source, target)
        return {"ok": True, "moved": mode == "cut"}
    if op == "compress":
        paths = [clean(value) for value in req.get("paths", [])]
        if not paths: return {"ok": False, "error": "Select at least one item to compress."}
        archive_name = os.path.basename(str(req.get("name", "archive.zip")).strip()) or "archive.zip"
        if not archive_name.lower().endswith(".zip"): archive_name += ".zip"
        destination = unique_path(os.path.join(clean(req.get("destination")), archive_name))
        with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in paths:
                if not os.path.exists(path): continue
                if os.path.isdir(path):
                    for base, _, files in os.walk(path):
                        for name in files: archive.write(os.path.join(base, name), os.path.relpath(os.path.join(base, name), os.path.dirname(path)))
                else: archive.write(path, os.path.basename(path))
        return {"ok": True, "archive": destination}
    if op == "uncompress":
        paths = [clean(value) for value in req.get("paths", [])]
        extracted = 0
        for path in paths:
            if not os.path.isfile(path): continue
            folder = unique_path(os.path.splitext(path)[0])
            os.makedirs(folder, exist_ok=True)
            if zipfile.is_zipfile(path):
                with zipfile.ZipFile(path) as archive: archive.extractall(folder)
            elif tarfile.is_tarfile(path):
                with tarfile.open(path) as archive: archive.extractall(folder, filter="data")
            else: continue
            extracted += 1
        return {"ok": extracted > 0, "error": "Select a ZIP or tar archive to uncompress." if extracted == 0 else ""}
    if op == "localsend":
        paths = [clean(value) for value in req.get("paths", []) if value and os.path.exists(clean(value))]
        if not paths: return {"ok": False, "error": "Select a file or folder to send."}
        try:
            subprocess.Popen(["localsend", *paths], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return {"ok": True, "sent": len(paths)}
        except FileNotFoundError:
            return {"ok": False, "error": "LocalSend is not installed."}
    if op == "open":
        subprocess.Popen(["xdg-open", clean(req.get("path"))], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); return {"ok": True}
    return {"ok": False, "error": "Unknown operation"}

for line in sys.stdin:
    try:
        try: response(main(json.loads(line)))
        except Exception as e: response({"ok": False, "error": str(e)})
    except BrokenPipeError: break
