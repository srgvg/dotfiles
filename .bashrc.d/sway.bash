# [2022-11-07 17:28:08.183] [warning] For a functional tray you must have libappindicator-* installed and export XDG_CURRENT_DESKTOP=Unity
export XDG_CURRENT_DESKTOP=Unity
export XDG_CURRENT_DESKTOP=Sway
export XDG_SESSION_TYPE=wayland

# https://github.com/swaywm/sway/wiki#my-favorite-application-isnt-displayed-right-how-can-i-fix-this
# Qt currently defaults to using the X11 backend instead of its native Wayland backend. To use the Wayland backend, set QT_QPA_PLATFORM=wayland. Then Qt will also draw client-side decorations for all windows, to disable this, set QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
#export QT_QPA_PLATFORM=wayland
#export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"

export TERMINAL="alacritty"
export MOZ_ENABLE_WAYLAND=1 
export WLR_DRM_NO_MODIFIERS=1
