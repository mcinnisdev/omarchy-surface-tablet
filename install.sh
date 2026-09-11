#!/bin/bash
# Tablet mode for Omarchy on the Surface Pro 4, on the stock Arch kernel.
#
#   1. IPTS touch driver as a DKMS module (rebuilds on kernel updates)
#   2. Floating on-screen keyboard with swipe typing (wvkbd fork)
#   3. Swipe word list
#   4. Auto-rotation and keyboard scripts, Hyprland config
#   5. hyprgrass touch gestures
#
# Run as your normal user from a checkout of this repo; it asks for sudo itself.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WVKBD_REPO=${WVKBD_REPO:-https://github.com/mcinnisdev/wvkbd.git}
WVKBD_BRANCH=${WVKBD_BRANCH:-tablet}
SRC_DIR=${SRC_DIR:-$HOME/.local/src}
DATA_DIR=$HOME/.local/share/tablet-keyboard
HYPR_DIR=$HOME/.config/hypr
IPTS_VER=6.19.8

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
  echo "Run this as your normal user (not sudo); it asks for sudo itself." >&2
  exit 1
fi

step "Installing packages"
sudo pacman -S --needed \
  linux-headers dkms pahole iio-sensor-proxy words python jq \
  wayland wayland-protocols pango cairo libxkbcommon scdoc pkgconf \
  cmake meson ninja glm cpio

step "Installing the IPTS touch driver (DKMS ipts/$IPTS_VER)"
if dkms status "ipts/$IPTS_VER" 2>/dev/null | grep -q installed &&
  diff -rq "$REPO_DIR/driver/ipts" "/usr/src/ipts-$IPTS_VER" >/dev/null 2>&1; then
  echo "Already installed: $(dkms status "ipts/$IPTS_VER")"
else
  # Rebuild when the driver source changed, e.g. to pick up fixes.
  sudo dkms remove "ipts/$IPTS_VER" --all 2>/dev/null || true
  sudo rm -rf "/usr/src/ipts-$IPTS_VER"
  sudo install -d "/usr/src/ipts-$IPTS_VER"
  sudo install -m644 "$REPO_DIR"/driver/ipts/* "/usr/src/ipts-$IPTS_VER/"
  sudo dkms install "ipts/$IPTS_VER"
  sudo modprobe -r ipts 2>/dev/null || true
fi
sudo modprobe ipts

step "Installing iptsd for multi-touch and the pen (linux-surface repo)"
if ! grep -q '^\[linux-surface\]' /etc/pacman.conf; then
  curl -fsSL https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc | sudo pacman-key --add -
  sudo pacman-key --lsign-key 56C464BAAC421453
  sudo cp /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%s)"
  printf '\n[linux-surface]\nServer = https://pkg.surfacelinux.com/arch/\n' | sudo tee -a /etc/pacman.conf >/dev/null
fi
sudo pacman -Syu --needed iptsd
# iptsd 3.1.0's built-in contact thresholds miss fingertips on the SP4 (iptsd#210).
sudo install -Dm644 "$REPO_DIR/iptsd/90-sp4-contacts.conf" /etc/iptsd.d/90-sp4-contacts.conf
sudo systemctl restart 'iptsd@*.service' 2>/dev/null || true
sudo udevadm trigger --action=add --subsystem-match=hidraw

step "Building the keyboard ($WVKBD_REPO, $WVKBD_BRANCH)"
mkdir -p "$SRC_DIR"
if [[ ! -d $SRC_DIR/wvkbd ]]; then
  git clone --branch "$WVKBD_BRANCH" "$WVKBD_REPO" "$SRC_DIR/wvkbd"
fi
make -C "$SRC_DIR/wvkbd" LAYOUT=tablet
make -C "$SRC_DIR/wvkbd" LAYOUT=tablet PREFIX="$HOME/.local" install

step "Building the swipe word list"
mkdir -p "$DATA_DIR"
if [[ ! -f $DATA_DIR/count_1w.txt ]]; then
  curl -fL -o "$DATA_DIR/count_1w.txt" https://norvig.com/ngrams/count_1w.txt
fi
python3 "$SRC_DIR/wvkbd/tools/build-wordlist.py" \
  /usr/share/dict/american-english "$DATA_DIR/count_1w.txt" >"$DATA_DIR/swipe-words.tsv"
echo "$(wc -l <"$DATA_DIR/swipe-words.tsv") words"

step "Installing scripts and Hyprland config"
install -Dm755 -t "$HOME/.local/bin" \
  "$REPO_DIR/bin/tablet-keyboard" "$REPO_DIR/bin/tablet-autorotate" "$REPO_DIR/bin/tablet-menu-sync" \
  "$REPO_DIR/bin/tablet-gestures"
if [[ -f $HYPR_DIR/tablet.lua ]] && ! cmp -s "$REPO_DIR/hypr/tablet.lua" "$HYPR_DIR/tablet.lua"; then
  cp "$HYPR_DIR/tablet.lua" "$HYPR_DIR/tablet.lua.bak.$(date +%s)"
fi
install -Dm644 "$REPO_DIR/hypr/tablet.lua" "$HYPR_DIR/tablet.lua"
if ! grep -q 'require("hypr.tablet")' "$HYPR_DIR/hyprland.lua"; then
  if grep -q '^require("hypr.autostart")' "$HYPR_DIR/hyprland.lua"; then
    sed -i '/^require("hypr.autostart")/a require("hypr.tablet")' "$HYPR_DIR/hyprland.lua"
  else
    echo 'require("hypr.tablet")' >>"$HYPR_DIR/hyprland.lua"
  fi
fi

step "Building hyprgrass touch gestures (first run fetches Hyprland headers)"
hyprpm update
hyprpm list | grep -q hyprgrass || hyprpm add https://github.com/horriblename/hyprgrass
hyprpm enable hyprgrass
hyprpm reload -n

hyprctl reload >/dev/null
hyprctl configerrors

step "Keeping Omarchy menus clear of the keyboard"
"$HOME/.local/bin/tablet-menu-sync"
hook_dir="$HOME/.config/omarchy/hooks/post-update.d"
mkdir -p "$hook_dir"
printf '#!/bin/bash\n# Rebuild the keyboard-friendly Omarchy menu copy after updates.\nexec "$HOME/.local/bin/tablet-menu-sync"\n' >"$hook_dir/tablet-menu-sync-hook"
chmod +x "$hook_dir/tablet-menu-sync-hook"

step "Setting up gesture settings (Omarchy menu > Setup > Gestures)"
"$HOME/.local/bin/tablet-gestures" apply
python3 - "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc" <<'PY'
import os
import sys

path = sys.argv[1]
entry = '  "setup.gestures": {"icon":"󰆽","label":"Gestures","description":"Touch gestures for tablet mode","action":"tablet-gestures","aliases":["gestures"]},\n'
try:
    text = open(path).read()
except FileNotFoundError:
    text = "{\n}\n"
if '"setup.gestures"' not in text:
    end = text.rstrip().rfind("}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text[:end] + entry + text[end:])
PY

step "Done"
echo "Log out and back in to start the keyboard and auto-rotation."
