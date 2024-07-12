# bash completion for eksctl                               -*- shell-script -*-

__eksctl_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE:-} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__eksctl_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__eksctl_index_of_word()
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

__eksctl_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__eksctl_handle_go_custom_completion()
{
    __eksctl_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly eksctl allows handling aliases
    args=("${words[@]:1}")
    # Disable ActiveHelp which is not supported for bash completion v1
    requestComp="EKSCTL_ACTIVE_HELP=0 ${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __eksctl_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __eksctl_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __eksctl_debug "${FUNCNAME[0]}: calling ${requestComp}"
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [ "${directive}" = "${out}" ]; then
        # There is not directive specified
        directive=0
    fi
    __eksctl_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __eksctl_debug "${FUNCNAME[0]}: the completions are: ${out}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __eksctl_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __eksctl_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __eksctl_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local fullFilter filter filteringCmd
        # Do not use quotes around the $out variable or else newline
        # characters will be kept.
        for filter in ${out}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __eksctl_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subdir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out}")
        if [ -n "$subdir" ]; then
            __eksctl_debug "Listing directories in $subdir"
            __eksctl_handle_subdirs_in_dir_flag "$subdir"
        else
            __eksctl_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out}" -- "$cur")
    fi
}

__eksctl_handle_reply()
{
    __eksctl_debug "${FUNCNAME[0]}"
    local comp
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
            while IFS='' read -r comp; do
                COMPREPLY+=("$comp")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
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
                __eksctl_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION:-}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi

            if [[ -z "${flag_parsing_disabled}" ]]; then
                # If flag parsing is enabled, we have completed the flags and can return.
                # If flag parsing is disabled, we may not know all (or any) of the flags, so we fallthrough
                # to possibly call handle_go_custom_completion.
                return 0;
            fi
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __eksctl_index_of_word "${prev}" "${flags_with_completion[@]}"
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
        completions+=("${must_have_one_noun[@]}")
    elif [[ -n "${has_completion_function}" ]]; then
        # if a go completion function is provided, defer to that function
        __eksctl_handle_go_custom_completion
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r comp; do
        COMPREPLY+=("$comp")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        if declare -F __eksctl_custom_func >/dev/null; then
            # try command name qualified custom func
            __eksctl_custom_func
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
__eksctl_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__eksctl_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__eksctl_handle_flag()
{
    __eksctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue=""
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __eksctl_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __eksctl_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __eksctl_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __eksctl_contains_word "${words[c]}" "${two_word_flags[@]}"; then
        __eksctl_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__eksctl_handle_noun()
{
    __eksctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __eksctl_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __eksctl_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__eksctl_handle_command()
{
    __eksctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_eksctl_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __eksctl_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__eksctl_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __eksctl_handle_reply
        return
    fi
    __eksctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __eksctl_handle_flag
    elif __eksctl_contains_word "${words[c]}" "${commands[@]}"; then
        __eksctl_handle_command
    elif [[ $c -eq 0 ]]; then
        __eksctl_handle_command
    elif __eksctl_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __eksctl_handle_command
        else
            __eksctl_handle_noun
        fi
    else
        __eksctl_handle_noun
    fi
    __eksctl_handle_word
}

_eksctl_anywhere()
{
    last_command="eksctl_anywhere"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_associate_identityprovider()
{
    last_command="eksctl_associate_identityprovider"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    local_nonpersistent_flags+=("-w")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_associate()
{
    last_command="eksctl_associate"

    command_aliases=()

    commands=()
    commands+=("identityprovider")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_completion_bash()
{
    last_command="eksctl_completion_bash"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_completion_fish()
{
    last_command="eksctl_completion_fish"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_completion_powershell()
{
    last_command="eksctl_completion_powershell"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_completion_zsh()
{
    last_command="eksctl_completion_zsh"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_completion()
{
    last_command="eksctl_completion"

    command_aliases=()

    commands=()
    commands+=("bash")
    commands+=("fish")
    commands+=("powershell")
    commands+=("zsh")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_create_accessentry()
{
    last_command="eksctl_create_accessentry"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--kubernetes-groups=")
    two_word_flags+=("--kubernetes-groups")
    local_nonpersistent_flags+=("--kubernetes-groups")
    local_nonpersistent_flags+=("--kubernetes-groups=")
    flags+=("--kubernetes-username=")
    two_word_flags+=("--kubernetes-username")
    local_nonpersistent_flags+=("--kubernetes-username")
    local_nonpersistent_flags+=("--kubernetes-username=")
    flags+=("--principal-arn=")
    two_word_flags+=("--principal-arn")
    local_nonpersistent_flags+=("--principal-arn")
    local_nonpersistent_flags+=("--principal-arn=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--type=")
    two_word_flags+=("--type")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_create_addon()
{
    last_command="eksctl_create_addon"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--attach-policy-arn=")
    two_word_flags+=("--attach-policy-arn")
    local_nonpersistent_flags+=("--attach-policy-arn")
    local_nonpersistent_flags+=("--attach-policy-arn=")
    flags+=("--auto-apply-pod-identity-associations")
    local_nonpersistent_flags+=("--auto-apply-pod-identity-associations")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service-account-role-arn=")
    two_word_flags+=("--service-account-role-arn")
    local_nonpersistent_flags+=("--service-account-role-arn")
    local_nonpersistent_flags+=("--service-account-role-arn=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--version=")
    two_word_flags+=("--version")
    local_nonpersistent_flags+=("--version")
    local_nonpersistent_flags+=("--version=")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_create_cluster()
{
    last_command="eksctl_create_cluster"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--alb-ingress-access")
    local_nonpersistent_flags+=("--alb-ingress-access")
    flags+=("--appmesh-access")
    local_nonpersistent_flags+=("--appmesh-access")
    flags+=("--appmesh-preview-access")
    local_nonpersistent_flags+=("--appmesh-preview-access")
    flags+=("--asg-access")
    local_nonpersistent_flags+=("--asg-access")
    flags+=("--authenticator-role-arn=")
    two_word_flags+=("--authenticator-role-arn")
    local_nonpersistent_flags+=("--authenticator-role-arn")
    local_nonpersistent_flags+=("--authenticator-role-arn=")
    flags+=("--auto-kubeconfig")
    local_nonpersistent_flags+=("--auto-kubeconfig")
    flags+=("--cfn-disable-rollback")
    local_nonpersistent_flags+=("--cfn-disable-rollback")
    flags+=("--cfn-role-arn=")
    two_word_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn=")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--disable-pod-imds")
    local_nonpersistent_flags+=("--disable-pod-imds")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--enable-ssm")
    local_nonpersistent_flags+=("--enable-ssm")
    flags+=("--external-dns-access")
    local_nonpersistent_flags+=("--external-dns-access")
    flags+=("--fargate")
    local_nonpersistent_flags+=("--fargate")
    flags+=("--full-ecr-access")
    local_nonpersistent_flags+=("--full-ecr-access")
    flags+=("--install-neuron-plugin")
    local_nonpersistent_flags+=("--install-neuron-plugin")
    flags+=("--install-nvidia-plugin")
    local_nonpersistent_flags+=("--install-nvidia-plugin")
    flags+=("--instance-name=")
    two_word_flags+=("--instance-name")
    local_nonpersistent_flags+=("--instance-name")
    local_nonpersistent_flags+=("--instance-name=")
    flags+=("--instance-prefix=")
    two_word_flags+=("--instance-prefix")
    local_nonpersistent_flags+=("--instance-prefix")
    local_nonpersistent_flags+=("--instance-prefix=")
    flags+=("--instance-selector-cpu-architecture=")
    two_word_flags+=("--instance-selector-cpu-architecture")
    local_nonpersistent_flags+=("--instance-selector-cpu-architecture")
    local_nonpersistent_flags+=("--instance-selector-cpu-architecture=")
    flags+=("--instance-selector-gpus=")
    two_word_flags+=("--instance-selector-gpus")
    local_nonpersistent_flags+=("--instance-selector-gpus")
    local_nonpersistent_flags+=("--instance-selector-gpus=")
    flags+=("--instance-selector-memory=")
    two_word_flags+=("--instance-selector-memory")
    local_nonpersistent_flags+=("--instance-selector-memory")
    local_nonpersistent_flags+=("--instance-selector-memory=")
    flags+=("--instance-selector-vcpus=")
    two_word_flags+=("--instance-selector-vcpus")
    local_nonpersistent_flags+=("--instance-selector-vcpus")
    local_nonpersistent_flags+=("--instance-selector-vcpus=")
    flags+=("--instance-types=")
    two_word_flags+=("--instance-types")
    local_nonpersistent_flags+=("--instance-types")
    local_nonpersistent_flags+=("--instance-types=")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig=")
    flags+=("--managed")
    local_nonpersistent_flags+=("--managed")
    flags+=("--max-pods-per-node=")
    two_word_flags+=("--max-pods-per-node")
    local_nonpersistent_flags+=("--max-pods-per-node")
    local_nonpersistent_flags+=("--max-pods-per-node=")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--node-ami=")
    two_word_flags+=("--node-ami")
    local_nonpersistent_flags+=("--node-ami")
    local_nonpersistent_flags+=("--node-ami=")
    flags+=("--node-ami-family=")
    two_word_flags+=("--node-ami-family")
    local_nonpersistent_flags+=("--node-ami-family")
    local_nonpersistent_flags+=("--node-ami-family=")
    flags+=("--node-labels=")
    two_word_flags+=("--node-labels")
    local_nonpersistent_flags+=("--node-labels")
    local_nonpersistent_flags+=("--node-labels=")
    flags+=("--node-private-networking")
    flags+=("-P")
    local_nonpersistent_flags+=("--node-private-networking")
    local_nonpersistent_flags+=("-P")
    flags+=("--node-security-groups=")
    two_word_flags+=("--node-security-groups")
    local_nonpersistent_flags+=("--node-security-groups")
    local_nonpersistent_flags+=("--node-security-groups=")
    flags+=("--node-type=")
    two_word_flags+=("--node-type")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--node-type")
    local_nonpersistent_flags+=("--node-type=")
    local_nonpersistent_flags+=("-t")
    flags+=("--node-volume-size=")
    two_word_flags+=("--node-volume-size")
    local_nonpersistent_flags+=("--node-volume-size")
    local_nonpersistent_flags+=("--node-volume-size=")
    flags+=("--node-volume-type=")
    two_word_flags+=("--node-volume-type")
    local_nonpersistent_flags+=("--node-volume-type")
    local_nonpersistent_flags+=("--node-volume-type=")
    flags+=("--node-zones=")
    two_word_flags+=("--node-zones")
    local_nonpersistent_flags+=("--node-zones")
    local_nonpersistent_flags+=("--node-zones=")
    flags+=("--nodegroup-name=")
    two_word_flags+=("--nodegroup-name")
    local_nonpersistent_flags+=("--nodegroup-name")
    local_nonpersistent_flags+=("--nodegroup-name=")
    flags+=("--nodegroup-parallelism=")
    two_word_flags+=("--nodegroup-parallelism")
    local_nonpersistent_flags+=("--nodegroup-parallelism")
    local_nonpersistent_flags+=("--nodegroup-parallelism=")
    flags+=("--nodes=")
    two_word_flags+=("--nodes")
    two_word_flags+=("-N")
    local_nonpersistent_flags+=("--nodes")
    local_nonpersistent_flags+=("--nodes=")
    local_nonpersistent_flags+=("-N")
    flags+=("--nodes-max=")
    two_word_flags+=("--nodes-max")
    two_word_flags+=("-M")
    local_nonpersistent_flags+=("--nodes-max")
    local_nonpersistent_flags+=("--nodes-max=")
    local_nonpersistent_flags+=("-M")
    flags+=("--nodes-min=")
    two_word_flags+=("--nodes-min")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--nodes-min")
    local_nonpersistent_flags+=("--nodes-min=")
    local_nonpersistent_flags+=("-m")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--set-kubeconfig-context")
    local_nonpersistent_flags+=("--set-kubeconfig-context")
    flags+=("--spot")
    local_nonpersistent_flags+=("--spot")
    flags+=("--ssh-access")
    local_nonpersistent_flags+=("--ssh-access")
    flags+=("--ssh-public-key=")
    two_word_flags+=("--ssh-public-key")
    local_nonpersistent_flags+=("--ssh-public-key")
    local_nonpersistent_flags+=("--ssh-public-key=")
    flags+=("--tags=")
    two_word_flags+=("--tags")
    local_nonpersistent_flags+=("--tags")
    local_nonpersistent_flags+=("--tags=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--version=")
    two_word_flags+=("--version")
    local_nonpersistent_flags+=("--version")
    local_nonpersistent_flags+=("--version=")
    flags+=("--vpc-cidr=")
    two_word_flags+=("--vpc-cidr")
    local_nonpersistent_flags+=("--vpc-cidr")
    local_nonpersistent_flags+=("--vpc-cidr=")
    flags+=("--vpc-from-kops-cluster=")
    two_word_flags+=("--vpc-from-kops-cluster")
    local_nonpersistent_flags+=("--vpc-from-kops-cluster")
    local_nonpersistent_flags+=("--vpc-from-kops-cluster=")
    flags+=("--vpc-nat-mode=")
    two_word_flags+=("--vpc-nat-mode")
    local_nonpersistent_flags+=("--vpc-nat-mode")
    local_nonpersistent_flags+=("--vpc-nat-mode=")
    flags+=("--vpc-private-subnets=")
    two_word_flags+=("--vpc-private-subnets")
    local_nonpersistent_flags+=("--vpc-private-subnets")
    local_nonpersistent_flags+=("--vpc-private-subnets=")
    flags+=("--vpc-public-subnets=")
    two_word_flags+=("--vpc-public-subnets")
    local_nonpersistent_flags+=("--vpc-public-subnets")
    local_nonpersistent_flags+=("--vpc-public-subnets=")
    flags+=("--with-oidc")
    local_nonpersistent_flags+=("--with-oidc")
    flags+=("--without-nodegroup")
    local_nonpersistent_flags+=("--without-nodegroup")
    flags+=("--write-kubeconfig")
    local_nonpersistent_flags+=("--write-kubeconfig")
    flags+=("--zones=")
    two_word_flags+=("--zones")
    local_nonpersistent_flags+=("--zones")
    local_nonpersistent_flags+=("--zones=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_create_fargateprofile()
{
    last_command="eksctl_create_fargateprofile"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--labels=")
    two_word_flags+=("--labels")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--labels")
    local_nonpersistent_flags+=("--labels=")
    local_nonpersistent_flags+=("-l")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--tags=")
    two_word_flags+=("--tags")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--tags")
    local_nonpersistent_flags+=("--tags=")
    local_nonpersistent_flags+=("-t")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_create_iamidentitymapping()
{
    last_command="eksctl_create_iamidentitymapping"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--arn=")
    two_word_flags+=("--arn")
    local_nonpersistent_flags+=("--arn")
    local_nonpersistent_flags+=("--arn=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--group=")
    two_word_flags+=("--group")
    local_nonpersistent_flags+=("--group")
    local_nonpersistent_flags+=("--group=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--no-duplicate-arns")
    local_nonpersistent_flags+=("--no-duplicate-arns")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service-name=")
    two_word_flags+=("--service-name")
    local_nonpersistent_flags+=("--service-name")
    local_nonpersistent_flags+=("--service-name=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--username=")
    two_word_flags+=("--username")
    local_nonpersistent_flags+=("--username")
    local_nonpersistent_flags+=("--username=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_create_iamserviceaccount()
{
    last_command="eksctl_create_iamserviceaccount"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--attach-policy-arn=")
    two_word_flags+=("--attach-policy-arn")
    local_nonpersistent_flags+=("--attach-policy-arn")
    local_nonpersistent_flags+=("--attach-policy-arn=")
    flags+=("--attach-role-arn=")
    two_word_flags+=("--attach-role-arn")
    local_nonpersistent_flags+=("--attach-role-arn")
    local_nonpersistent_flags+=("--attach-role-arn=")
    flags+=("--cfn-disable-rollback")
    local_nonpersistent_flags+=("--cfn-disable-rollback")
    flags+=("--cfn-role-arn=")
    two_word_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--exclude=")
    two_word_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude=")
    flags+=("--include=")
    two_word_flags+=("--include")
    local_nonpersistent_flags+=("--include")
    local_nonpersistent_flags+=("--include=")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--override-existing-serviceaccounts")
    local_nonpersistent_flags+=("--override-existing-serviceaccounts")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--role-name=")
    two_word_flags+=("--role-name")
    local_nonpersistent_flags+=("--role-name")
    local_nonpersistent_flags+=("--role-name=")
    flags+=("--role-only")
    local_nonpersistent_flags+=("--role-only")
    flags+=("--tags=")
    two_word_flags+=("--tags")
    local_nonpersistent_flags+=("--tags")
    local_nonpersistent_flags+=("--tags=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_create_nodegroup()
{
    last_command="eksctl_create_nodegroup"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--alb-ingress-access")
    local_nonpersistent_flags+=("--alb-ingress-access")
    flags+=("--appmesh-access")
    local_nonpersistent_flags+=("--appmesh-access")
    flags+=("--appmesh-preview-access")
    local_nonpersistent_flags+=("--appmesh-preview-access")
    flags+=("--asg-access")
    local_nonpersistent_flags+=("--asg-access")
    flags+=("--cfn-disable-rollback")
    local_nonpersistent_flags+=("--cfn-disable-rollback")
    flags+=("--cfn-role-arn=")
    two_word_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--disable-pod-imds")
    local_nonpersistent_flags+=("--disable-pod-imds")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--enable-ssm")
    local_nonpersistent_flags+=("--enable-ssm")
    flags+=("--exclude=")
    two_word_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude=")
    flags+=("--external-dns-access")
    local_nonpersistent_flags+=("--external-dns-access")
    flags+=("--full-ecr-access")
    local_nonpersistent_flags+=("--full-ecr-access")
    flags+=("--include=")
    two_word_flags+=("--include")
    local_nonpersistent_flags+=("--include")
    local_nonpersistent_flags+=("--include=")
    flags+=("--install-neuron-plugin")
    local_nonpersistent_flags+=("--install-neuron-plugin")
    flags+=("--install-nvidia-plugin")
    local_nonpersistent_flags+=("--install-nvidia-plugin")
    flags+=("--instance-name=")
    two_word_flags+=("--instance-name")
    local_nonpersistent_flags+=("--instance-name")
    local_nonpersistent_flags+=("--instance-name=")
    flags+=("--instance-prefix=")
    two_word_flags+=("--instance-prefix")
    local_nonpersistent_flags+=("--instance-prefix")
    local_nonpersistent_flags+=("--instance-prefix=")
    flags+=("--instance-selector-cpu-architecture=")
    two_word_flags+=("--instance-selector-cpu-architecture")
    local_nonpersistent_flags+=("--instance-selector-cpu-architecture")
    local_nonpersistent_flags+=("--instance-selector-cpu-architecture=")
    flags+=("--instance-selector-gpus=")
    two_word_flags+=("--instance-selector-gpus")
    local_nonpersistent_flags+=("--instance-selector-gpus")
    local_nonpersistent_flags+=("--instance-selector-gpus=")
    flags+=("--instance-selector-memory=")
    two_word_flags+=("--instance-selector-memory")
    local_nonpersistent_flags+=("--instance-selector-memory")
    local_nonpersistent_flags+=("--instance-selector-memory=")
    flags+=("--instance-selector-vcpus=")
    two_word_flags+=("--instance-selector-vcpus")
    local_nonpersistent_flags+=("--instance-selector-vcpus")
    local_nonpersistent_flags+=("--instance-selector-vcpus=")
    flags+=("--instance-types=")
    two_word_flags+=("--instance-types")
    local_nonpersistent_flags+=("--instance-types")
    local_nonpersistent_flags+=("--instance-types=")
    flags+=("--managed")
    local_nonpersistent_flags+=("--managed")
    flags+=("--max-pods-per-node=")
    two_word_flags+=("--max-pods-per-node")
    local_nonpersistent_flags+=("--max-pods-per-node")
    local_nonpersistent_flags+=("--max-pods-per-node=")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--node-ami=")
    two_word_flags+=("--node-ami")
    local_nonpersistent_flags+=("--node-ami")
    local_nonpersistent_flags+=("--node-ami=")
    flags+=("--node-ami-family=")
    two_word_flags+=("--node-ami-family")
    local_nonpersistent_flags+=("--node-ami-family")
    local_nonpersistent_flags+=("--node-ami-family=")
    flags+=("--node-labels=")
    two_word_flags+=("--node-labels")
    local_nonpersistent_flags+=("--node-labels")
    local_nonpersistent_flags+=("--node-labels=")
    flags+=("--node-private-networking")
    flags+=("-P")
    local_nonpersistent_flags+=("--node-private-networking")
    local_nonpersistent_flags+=("-P")
    flags+=("--node-security-groups=")
    two_word_flags+=("--node-security-groups")
    local_nonpersistent_flags+=("--node-security-groups")
    local_nonpersistent_flags+=("--node-security-groups=")
    flags+=("--node-type=")
    two_word_flags+=("--node-type")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--node-type")
    local_nonpersistent_flags+=("--node-type=")
    local_nonpersistent_flags+=("-t")
    flags+=("--node-volume-size=")
    two_word_flags+=("--node-volume-size")
    local_nonpersistent_flags+=("--node-volume-size")
    local_nonpersistent_flags+=("--node-volume-size=")
    flags+=("--node-volume-type=")
    two_word_flags+=("--node-volume-type")
    local_nonpersistent_flags+=("--node-volume-type")
    local_nonpersistent_flags+=("--node-volume-type=")
    flags+=("--node-zones=")
    two_word_flags+=("--node-zones")
    local_nonpersistent_flags+=("--node-zones")
    local_nonpersistent_flags+=("--node-zones=")
    flags+=("--nodegroup-parallelism=")
    two_word_flags+=("--nodegroup-parallelism")
    local_nonpersistent_flags+=("--nodegroup-parallelism")
    local_nonpersistent_flags+=("--nodegroup-parallelism=")
    flags+=("--nodes=")
    two_word_flags+=("--nodes")
    two_word_flags+=("-N")
    local_nonpersistent_flags+=("--nodes")
    local_nonpersistent_flags+=("--nodes=")
    local_nonpersistent_flags+=("-N")
    flags+=("--nodes-max=")
    two_word_flags+=("--nodes-max")
    two_word_flags+=("-M")
    local_nonpersistent_flags+=("--nodes-max")
    local_nonpersistent_flags+=("--nodes-max=")
    local_nonpersistent_flags+=("-M")
    flags+=("--nodes-min=")
    two_word_flags+=("--nodes-min")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--nodes-min")
    local_nonpersistent_flags+=("--nodes-min=")
    local_nonpersistent_flags+=("-m")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--skip-outdated-addons-check")
    local_nonpersistent_flags+=("--skip-outdated-addons-check")
    flags+=("--spot")
    local_nonpersistent_flags+=("--spot")
    flags+=("--ssh-access")
    local_nonpersistent_flags+=("--ssh-access")
    flags+=("--ssh-public-key=")
    two_word_flags+=("--ssh-public-key")
    local_nonpersistent_flags+=("--ssh-public-key")
    local_nonpersistent_flags+=("--ssh-public-key=")
    flags+=("--subnet-ids=")
    two_word_flags+=("--subnet-ids")
    local_nonpersistent_flags+=("--subnet-ids")
    local_nonpersistent_flags+=("--subnet-ids=")
    flags+=("--tags=")
    two_word_flags+=("--tags")
    local_nonpersistent_flags+=("--tags")
    local_nonpersistent_flags+=("--tags=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--update-auth-configmap")
    local_nonpersistent_flags+=("--update-auth-configmap")
    flags+=("--version=")
    two_word_flags+=("--version")
    local_nonpersistent_flags+=("--version")
    local_nonpersistent_flags+=("--version=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_create_podidentityassociation()
{
    last_command="eksctl_create_podidentityassociation"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--create-service-account")
    local_nonpersistent_flags+=("--create-service-account")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--permission-boundary-arn=")
    two_word_flags+=("--permission-boundary-arn")
    local_nonpersistent_flags+=("--permission-boundary-arn")
    local_nonpersistent_flags+=("--permission-boundary-arn=")
    flags+=("--permission-policy-arns=")
    two_word_flags+=("--permission-policy-arns")
    local_nonpersistent_flags+=("--permission-policy-arns")
    local_nonpersistent_flags+=("--permission-policy-arns=")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--role-arn=")
    two_word_flags+=("--role-arn")
    local_nonpersistent_flags+=("--role-arn")
    local_nonpersistent_flags+=("--role-arn=")
    flags+=("--role-name=")
    two_word_flags+=("--role-name")
    local_nonpersistent_flags+=("--role-name")
    local_nonpersistent_flags+=("--role-name=")
    flags+=("--service-account-name=")
    two_word_flags+=("--service-account-name")
    local_nonpersistent_flags+=("--service-account-name")
    local_nonpersistent_flags+=("--service-account-name=")
    flags+=("--tags=")
    two_word_flags+=("--tags")
    local_nonpersistent_flags+=("--tags")
    local_nonpersistent_flags+=("--tags=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--well-known-policies=")
    two_word_flags+=("--well-known-policies")
    local_nonpersistent_flags+=("--well-known-policies")
    local_nonpersistent_flags+=("--well-known-policies=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_create()
{
    last_command="eksctl_create"

    command_aliases=()

    commands=()
    commands+=("accessentry")
    commands+=("addon")
    commands+=("cluster")
    commands+=("fargateprofile")
    commands+=("iamidentitymapping")
    commands+=("iamserviceaccount")
    commands+=("nodegroup")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ng")
        aliashash["ng"]="nodegroup"
    fi
    commands+=("podidentityassociation")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_delete_accessentry()
{
    last_command="eksctl_delete_accessentry"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--principal-arn=")
    two_word_flags+=("--principal-arn")
    local_nonpersistent_flags+=("--principal-arn")
    local_nonpersistent_flags+=("--principal-arn=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_delete_addon()
{
    last_command="eksctl_delete_addon"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--preserve")
    local_nonpersistent_flags+=("--preserve")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_delete_cluster()
{
    last_command="eksctl_delete_cluster"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cfn-disable-rollback")
    local_nonpersistent_flags+=("--cfn-disable-rollback")
    flags+=("--cfn-role-arn=")
    two_word_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn=")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--disable-nodegroup-eviction")
    local_nonpersistent_flags+=("--disable-nodegroup-eviction")
    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--parallel=")
    two_word_flags+=("--parallel")
    local_nonpersistent_flags+=("--parallel")
    local_nonpersistent_flags+=("--parallel=")
    flags+=("--pod-eviction-wait-period=")
    two_word_flags+=("--pod-eviction-wait-period")
    local_nonpersistent_flags+=("--pod-eviction-wait-period")
    local_nonpersistent_flags+=("--pod-eviction-wait-period=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    local_nonpersistent_flags+=("-w")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_delete_fargateprofile()
{
    last_command="eksctl_delete_fargateprofile"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    local_nonpersistent_flags+=("-w")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_delete_iamidentitymapping()
{
    last_command="eksctl_delete_iamidentitymapping"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--arn=")
    two_word_flags+=("--arn")
    local_nonpersistent_flags+=("--arn")
    local_nonpersistent_flags+=("--arn=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_delete_iamserviceaccount()
{
    last_command="eksctl_delete_iamserviceaccount"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cfn-disable-rollback")
    local_nonpersistent_flags+=("--cfn-disable-rollback")
    flags+=("--cfn-role-arn=")
    two_word_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--exclude=")
    two_word_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude=")
    flags+=("--include=")
    two_word_flags+=("--include")
    local_nonpersistent_flags+=("--include")
    local_nonpersistent_flags+=("--include=")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--only-missing")
    local_nonpersistent_flags+=("--only-missing")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    local_nonpersistent_flags+=("-w")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_delete_nodegroup()
{
    last_command="eksctl_delete_nodegroup"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cfn-disable-rollback")
    local_nonpersistent_flags+=("--cfn-disable-rollback")
    flags+=("--cfn-role-arn=")
    two_word_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--disable-eviction")
    local_nonpersistent_flags+=("--disable-eviction")
    flags+=("--drain")
    local_nonpersistent_flags+=("--drain")
    flags+=("--exclude=")
    two_word_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude=")
    flags+=("--include=")
    two_word_flags+=("--include")
    local_nonpersistent_flags+=("--include")
    local_nonpersistent_flags+=("--include=")
    flags+=("--max-grace-period=")
    two_word_flags+=("--max-grace-period")
    local_nonpersistent_flags+=("--max-grace-period")
    local_nonpersistent_flags+=("--max-grace-period=")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--only-missing")
    local_nonpersistent_flags+=("--only-missing")
    flags+=("--parallel=")
    two_word_flags+=("--parallel")
    local_nonpersistent_flags+=("--parallel")
    local_nonpersistent_flags+=("--parallel=")
    flags+=("--pod-eviction-wait-period=")
    two_word_flags+=("--pod-eviction-wait-period")
    local_nonpersistent_flags+=("--pod-eviction-wait-period")
    local_nonpersistent_flags+=("--pod-eviction-wait-period=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--update-auth-configmap")
    local_nonpersistent_flags+=("--update-auth-configmap")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    local_nonpersistent_flags+=("-w")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_delete_podidentityassociation()
{
    last_command="eksctl_delete_podidentityassociation"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service-account-name=")
    two_word_flags+=("--service-account-name")
    local_nonpersistent_flags+=("--service-account-name")
    local_nonpersistent_flags+=("--service-account-name=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_delete()
{
    last_command="eksctl_delete"

    command_aliases=()

    commands=()
    commands+=("accessentry")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("accessentries")
        aliashash["accessentries"]="accessentry"
    fi
    commands+=("addon")
    commands+=("cluster")
    commands+=("fargateprofile")
    commands+=("iamidentitymapping")
    commands+=("iamserviceaccount")
    commands+=("nodegroup")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ng")
        aliashash["ng"]="nodegroup"
    fi
    commands+=("podidentityassociation")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_deregister_cluster()
{
    last_command="eksctl_deregister_cluster"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_flag+=("--name=")
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_deregister()
{
    last_command="eksctl_deregister"

    command_aliases=()

    commands=()
    commands+=("cluster")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_disassociate_identityprovider()
{
    last_command="eksctl_disassociate_identityprovider"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--type=")
    two_word_flags+=("--type")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    local_nonpersistent_flags+=("-w")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_disassociate()
{
    last_command="eksctl_disassociate"

    command_aliases=()

    commands=()
    commands+=("identityprovider")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_drain_nodegroup()
{
    last_command="eksctl_drain_nodegroup"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cfn-disable-rollback")
    local_nonpersistent_flags+=("--cfn-disable-rollback")
    flags+=("--cfn-role-arn=")
    two_word_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--disable-eviction")
    local_nonpersistent_flags+=("--disable-eviction")
    flags+=("--exclude=")
    two_word_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude=")
    flags+=("--include=")
    two_word_flags+=("--include")
    local_nonpersistent_flags+=("--include")
    local_nonpersistent_flags+=("--include=")
    flags+=("--max-grace-period=")
    two_word_flags+=("--max-grace-period")
    local_nonpersistent_flags+=("--max-grace-period")
    local_nonpersistent_flags+=("--max-grace-period=")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--node-drain-wait-period=")
    two_word_flags+=("--node-drain-wait-period")
    local_nonpersistent_flags+=("--node-drain-wait-period")
    local_nonpersistent_flags+=("--node-drain-wait-period=")
    flags+=("--only-missing")
    local_nonpersistent_flags+=("--only-missing")
    flags+=("--parallel=")
    two_word_flags+=("--parallel")
    local_nonpersistent_flags+=("--parallel")
    local_nonpersistent_flags+=("--parallel=")
    flags+=("--pod-eviction-wait-period=")
    two_word_flags+=("--pod-eviction-wait-period")
    local_nonpersistent_flags+=("--pod-eviction-wait-period")
    local_nonpersistent_flags+=("--pod-eviction-wait-period=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--undo")
    local_nonpersistent_flags+=("--undo")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_drain()
{
    last_command="eksctl_drain"

    command_aliases=()

    commands=()
    commands+=("nodegroup")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ng")
        aliashash["ng"]="nodegroup"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_enable_flux()
{
    last_command="eksctl_enable_flux"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_enable()
{
    last_command="eksctl_enable"

    command_aliases=()

    commands=()
    commands+=("flux")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get_accessentry()
{
    last_command="eksctl_get_accessentry"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--chunk-size=")
    two_word_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--principal-arn=")
    two_word_flags+=("--principal-arn")
    local_nonpersistent_flags+=("--principal-arn")
    local_nonpersistent_flags+=("--principal-arn=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get_addon()
{
    last_command="eksctl_get_addon"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--chunk-size=")
    two_word_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get_cluster()
{
    last_command="eksctl_get_cluster"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-regions")
    flags+=("-A")
    local_nonpersistent_flags+=("--all-regions")
    local_nonpersistent_flags+=("-A")
    flags+=("--chunk-size=")
    two_word_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size=")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get_fargateprofile()
{
    last_command="eksctl_get_fargateprofile"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--chunk-size=")
    two_word_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get_iamidentitymapping()
{
    last_command="eksctl_get_iamidentitymapping"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--arn=")
    two_word_flags+=("--arn")
    local_nonpersistent_flags+=("--arn")
    local_nonpersistent_flags+=("--arn=")
    flags+=("--chunk-size=")
    two_word_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get_iamserviceaccount()
{
    last_command="eksctl_get_iamserviceaccount"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--chunk-size=")
    two_word_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get_identityprovider()
{
    last_command="eksctl_get_identityprovider"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--chunk-size=")
    two_word_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get_labels()
{
    last_command="eksctl_get_labels"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--nodegroup=")
    two_word_flags+=("--nodegroup")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--nodegroup")
    local_nonpersistent_flags+=("--nodegroup=")
    local_nonpersistent_flags+=("-n")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get_nodegroup()
{
    last_command="eksctl_get_nodegroup"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--chunk-size=")
    two_word_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get_podidentityassociation()
{
    last_command="eksctl_get_podidentityassociation"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--chunk-size=")
    two_word_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size")
    local_nonpersistent_flags+=("--chunk-size=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service-account-name=")
    two_word_flags+=("--service-account-name")
    local_nonpersistent_flags+=("--service-account-name")
    local_nonpersistent_flags+=("--service-account-name=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_get()
{
    last_command="eksctl_get"

    command_aliases=()

    commands=()
    commands+=("accessentry")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("accessentries")
        aliashash["accessentries"]="accessentry"
    fi
    commands+=("addon")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("addons")
        aliashash["addons"]="addon"
    fi
    commands+=("cluster")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("clusters")
        aliashash["clusters"]="cluster"
    fi
    commands+=("fargateprofile")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("fargateprofiles")
        aliashash["fargateprofiles"]="fargateprofile"
    fi
    commands+=("iamidentitymapping")
    commands+=("iamserviceaccount")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("iamserviceaccounts")
        aliashash["iamserviceaccounts"]="iamserviceaccount"
    fi
    commands+=("identityprovider")
    commands+=("labels")
    commands+=("nodegroup")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ng")
        aliashash["ng"]="nodegroup"
        command_aliases+=("nodegroups")
        aliashash["nodegroups"]="nodegroup"
    fi
    commands+=("podidentityassociation")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("podidentityassociations")
        aliashash["podidentityassociations"]="podidentityassociation"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_help()
{
    last_command="eksctl_help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_eksctl_info()
{
    last_command="eksctl_info"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_register_cluster()
{
    last_command="eksctl_register_cluster"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--provider=")
    two_word_flags+=("--provider")
    local_nonpersistent_flags+=("--provider")
    local_nonpersistent_flags+=("--provider=")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--role-arn=")
    two_word_flags+=("--role-arn")
    local_nonpersistent_flags+=("--role-arn")
    local_nonpersistent_flags+=("--role-arn=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_flag+=("--name=")
    must_have_one_flag+=("--provider=")
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_register()
{
    last_command="eksctl_register"

    command_aliases=()

    commands=()
    commands+=("cluster")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_scale_nodegroup()
{
    last_command="eksctl_scale_nodegroup"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cfn-disable-rollback")
    local_nonpersistent_flags+=("--cfn-disable-rollback")
    flags+=("--cfn-role-arn=")
    two_word_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--nodes=")
    two_word_flags+=("--nodes")
    two_word_flags+=("-N")
    local_nonpersistent_flags+=("--nodes")
    local_nonpersistent_flags+=("--nodes=")
    local_nonpersistent_flags+=("-N")
    flags+=("--nodes-max=")
    two_word_flags+=("--nodes-max")
    two_word_flags+=("-M")
    local_nonpersistent_flags+=("--nodes-max")
    local_nonpersistent_flags+=("--nodes-max=")
    local_nonpersistent_flags+=("-M")
    flags+=("--nodes-min=")
    two_word_flags+=("--nodes-min")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--nodes-min")
    local_nonpersistent_flags+=("--nodes-min=")
    local_nonpersistent_flags+=("-m")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    local_nonpersistent_flags+=("-w")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_scale()
{
    last_command="eksctl_scale"

    command_aliases=()

    commands=()
    commands+=("nodegroup")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ng")
        aliashash["ng"]="nodegroup"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_set_labels()
{
    last_command="eksctl_set_labels"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--labels=")
    two_word_flags+=("--labels")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--labels")
    local_nonpersistent_flags+=("--labels=")
    local_nonpersistent_flags+=("-l")
    flags+=("--nodegroup=")
    two_word_flags+=("--nodegroup")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--nodegroup")
    local_nonpersistent_flags+=("--nodegroup=")
    local_nonpersistent_flags+=("-n")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_set()
{
    last_command="eksctl_set"

    command_aliases=()

    commands=()
    commands+=("labels")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_unset_labels()
{
    last_command="eksctl_unset_labels"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--labels=")
    two_word_flags+=("--labels")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--labels")
    local_nonpersistent_flags+=("--labels=")
    local_nonpersistent_flags+=("-l")
    flags+=("--nodegroup=")
    two_word_flags+=("--nodegroup")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--nodegroup")
    local_nonpersistent_flags+=("--nodegroup=")
    local_nonpersistent_flags+=("-n")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_flag+=("--labels=")
    must_have_one_flag+=("-l")
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_unset()
{
    last_command="eksctl_unset"

    command_aliases=()

    commands=()
    commands+=("labels")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_update_addon()
{
    last_command="eksctl_update_addon"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service-account-role-arn=")
    two_word_flags+=("--service-account-role-arn")
    local_nonpersistent_flags+=("--service-account-role-arn")
    local_nonpersistent_flags+=("--service-account-role-arn=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--version=")
    two_word_flags+=("--version")
    local_nonpersistent_flags+=("--version")
    local_nonpersistent_flags+=("--version=")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_update_cluster()
{
    last_command="eksctl_update_cluster"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--version=")
    two_word_flags+=("--version")
    local_nonpersistent_flags+=("--version")
    local_nonpersistent_flags+=("--version=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_update_iamserviceaccount()
{
    last_command="eksctl_update_iamserviceaccount"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--attach-policy-arn=")
    two_word_flags+=("--attach-policy-arn")
    local_nonpersistent_flags+=("--attach-policy-arn")
    local_nonpersistent_flags+=("--attach-policy-arn=")
    flags+=("--cfn-disable-rollback")
    local_nonpersistent_flags+=("--cfn-disable-rollback")
    flags+=("--cfn-role-arn=")
    two_word_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn")
    local_nonpersistent_flags+=("--cfn-role-arn=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--exclude=")
    two_word_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude=")
    flags+=("--include=")
    two_word_flags+=("--include")
    local_nonpersistent_flags+=("--include")
    local_nonpersistent_flags+=("--include=")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_update_nodegroup()
{
    last_command="eksctl_update_nodegroup"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    local_nonpersistent_flags+=("-w")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_update_podidentityassociation()
{
    last_command="eksctl_update_podidentityassociation"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--role-arn=")
    two_word_flags+=("--role-arn")
    local_nonpersistent_flags+=("--role-arn")
    local_nonpersistent_flags+=("--role-arn=")
    flags+=("--service-account-name=")
    two_word_flags+=("--service-account-name")
    local_nonpersistent_flags+=("--service-account-name")
    local_nonpersistent_flags+=("--service-account-name=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_update()
{
    last_command="eksctl_update"

    command_aliases=()

    commands=()
    commands+=("addon")
    commands+=("cluster")
    commands+=("iamserviceaccount")
    commands+=("nodegroup")
    commands+=("podidentityassociation")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_upgrade_cluster()
{
    last_command="eksctl_upgrade_cluster"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--version=")
    two_word_flags+=("--version")
    local_nonpersistent_flags+=("--version")
    local_nonpersistent_flags+=("--version=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_upgrade_nodegroup()
{
    last_command="eksctl_upgrade_nodegroup"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--force-upgrade")
    local_nonpersistent_flags+=("--force-upgrade")
    flags+=("--kubernetes-version=")
    two_word_flags+=("--kubernetes-version")
    local_nonpersistent_flags+=("--kubernetes-version")
    local_nonpersistent_flags+=("--kubernetes-version=")
    flags+=("--launch-template-version=")
    two_word_flags+=("--launch-template-version")
    local_nonpersistent_flags+=("--launch-template-version")
    local_nonpersistent_flags+=("--launch-template-version=")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--release-version=")
    two_word_flags+=("--release-version")
    local_nonpersistent_flags+=("--release-version")
    local_nonpersistent_flags+=("--release-version=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_upgrade()
{
    last_command="eksctl_upgrade"

    command_aliases=()

    commands=()
    commands+=("cluster")
    commands+=("nodegroup")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_associate-iam-oidc-provider()
{
    last_command="eksctl_utils_associate-iam-oidc-provider"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_describe-addon-configuration()
{
    last_command="eksctl_utils_describe-addon-configuration"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--version=")
    two_word_flags+=("--version")
    local_nonpersistent_flags+=("--version")
    local_nonpersistent_flags+=("--version=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_flag+=("--name=")
    must_have_one_flag+=("--version=")
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_describe-addon-versions()
{
    last_command="eksctl_utils_describe-addon-versions"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--kubernetes-version=")
    two_word_flags+=("--kubernetes-version")
    local_nonpersistent_flags+=("--kubernetes-version")
    local_nonpersistent_flags+=("--kubernetes-version=")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--owners=")
    two_word_flags+=("--owners")
    local_nonpersistent_flags+=("--owners")
    local_nonpersistent_flags+=("--owners=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--publishers=")
    two_word_flags+=("--publishers")
    local_nonpersistent_flags+=("--publishers")
    local_nonpersistent_flags+=("--publishers=")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--types=")
    two_word_flags+=("--types")
    local_nonpersistent_flags+=("--types")
    local_nonpersistent_flags+=("--types=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_describe-stacks()
{
    last_command="eksctl_utils_describe-stacks"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--events")
    local_nonpersistent_flags+=("--events")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--resource-status=")
    two_word_flags+=("--resource-status")
    local_nonpersistent_flags+=("--resource-status")
    local_nonpersistent_flags+=("--resource-status=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--trail")
    local_nonpersistent_flags+=("--trail")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_enable-secrets-encryption()
{
    last_command="eksctl_utils_enable-secrets-encryption"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--encrypt-existing-secrets")
    local_nonpersistent_flags+=("--encrypt-existing-secrets")
    flags+=("--key-arn=")
    two_word_flags+=("--key-arn")
    local_nonpersistent_flags+=("--key-arn")
    local_nonpersistent_flags+=("--key-arn=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_install-vpc-controllers()
{
    last_command="eksctl_utils_install-vpc-controllers"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_migrate-to-access-entry()
{
    last_command="eksctl_utils_migrate-to-access-entry"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--target-authentication-mode=")
    two_word_flags+=("--target-authentication-mode")
    local_nonpersistent_flags+=("--target-authentication-mode")
    local_nonpersistent_flags+=("--target-authentication-mode=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_migrate-to-pod-identity()
{
    last_command="eksctl_utils_migrate-to-pod-identity"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--remove-oidc-provider-trust-relationship")
    local_nonpersistent_flags+=("--remove-oidc-provider-trust-relationship")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_nodegroup-health()
{
    last_command="eksctl_utils_nodegroup-health"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_schema()
{
    last_command="eksctl_utils_schema"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_update-authentication-mode()
{
    last_command="eksctl_utils_update-authentication-mode"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--authentication-mode=")
    two_word_flags+=("--authentication-mode")
    local_nonpersistent_flags+=("--authentication-mode")
    local_nonpersistent_flags+=("--authentication-mode=")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_update-aws-node()
{
    last_command="eksctl_utils_update-aws-node"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_update-cluster-logging()
{
    last_command="eksctl_utils_update-cluster-logging"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--disable-types=")
    two_word_flags+=("--disable-types")
    local_nonpersistent_flags+=("--disable-types")
    local_nonpersistent_flags+=("--disable-types=")
    flags+=("--enable-types=")
    two_word_flags+=("--enable-types")
    local_nonpersistent_flags+=("--enable-types")
    local_nonpersistent_flags+=("--enable-types=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_update-cluster-vpc-config()
{
    last_command="eksctl_utils_update-cluster-vpc-config"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--control-plane-security-group-ids=")
    two_word_flags+=("--control-plane-security-group-ids")
    local_nonpersistent_flags+=("--control-plane-security-group-ids")
    local_nonpersistent_flags+=("--control-plane-security-group-ids=")
    flags+=("--control-plane-subnet-ids=")
    two_word_flags+=("--control-plane-subnet-ids")
    local_nonpersistent_flags+=("--control-plane-subnet-ids")
    local_nonpersistent_flags+=("--control-plane-subnet-ids=")
    flags+=("--private-access")
    local_nonpersistent_flags+=("--private-access")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--public-access")
    local_nonpersistent_flags+=("--public-access")
    flags+=("--public-access-cidrs=")
    two_word_flags+=("--public-access-cidrs")
    local_nonpersistent_flags+=("--public-access-cidrs")
    local_nonpersistent_flags+=("--public-access-cidrs=")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_update-coredns()
{
    last_command="eksctl_utils_update-coredns"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_update-kube-proxy()
{
    last_command="eksctl_utils_update-kube-proxy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--approve")
    local_nonpersistent_flags+=("--approve")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_update-legacy-subnet-settings()
{
    last_command="eksctl_utils_update-legacy-subnet-settings"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils_write-kubeconfig()
{
    last_command="eksctl_utils_write-kubeconfig"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--authenticator-role-arn=")
    two_word_flags+=("--authenticator-role-arn")
    local_nonpersistent_flags+=("--authenticator-role-arn")
    local_nonpersistent_flags+=("--authenticator-role-arn=")
    flags+=("--auto-kubeconfig")
    local_nonpersistent_flags+=("--auto-kubeconfig")
    flags+=("--cluster=")
    two_word_flags+=("--cluster")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cluster")
    local_nonpersistent_flags+=("--cluster=")
    local_nonpersistent_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig=")
    flags+=("--profile=")
    two_word_flags+=("--profile")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--profile")
    local_nonpersistent_flags+=("--profile=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--set-kubeconfig-context")
    local_nonpersistent_flags+=("--set-kubeconfig-context")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_utils()
{
    last_command="eksctl_utils"

    command_aliases=()

    commands=()
    commands+=("associate-iam-oidc-provider")
    commands+=("describe-addon-configuration")
    commands+=("describe-addon-versions")
    commands+=("describe-stacks")
    commands+=("enable-secrets-encryption")
    commands+=("install-vpc-controllers")
    commands+=("migrate-to-access-entry")
    commands+=("migrate-to-pod-identity")
    commands+=("nodegroup-health")
    commands+=("schema")
    commands+=("update-authentication-mode")
    commands+=("update-aws-node")
    commands+=("update-cluster-logging")
    commands+=("update-cluster-vpc-config")
    commands+=("update-coredns")
    commands+=("update-kube-proxy")
    commands+=("update-legacy-subnet-settings")
    commands+=("write-kubeconfig")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_version()
{
    last_command="eksctl_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_eksctl_root_command()
{
    last_command="eksctl"

    command_aliases=()

    commands=()
    commands+=("anywhere")
    commands+=("associate")
    commands+=("completion")
    commands+=("create")
    commands+=("delete")
    commands+=("deregister")
    commands+=("disassociate")
    commands+=("drain")
    commands+=("enable")
    commands+=("get")
    commands+=("help")
    commands+=("info")
    commands+=("register")
    commands+=("scale")
    commands+=("set")
    commands+=("unset")
    commands+=("update")
    commands+=("upgrade")
    commands+=("utils")
    commands+=("version")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    two_word_flags+=("-C")
    flags+=("--dumpLogs")
    flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_eksctl()
{
    local cur prev words cword split
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __eksctl_init_completion -n "=" || return
    fi

    local c=0
    local flag_parsing_disabled=
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("eksctl")
    local command_aliases=()
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function=""
    local last_command=""
    local nouns=()
    local noun_aliases=()

    __eksctl_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_eksctl eksctl
else
    complete -o default -o nospace -F __start_eksctl eksctl
fi

# ex: ts=4 sw=4 et filetype=sh
