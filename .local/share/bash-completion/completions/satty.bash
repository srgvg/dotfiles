_satty() {
    local i cur prev opts cmd
    COMPREPLY=()
    if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
        cur="$2"
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
    fi
    prev="$3"
    cmd=""
    opts=""

    for i in "${COMP_WORDS[@]:0:COMP_CWORD}"
    do
        case "${cmd},${i}" in
            ",$1")
                cmd="satty"
                ;;
            *)
                ;;
        esac
    done

    case "${cmd}" in
        satty)
            opts="-c -f -o -d -h -V --config --filename --fullscreen --resize --floating-hack --output-filename --early-exit --early-exit-save-as --corner-roundness --init-tool --initial-tool --copy-command --annotation-size-factor --save-after-copy --actions-on-enter --actions-on-escape --actions-on-right-click --default-hide-toolbars --focus-toggles-toolbars --default-fill-shapes --font-family --font-style --primary-highlighter --disable-notifications --profile-startup --no-window-decoration --brush-smooth-history-size --zoom-factor --pan-step-size --text-move-length --input-scale --right-click-copy --action-on-enter --help --version"
            if [[ ${cur} == -* || ${COMP_CWORD} -eq 1 ]] ; then
                COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
                return 0
            fi
            case "${prev}" in
                --config)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                -c)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --filename)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                -f)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --fullscreen)
                    COMPREPLY=($(compgen -W "all current-screen" -- "${cur}"))
                    return 0
                    ;;
                --resize)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --output-filename)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                -o)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --corner-roundness)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --initial-tool)
                    COMPREPLY=($(compgen -W "pointer crop line arrow rectangle ellipse text marker blur highlight brush" -- "${cur}"))
                    return 0
                    ;;
                --init-tool)
                    COMPREPLY=($(compgen -W "pointer crop line arrow rectangle ellipse text marker blur highlight brush" -- "${cur}"))
                    return 0
                    ;;
                --copy-command)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --annotation-size-factor)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --actions-on-enter)
                    COMPREPLY=($(compgen -W "save-to-clipboard save-to-file save-to-file-as copy-filepath-to-clipboard exit" -- "${cur}"))
                    return 0
                    ;;
                --actions-on-escape)
                    COMPREPLY=($(compgen -W "save-to-clipboard save-to-file save-to-file-as copy-filepath-to-clipboard exit" -- "${cur}"))
                    return 0
                    ;;
                --actions-on-right-click)
                    COMPREPLY=($(compgen -W "save-to-clipboard save-to-file save-to-file-as copy-filepath-to-clipboard exit" -- "${cur}"))
                    return 0
                    ;;
                --font-family)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --font-style)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --primary-highlighter)
                    COMPREPLY=($(compgen -W "block freehand" -- "${cur}"))
                    return 0
                    ;;
                --brush-smooth-history-size)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --zoom-factor)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --pan-step-size)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --text-move-length)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --input-scale)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --action-on-enter)
                    COMPREPLY=($(compgen -W "save-to-clipboard save-to-file save-to-file-as copy-filepath-to-clipboard exit" -- "${cur}"))
                    return 0
                    ;;
                *)
                    COMPREPLY=()
                    ;;
            esac
            COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
            return 0
            ;;
    esac
}

if [[ "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -ge 4 || "${BASH_VERSINFO[0]}" -gt 4 ]]; then
    complete -F _satty -o nosort -o bashdefault -o default satty
else
    complete -F _satty -o bashdefault -o default satty
fi
