# starship shell prompt stuff
# https://starship.rs/
# Use pre-generated cache (regenerated every 4h via update-tools)
# To manually regenerate: update-tools shell-init
_starship_cache="$HOME/.cache/shell-init/starship.bash"
if [[ -f "$_starship_cache" ]]; then
    # shellcheck source=/dev/null
    source "$_starship_cache"
else
    # Fallback if cache missing (first run)
    eval "$(starship init bash)"
fi
unset _starship_cache
# to update startship:
# bash <(curl -fsSL https://starship.rs/install.sh) --verbose --bin-dir $HOME/bin2 --yes

# https://superuser.com/questions/992210/how-to-set-environment-variables-for-a-gnome-wayland-session
# NOTE: Interactive login shell guard added to prevent writing to filesystem
# during non-interactive shells. This file write is only needed for login
# shells to export PATH to systemd user session (Wayland/Sway).
# mise entries are dropped (install dirs pin tool versions into the session;
# 51-mise-shims.conf adds the shims), and so are empty and duplicate entries.
if [[ $- == *i* ]] && shopt -q login_shell; then
    _envd_path='' _p=''
    while IFS= read -r -d: _p; do
        [[ -z $_p || $_p == *mise/installs* || $_p == *mise/shims* ]] && continue
        [[ :$_envd_path: == *":$_p:"* ]] && continue
        _envd_path+=${_envd_path:+:}$_p
    done <<<"$PATH:"
    echo "PATH=${_envd_path}" >"$HOME/.config/environment.d/50-path.conf"
    unset _envd_path _p
fi
export PATH

# at some point CDPATH completion stopped working, this seems to fix/workarounf it
#__load_completion cd

# https://github.com/akinomyoga/ble.sh?tab=readme-ov-file#set-up-bashrc
[[ ! ${BLE_VERSION-} ]] || ble-attach

# sem collects anonymous usage data (command names only, never code or repo names).
# Set SEM_NO_TELEMETRY=1 to disable.
export SEM_NO_TELEMETRY=1
