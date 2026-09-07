# Flyline: readline replacement written in Rust (alternative to ble.sh).
# https://github.com/HalFrgrd/flyline
# Toggle with SHELL_LINE_EDITOR=flyline (default: blesh, see blesh.bash).
if [[ $- == *i* && ${SHELL_LINE_EDITOR:-blesh} == flyline ]]; then
    # mise's github backend keeps the upstream versioned filename (no bare
    # "libflyline.so" symlink like install.sh's own layout would), so glob it.
    _flyline_so=("$HOME"/.local/share/mise/installs/flyline/latest/libflyline.so.*)
    if enable flyline 2>/dev/null || { [[ -f ${_flyline_so[0]} ]] && enable -f "${_flyline_so[0]}" flyline; }; then
        flyline mouse --mode disabled

        flyline_fzf_cd() {
            local cmd
            cmd=$(__fzf_cd__) && READLINE_LINE="$cmd" READLINE_POINT=${#cmd}
        }

        # fzf widgets -- the readline `bind`s in 5-fzf-keys.bash don't apply under flyline
        flyline key bind Ctrl+r 'always=runBashCommand(__fzf_history__)'
        flyline key bind Ctrl+t 'always=runBashCommand(fzf-file-widget)'
        flyline key bind Alt+c 'always=runBashCommand(flyline_fzf_cd)+submitOrNewline'
    fi
    unset _flyline_so
fi
