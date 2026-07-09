#!/usr/bin/env python3
import os
import sys
import json
import subprocess
import urllib.parse
import hashlib
import time
import fcntl

CACHE_DIR = os.path.expanduser('~/.cache/quickshell/clipboard')
HISTORY_FILE = os.path.join(CACHE_DIR, 'history.json')
IMAGES_DIR = os.path.join(CACHE_DIR, 'images')
LOCK_FILE = os.path.join(CACHE_DIR, 'history.lock')

def acquire_lock():
    """Acquire an exclusive advisory lock to prevent concurrent read/write race conditions."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    lock_f = open(LOCK_FILE, 'w')
    try:
        fcntl.flock(lock_f, fcntl.LOCK_EX)
    except IOError:
        pass
    return lock_f

def release_lock(lock_f):
    """Release the advisory lock and close the lock file handler."""
    if lock_f:
        try:
            fcntl.flock(lock_f, fcntl.LOCK_UN)
        except IOError:
            pass
        lock_f.close()

def load_history():
    """Load clipboard history from the persistent JSON file safely."""
    if not os.path.exists(HISTORY_FILE):
        return []
    try:
        with open(HISTORY_FILE, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading history: {e}", file=sys.stderr)
        return []

def save_history(history):
    """Save clipboard history atomically using a temporary file to prevent corruption."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    temp_file = HISTORY_FILE + '.tmp'
    try:
        with open(temp_file, 'w') as f:
            json.dump(history, f, indent=2)
        os.replace(temp_file, HISTORY_FILE)
    except Exception as e:
        print(f"Error saving history: {e}", file=sys.stderr)
        if os.path.exists(temp_file):
            os.remove(temp_file)

def add_to_history(history, item_type, value, preview):
    """Add a new item to history, remove duplicates using stripped comparisons, and limit to 20 items."""
    duplicate_index = -1
    
    # Clean up standard formatting variations for comparison to avoid redundant entries
    val_to_compare = value.strip() if isinstance(value, str) else value
    
    for i, item in enumerate(history):
        item_val = item['value']
        item_val_compare = item_val.strip() if isinstance(item_val, str) else item_val
        
        # Deduplicate based on type and content consistency
        if item['type'] == item_type and item_val_compare == val_to_compare:
            duplicate_index = i
            break
            
    if duplicate_index != -1:
        # Move existing item to top (most recent)
        item = history.pop(duplicate_index)
        item['timestamp'] = time.strftime("%H:%M:%S")
        history.insert(0, item)
    else:
        # Create a new unique history item
        item = {
            "id": int(time.time() * 1000),  # Unique millisecond timestamp
            "type": item_type,
            "value": value,                 # Always a String!
            "preview": preview,
            "timestamp": time.strftime("%H:%M:%S")
        }
        history.insert(0, item)
        
    # Strictly limit to 20 items
    history = history[:20]
    save_history(history)

def record():
    """Query wl-paste, inspect mime types, format the preview and record history."""
    try:
        res = subprocess.run(['wl-paste', '--list-types'], capture_output=True, text=True, check=True)
        types = res.stdout.strip().split('\n')
    except Exception:
        # Clipboard is empty or wl-clipboard is not accessible
        return

    os.makedirs(IMAGES_DIR, exist_ok=True)
    history = load_history()

    # --- Type 1: Files/Directories (text/uri-list) ---
    if 'text/uri-list' in types:
        try:
            res = subprocess.run(['wl-paste', '--type', 'text/uri-list'], capture_output=True, text=True, check=True)
            raw_uris = res.stdout.strip()
            uris = [line.strip() for line in raw_uris.split('\n') if line.strip()]
            if uris:
                filenames = []
                for uri in uris:
                    parsed = urllib.parse.urlparse(uri)
                    path = urllib.parse.unquote(parsed.path)
                    filenames.append(os.path.basename(path) or path)
                preview = ", ".join(filenames)
                # Store raw_uris as a newline-separated String instead of a List
                add_to_history(history, "files", raw_uris, preview)
                return
        except Exception:
            pass

    # --- Type 2: Images ---
    image_type = next((t for t in types if t.startswith('image/')), None)
    if image_type:
        try:
            res = subprocess.run(['wl-paste', '--type', image_type], capture_output=True, check=True)
            img_data = res.stdout
            if img_data:
                hasher = hashlib.md5()
                hasher.update(img_data)
                img_hash = hasher.hexdigest()
                img_filename = f"clip_{img_hash}.png"
                img_path = os.path.join(IMAGES_DIR, img_filename)
                
                if not os.path.exists(img_path):
                    with open(img_path, 'wb') as f:
                        f.write(img_data)
                
                add_to_history(history, "image", img_path, f"Image ({len(img_data) // 1024} KB)")
                return
        except Exception:
            pass

    # --- Type 3: Plain Text ---
    text_type = next((t for t in types if 'text/plain' in t or 'UTF8_STRING' in t or 'string' in t), None)
    try:
        res = subprocess.run(['wl-paste', '--type', text_type or 'text/plain'], capture_output=True, text=True, check=True)
        text_val = res.stdout
        if text_val and text_val.strip():
            preview = text_val.strip()[:150] + ("..." if len(text_val.strip()) > 150 else "")
            add_to_history(history, "text", text_val, preview)
    except Exception:
        # Final general paste fallback
        try:
            res = subprocess.run(['wl-paste'], capture_output=True, text=True, check=True)
            text_val = res.stdout
            if text_val and text_val.strip():
                preview = text_val.strip()[:150] + ("..." if len(text_val.strip()) > 150 else "")
                add_to_history(history, "text", text_val, preview)
        except Exception:
            pass

def copy_to_clipboard(item_id):
    """Write chosen item back to the wayland clipboard using wl-copy."""
    history = load_history()
    item = next((x for x in history if str(x['id']) == str(item_id)), None)
    if not item:
        return
        
    item_type = item['type']
    value = item['value']
    
    if item_type == 'text':
        p = subprocess.Popen(['wl-copy', '--type', 'text/plain'], stdin=subprocess.PIPE)
        p.communicate(input=value.encode('utf-8'))
    elif item_type == 'image':
        if os.path.exists(value):
            with open(value, 'rb') as f:
                img_data = f.read()
            p = subprocess.Popen(['wl-copy', '--type', 'image/png'], stdin=subprocess.PIPE)
            p.communicate(input=img_data)
    elif item_type == 'files':
        # value is already a string of newline-separated URIs
        p = subprocess.Popen(['wl-copy', '--type', 'text/uri-list'], stdin=subprocess.PIPE)
        p.communicate(input=value.encode('utf-8'))

def delete_item(item_id):
    """Delete a single clipboard item from the list."""
    history = load_history()
    updated_history = [x for x in history if str(x['id']) != str(item_id)]
    save_history(updated_history)

def clear_all():
    """Clear all clipboard history and cached images."""
    save_history([])
    if os.path.exists(IMAGES_DIR):
        for f in os.listdir(IMAGES_DIR):
            try:
                os.remove(os.path.join(IMAGES_DIR, f))
            except Exception:
                pass

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: clip_daemon.py [record|list|copy <id>|delete <id>|clear]")
        sys.exit(1)
        
    cmd = sys.argv[1]
    
    # Wrap every command transaction in a lock session to handle background process sync perfectly
    lock_f = acquire_lock()
    try:
        if cmd == "record":
            record()
        elif cmd == "list":
            print(json.dumps(load_history()))
        elif cmd == "copy" and len(sys.argv) == 3:
            copy_to_clipboard(sys.argv[2])
        elif cmd == "delete" and len(sys.argv) == 3:
            delete_item(sys.argv[2])
        elif cmd == "clear":
            clear_all()
    finally:
        release_lock(lock_f)