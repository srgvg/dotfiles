# prevent duplicate directories in you PATH variable
# pathmunge /path/to/dir is equivalent to PATH=/path/to/dir:$PATH
# pathmunge /path/to/dir after is equivalent to PATH=$PATH:/path/to/dir
if ! type pathmunge > /dev/null 2>&1
then
  function pathmunge () {

    if ! [[ $PATH =~ (^|:)$1($|:) ]] ; then
      if [ "$2" = "after" ] ; then
        export PATH=$PATH:$1
      else
        export PATH=$1:$PATH
      fi
    fi
  }
fi

function _printline() {
	local _char=$1
	printf "%`tput cols`s" | tr " " "$_char"
}

function cloud_completions() {
    if [ -d $HOME/.bashrc.d/cloud_completions ]
    then
        for bashrc in $HOME/.bashrc.d/cloud_completions/*.bash; do
            source $bashrc
        done
    fi
}

# window manager specifics
wm="$(wmctrl -m | grep Name: | cut -d: -f2)"
if [[ "${wm}" =~ "wlroots" ]]
then
  export MY_WM="sway"
  # [2022-11-07 17:28:08.183] [warning] For a functional tray you must have libappindicator-* installed and export XDG_CURRENT_DESKTOP=Unity
  export XDG_CURRENT_DESKTOP=Sway
  export XDG_SESSION_TYPE=wayland
  
  # https://github.com/swaywm/sway/wiki#my-favorite-application-isnt-displayed-right-how-can-i-fix-this
  # Qt currently defaults to using the X11 backend instead of its native Wayland backend. To use the Wayland backend, set QT_QPA_PLATFORM=wayland. Then Qt will also draw client-side decorations for all windows, to disable this, set QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
  #export QT_QPA_PLATFORM=wayland
  #export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
  export TERMINAL="alacritty"
  export MOZ_ENABLE_WAYLAND=1 
  export WLR_DRM_NO_MODIFIERS=1
elif [[ "${wm}" =~ "i3" ]]
then 
  export MY_WM="i3"
  unset XDG_CURRENT_DESKTOP
  unset XDG_CURRENT_DESKTOP
  unset XDG_SESSION_TYPE
  unset TERMINAL
  unset MOZ_ENABLE_WAYLAND
  unset WLR_DRM_NO_MODIFIERS
else 
  export MY_WM="UNKNOWN"
  unset XDG_CURRENT_DESKTOP
  unset XDG_CURRENT_DESKTOP
  unset XDG_SESSION_TYPE
  unset TERMINAL
  unset MOZ_ENABLE_WAYLAND
  unset WLR_DRM_NO_MODIFIERS
fi
