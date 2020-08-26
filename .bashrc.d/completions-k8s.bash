# bash completion for fluxctl                              -*- shell-script -*-

__fluxctl_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__fluxctl_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__fluxctl_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__fluxctl_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__fluxctl_handle_reply()
{
    __fluxctl_debug "${FUNCNAME[0]}"
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            COMPREPLY=( $(compgen -W "${allflags[*]}" -- "$cur") )
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __fluxctl_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi
            return 0;
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __fluxctl_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions=("${must_have_one_noun[@]}")
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    COMPREPLY=( $(compgen -W "${completions[*]}" -- "$cur") )

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        COMPREPLY=( $(compgen -W "${noun_aliases[*]}" -- "$cur") )
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
		if declare -F __fluxctl_custom_func >/dev/null; then
			# try command name qualified custom func
			__fluxctl_custom_func
		else
			# otherwise fall back to unqualified for compatibility
			declare -F __custom_func >/dev/null && __custom_func
		fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__fluxctl_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__fluxctl_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1
}

__fluxctl_handle_flag()
{
    __fluxctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __fluxctl_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __fluxctl_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __fluxctl_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __fluxctl_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __fluxctl_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__fluxctl_handle_noun()
{
    __fluxctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __fluxctl_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __fluxctl_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__fluxctl_handle_command()
{
    __fluxctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_fluxctl_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __fluxctl_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__fluxctl_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __fluxctl_handle_reply
        return
    fi
    __fluxctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __fluxctl_handle_flag
    elif __fluxctl_contains_word "${words[c]}" "${commands[@]}"; then
        __fluxctl_handle_command
    elif [[ $c -eq 0 ]]; then
        __fluxctl_handle_command
    elif __fluxctl_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __fluxctl_handle_command
        else
            __fluxctl_handle_noun
        fi
    else
        __fluxctl_handle_noun
    fi
    __fluxctl_handle_word
}

_fluxctl_automate()
{
    last_command="fluxctl_automate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--user=")
    two_word_flags+=("--user")
    local_nonpersistent_flags+=("--user=")
    flags+=("--verbose")
    flags+=("-v")
    local_nonpersistent_flags+=("--verbose")
    flags+=("--workload=")
    two_word_flags+=("--workload")
    two_word_flags+=("-w")
    local_nonpersistent_flags+=("--workload=")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_completion()
{
    last_command="fluxctl_completion"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    must_have_one_noun+=("bash")
    must_have_one_noun+=("zsh")
    noun_aliases=()
}

_fluxctl_deautomate()
{
    last_command="fluxctl_deautomate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--user=")
    two_word_flags+=("--user")
    local_nonpersistent_flags+=("--user=")
    flags+=("--verbose")
    flags+=("-v")
    local_nonpersistent_flags+=("--verbose")
    flags+=("--workload=")
    two_word_flags+=("--workload")
    two_word_flags+=("-w")
    local_nonpersistent_flags+=("--workload=")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_identity()
{
    last_command="fluxctl_identity"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--fingerprint")
    flags+=("-l")
    local_nonpersistent_flags+=("--fingerprint")
    flags+=("--regenerate")
    flags+=("-r")
    local_nonpersistent_flags+=("--regenerate")
    flags+=("--visual")
    flags+=("-v")
    local_nonpersistent_flags+=("--visual")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_install()
{
    last_command="fluxctl_install"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--add-security-context")
    local_nonpersistent_flags+=("--add-security-context")
    flags+=("--git-branch=")
    two_word_flags+=("--git-branch")
    local_nonpersistent_flags+=("--git-branch=")
    flags+=("--git-email=")
    two_word_flags+=("--git-email")
    local_nonpersistent_flags+=("--git-email=")
    flags+=("--git-label=")
    two_word_flags+=("--git-label")
    local_nonpersistent_flags+=("--git-label=")
    flags+=("--git-path=")
    two_word_flags+=("--git-path")
    local_nonpersistent_flags+=("--git-path=")
    flags+=("--git-readonly")
    local_nonpersistent_flags+=("--git-readonly")
    flags+=("--git-url=")
    two_word_flags+=("--git-url")
    local_nonpersistent_flags+=("--git-url=")
    flags+=("--git-user=")
    two_word_flags+=("--git-user")
    local_nonpersistent_flags+=("--git-user=")
    flags+=("--manifest-generation")
    local_nonpersistent_flags+=("--manifest-generation")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--output-dir=")
    two_word_flags+=("--output-dir")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-dir=")
    flags+=("--registry-disable-scanning")
    local_nonpersistent_flags+=("--registry-disable-scanning")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_list-images()
{
    last_command="fluxctl_list-images"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output-format=")
    two_word_flags+=("--output-format")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-format=")
    flags+=("--workload=")
    two_word_flags+=("--workload")
    two_word_flags+=("-w")
    local_nonpersistent_flags+=("--workload=")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_list-workloads()
{
    last_command="fluxctl_list-workloads"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-namespaces")
    flags+=("-a")
    local_nonpersistent_flags+=("--all-namespaces")
    flags+=("--container=")
    two_word_flags+=("--container")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--container=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output-format=")
    two_word_flags+=("--output-format")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-format=")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_lock()
{
    last_command="fluxctl_lock"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--user=")
    two_word_flags+=("--user")
    local_nonpersistent_flags+=("--user=")
    flags+=("--verbose")
    flags+=("-v")
    local_nonpersistent_flags+=("--verbose")
    flags+=("--workload=")
    two_word_flags+=("--workload")
    two_word_flags+=("-w")
    local_nonpersistent_flags+=("--workload=")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_policy()
{
    last_command="fluxctl_policy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--automate")
    local_nonpersistent_flags+=("--automate")
    flags+=("--deautomate")
    local_nonpersistent_flags+=("--deautomate")
    flags+=("--lock")
    local_nonpersistent_flags+=("--lock")
    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--tag=")
    two_word_flags+=("--tag")
    local_nonpersistent_flags+=("--tag=")
    flags+=("--tag-all=")
    two_word_flags+=("--tag-all")
    local_nonpersistent_flags+=("--tag-all=")
    flags+=("--unlock")
    local_nonpersistent_flags+=("--unlock")
    flags+=("--user=")
    two_word_flags+=("--user")
    local_nonpersistent_flags+=("--user=")
    flags+=("--verbose")
    flags+=("-v")
    local_nonpersistent_flags+=("--verbose")
    flags+=("--workload=")
    two_word_flags+=("--workload")
    two_word_flags+=("-w")
    local_nonpersistent_flags+=("--workload=")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_release()
{
    last_command="fluxctl_release"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--exclude=")
    two_word_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude=")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--interactive")
    local_nonpersistent_flags+=("--interactive")
    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--update-all-images")
    local_nonpersistent_flags+=("--update-all-images")
    flags+=("--update-image=")
    two_word_flags+=("--update-image")
    two_word_flags+=("-i")
    local_nonpersistent_flags+=("--update-image=")
    flags+=("--user=")
    two_word_flags+=("--user")
    local_nonpersistent_flags+=("--user=")
    flags+=("--verbose")
    flags+=("-v")
    local_nonpersistent_flags+=("--verbose")
    flags+=("--watch")
    flags+=("-w")
    local_nonpersistent_flags+=("--watch")
    flags+=("--workload=")
    two_word_flags+=("--workload")
    local_nonpersistent_flags+=("--workload=")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_save()
{
    last_command="fluxctl_save"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--out=")
    two_word_flags+=("--out")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--out=")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_sync()
{
    last_command="fluxctl_sync"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_unlock()
{
    last_command="fluxctl_unlock"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--user=")
    two_word_flags+=("--user")
    local_nonpersistent_flags+=("--user=")
    flags+=("--verbose")
    flags+=("-v")
    local_nonpersistent_flags+=("--verbose")
    flags+=("--workload=")
    two_word_flags+=("--workload")
    two_word_flags+=("-w")
    local_nonpersistent_flags+=("--workload=")
    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_version()
{
    last_command="fluxctl_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_fluxctl_root_command()
{
    last_command="fluxctl"

    command_aliases=()

    commands=()
    commands+=("automate")
    commands+=("completion")
    commands+=("deautomate")
    commands+=("identity")
    commands+=("install")
    commands+=("list-images")
    commands+=("list-workloads")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("list-controllers")
        aliashash["list-controllers"]="list-workloads"
    fi
    commands+=("lock")
    commands+=("policy")
    commands+=("release")
    commands+=("save")
    commands+=("sync")
    commands+=("unlock")
    commands+=("version")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    flags+=("--k8s-fwd-labels=")
    two_word_flags+=("--k8s-fwd-labels")
    flags+=("--k8s-fwd-ns=")
    two_word_flags+=("--k8s-fwd-ns")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    flags+=("--token=")
    two_word_flags+=("--token")
    two_word_flags+=("-t")
    flags+=("--url=")
    two_word_flags+=("--url")
    two_word_flags+=("-u")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_fluxctl()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __fluxctl_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("fluxctl")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local last_command
    local nouns=()

    __fluxctl_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_fluxctl fluxctl
else
    complete -o default -o nospace -F __start_fluxctl fluxctl
fi

# ex: ts=4 sw=4 et filetype=sh
