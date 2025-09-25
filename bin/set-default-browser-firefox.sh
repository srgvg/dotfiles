#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

###############################################################################

DESKTOP_FILE="$HOME/.local/share/applications/firefox.desktop"
TARGET="$HOME/bin/firefox"
LINK="/usr/bin/firefox"

# 1) Verify /usr/bin/firefox is a symlink to $TARGET
if [ ! -L "$LINK" ]; then
  echo "ERROR: $LINK is not a symlink:" >&2
  file "$LINK" >&2
  exit 1
fi
REAL="$(readlink -f "$LINK")"
if [ "$REAL" != "$TARGET" ]; then
  echo "ERROR: $LINK points to $REAL, expected $TARGET" >&2
  exit 1
fi
if [ ! -x "$TARGET" ]; then
  echo "ERROR: $TARGET not found or not executable" >&2
  exit 1
fi

# 2) Ensure .desktop file exists
if [ ! -f "$DESKTOP_FILE" ]; then
  echo "ERROR: $DESKTOP_FILE missing" >&2
  exit 1
fi

# 3) Check Exec= line in .desktop
if grep -q '^Exec=/usr/bin/firefox' "$DESKTOP_FILE"; then
  echo "Exec= line already correct in $DESKTOP_FILE"
else
  echo "Patching Exec= in $DESKTOP_FILE"
  sed -i 's|^Exec=.*|Exec=/usr/bin/firefox %u|' "$DESKTOP_FILE"
  echo "Exec= line was patched in $DESKTOP_FILE"
fi

# 4) Check TryExec= line in .desktop
if grep -q '^TryExec=/usr/bin/firefox' "$DESKTOP_FILE"; then
  echo "TryExec= line already correct in $DESKTOP_FILE"
else
  if grep -q '^TryExec=' "$DESKTOP_FILE"; then
    sed -i 's|^TryExec=.*|TryExec=/usr/bin/firefox|' "$DESKTOP_FILE"
  echo "TryExec= line was patched in $DESKTOP_FILE"
  else
    echo 'TryExec=/usr/bin/firefox' >> "$DESKTOP_FILE"
  fi
fi

# 5) Update alternatives
sudo update-alternatives --install /usr/bin/x-www-browser x-www-browser "$LINK" 200
sudo update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser "$LINK" 200
sudo update-alternatives --set x-www-browser "$LINK"
sudo update-alternatives --set gnome-www-browser "$LINK"

# 6) Update MIME associations
xdg-settings set default-web-browser "$(basename "$DESKTOP_FILE")"
xdg-mime default "$(basename "$DESKTOP_FILE")" x-scheme-handler/http
xdg-mime default "$(basename "$DESKTOP_FILE")" x-scheme-handler/https
xdg-mime default "$(basename "$DESKTOP_FILE")" text/html

# 7) Refresh desktop DB
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

# 8) Report status
echo "== alternatives =="
update-alternatives --query x-www-browser | sed -n '1,12p'
update-alternatives --query gnome-www-browser | sed -n '1,12p'
echo "== xdg =="
xdg-settings get default-web-browser
xdg-mime query default x-scheme-handler/http
xdg-mime query default x-scheme-handler/https
xdg-mime query default text/html

