_yazi() {
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
                cmd="yazi"
                ;;
            *)
                ;;
        esac
    done

    case "${cmd}" in
        yazi)
            opts="-V -h --cwd-file --chooser-file --clear-cache --client-id --local-events --remote-events --debug --version --help [ENTRIES]..."
            if [[ ${cur} == -* || ${COMP_CWORD} -eq 1 ]] ; then
                COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
                return 0
            fi
            case "${prev}" in
                --cwd-file)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --chooser-file)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --client-id)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --local-events)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --remote-events)
                    COMPREPLY=($(compgen -f "${cur}"))
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
    complete -F _yazi -o nosort -o bashdefault -o default yazi
else
    complete -F _yazi -o bashdefault -o default yazi
fi
