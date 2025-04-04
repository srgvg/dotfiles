_satty() {
    local i cur prev opts cmd
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd=""
    opts=""

    for i in ${COMP_WORDS[@]}
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
            opts="-c -f -o -d -h -V --config --filename --fullscreen --output-filename --early-exit --corner-roundness --init-tool --initial-tool --copy-command --annotation-size-factor --action-on-enter --save-after-copy --default-hide-toolbars --font-family --font-style --primary-highlighter --disable-notifications --help --version"
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
                --action-on-enter)
                    COMPREPLY=($(compgen -W "save-to-clipboard save-to-file" -- "${cur}"))
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
