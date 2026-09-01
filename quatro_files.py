#!/usr/bin/env python3
import json, os, shutil, subprocess, sys, tempfile

HOME = os.path.expanduser("~")
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".svg", ".avif", ".ico"}

def clean(path):
    return os.path.realpath(os.path.expanduser(path or HOME))

def item(path):
    try:
        st = os.stat(path)
        is_dir = os.path.isdir(path)
        return {"name": os.path.basename(path) or path, "path": path,
                "directory": is_dir, "size": 0 if is_dir else st.st_size,
                "modified": st.st_mtime, "created": getattr(st, "st_birthtime", st.st_ctime), "hidden": os.path.basename(path).startswith("."),
                "image": (not is_dir and os.path.splitext(path)[1].lower() in IMAGE_EXTENSIONS)}
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

def main(req):
    op = req.get("op")
    if op == "list": return listing(req.get("path"), req.get("hidden", False), req.get("query", ""), req.get("sort", "name"), req.get("ascending", True))
    if op == "preview":
        path = clean(req.get("path"));
        if os.path.isdir(path): return {"ok": True, "text": "Folder\n\n" + path, "image": False}
        if os.path.splitext(path)[1].lower() in IMAGE_EXTENSIONS: return {"ok": True, "text": "", "image": True}
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f: data = f.read(12000)
            return {"ok": True, "text": data, "truncated": len(data) >= 12000}
        except Exception as e: return {"ok": False, "error": str(e)}
    if op == "mkdir":
        os.mkdir(os.path.join(clean(req.get("path")), req.get("name", "New Folder"))); return {"ok": True}
    if op == "rename":
        old = clean(req.get("path")); new = os.path.join(os.path.dirname(old), req.get("name", "")); os.rename(old, new); return {"ok": True}
    if op == "trash":
        path = clean(req.get("path")); trash = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share")), "Trash/files"); os.makedirs(trash, exist_ok=True)
        target = os.path.join(trash, os.path.basename(path));
        if os.path.exists(target): target += "." + next(tempfile._get_candidate_names())
        shutil.move(path, target); return {"ok": True}
    if op == "paste":
        source = clean(req.get("source")); destination = clean(req.get("destination")); mode = req.get("mode", "copy")
        if not os.path.exists(source): return {"ok": False, "error": "The source item no longer exists."}
        if os.path.isdir(destination): target = os.path.join(destination, os.path.basename(source))
        else: target = destination
        if clean(target) == source or clean(target).startswith(source + os.sep):
            return {"ok": False, "error": "An item cannot be pasted inside itself."}
        if os.path.exists(target):
            stem, ext = os.path.splitext(target); target = stem + " copy" + ext
        if mode == "cut": shutil.move(source, target)
        elif os.path.isdir(source): shutil.copytree(source, target)
        else: shutil.copy2(source, target)
        return {"ok": True, "moved": mode == "cut"}
    if op == "open":
        subprocess.Popen(["xdg-open", clean(req.get("path"))], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); return {"ok": True}
    return {"ok": False, "error": "Unknown operation"}

for line in sys.stdin:
    try:
        try: response(main(json.loads(line)))
        except Exception as e: response({"ok": False, "error": str(e)})
    except BrokenPipeError: break
