#!/usr/bin/env bash
set -e

PLUGIN_ID="dorneles.ambience"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
BINDINGS_CONFIG="$HOME/.config/hypr/bindings.lua"
MENU_CONFIG="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Ambience plugin for Omarchy..."

# 1. Ensure plugin is in place
if [ "$SCRIPT_DIR" != "$PLUGIN_DIR" ]; then
  mkdir -p "$HOME/.config/omarchy/plugins"
  if [ -e "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_DIR"
  fi
  cp -r "$SCRIPT_DIR" "$PLUGIN_DIR"
fi

# 2. Configure shell.json (mode: active-only in bar.layout.right and in plugins array)
if [ -f "$SHELL_CONFIG" ]; then
  python3 - <<EOF
import json
import os

path = os.path.expanduser("$SHELL_CONFIG")
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}

if "bar" not in data:
    data["bar"] = {}
if "layout" not in data["bar"]:
    data["bar"]["layout"] = {}
if "right" not in data["bar"]["layout"]:
    data["bar"]["layout"]["right"] = []

# Update or insert in bar.layout.right
right = data["bar"]["layout"]["right"]
found_bar = False
for item in right:
    if isinstance(item, dict) and item.get("id") == "$PLUGIN_ID":
        item["mode"] = "active-only"
        found_bar = True
        break
if not found_bar:
    # Insert after omarchy.tray or at start
    insert_idx = 0
    for idx, item in enumerate(right):
        if isinstance(item, dict) and item.get("id") == "omarchy.tray":
            insert_idx = idx + 1
            break
    right.insert(insert_idx, {"id": "$PLUGIN_ID", "mode": "active-only"})

# Ensure in plugins list
if "plugins" not in data or not isinstance(data["plugins"], list):
    data["plugins"] = []

found_plugin = any(isinstance(p, dict) and p.get("id") == "$PLUGIN_ID" for p in data["plugins"])
if not found_plugin:
    data["plugins"].append({"id": "$PLUGIN_ID"})

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
print("  ✓ Updated shell.json with active-only mode")
EOF
fi

# 3. Add Hyprland keybindings
if [ -f "$BINDINGS_CONFIG" ]; then
  if ! grep -q "$PLUGIN_ID" "$BINDINGS_CONFIG"; then
    cat <<'EOF' >> "$BINDINGS_CONFIG"

-- Ambience Triggers
o.bind("SUPER + ALT + A", "Ambience (Play/Pause)", "omarchy-shell dorneles.ambience toggle")
o.bind("SUPER + CTRL + ALT + A", "Ambience", "omarchy-shell dorneles.ambience openStudio")
EOF
    echo "  ✓ Added keybindings to bindings.lua"
  fi
fi

# 4. Add Omarchy menu entries
if [ -f "$MENU_CONFIG" ]; then
  python3 - <<EOF
import os

path = os.path.expanduser("$MENU_CONFIG")
try:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    if "trigger.ambience" not in content:
        target = '"trigger.share.receive"'
        entries = (
            '  "trigger.ambience": {"icon":"󱒗","label":"Ambience (Play/Pause)","action":"omarchy-shell dorneles.ambience toggle","aliases":["ambience","ambient sounds","white noise","rain","focus sound","nature"]},\n'
            '  "trigger.ambience.studio": {"icon":"󰎆","label":"Ambience","action":"omarchy-shell dorneles.ambience openStudio","aliases":["ambience","sounds","focus","ambient sound"]},\n'
        )
        if target in content:
            content = content.replace(target, entries + '  ' + target)
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            print("  ✓ Added menu entries to omarchy-menu.jsonc")
except Exception as e:
    pass
EOF
fi

# 5. Reload shell and Hyprland
if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi
if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
if command -v omarchy-restart-shell >/dev/null 2>&1; then
  omarchy-restart-shell >/dev/null 2>&1 || true
fi

echo "==> Ambience installation complete!"
echo "    • Super+Alt+A        : Play/Pause ambient sound"
echo "    • Super+Ctrl+Alt+A   : Open Ambience modal"
