# bash completion for kind                                 -*- shell-script -*-

__kind_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__kind_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__kind_index_of_word()
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

__kind_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__kind_handle_go_custom_completion()
{
    __kind_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly kind allows to handle aliases
    args=("${words[@]:1}")
    requestComp="${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __kind_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __kind_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __kind_debug "${FUNCNAME[0]}: calling ${requestComp}"
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
    __kind_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __kind_debug "${FUNCNAME[0]}: the completions are: ${out[*]}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __kind_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __kind_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __kind_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local fullFilter filter filteringCmd
        # Do not use quotes around the $out variable or else newline
        # characters will be kept.
        for filter in ${out[*]}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __kind_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subDir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out[0]}")
        if [ -n "$subdir" ]; then
            __kind_debug "Listing directories in $subdir"
            __kind_handle_subdirs_in_dir_flag "$subdir"
        else
            __kind_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out[*]}" -- "$cur")
    fi
}

__kind_handle_reply()
{
    __kind_debug "${FUNCNAME[0]}"
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
                __kind_index_of_word "${flag}" "${flags_with_completion[@]}"
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
    __kind_index_of_word "${prev}" "${flags_with_completion[@]}"
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
        __kind_handle_go_custom_completion
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
		if declare -F __kind_custom_func >/dev/null; then
			# try command name qualified custom func
			__kind_custom_func
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
__kind_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__kind_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__kind_handle_flag()
{
    __kind_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __kind_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __kind_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __kind_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
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
    if [[ ${words[c]} != *"="* ]] && __kind_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __kind_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__kind_handle_noun()
{
    __kind_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __kind_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __kind_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__kind_handle_command()
{
    __kind_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_kind_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __kind_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__kind_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __kind_handle_reply
        return
    fi
    __kind_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __kind_handle_flag
    elif __kind_contains_word "${words[c]}" "${commands[@]}"; then
        __kind_handle_command
    elif [[ $c -eq 0 ]]; then
        __kind_handle_command
    elif __kind_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __kind_handle_command
        else
            __kind_handle_noun
        fi
    else
        __kind_handle_noun
    fi
    __kind_handle_word
}

_kind_build_node-image()
{
    last_command="kind_build_node-image"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--arch=")
    two_word_flags+=("--arch")
    local_nonpersistent_flags+=("--arch")
    local_nonpersistent_flags+=("--arch=")
    flags+=("--base-image=")
    two_word_flags+=("--base-image")
    local_nonpersistent_flags+=("--base-image")
    local_nonpersistent_flags+=("--base-image=")
    flags+=("--image=")
    two_word_flags+=("--image")
    local_nonpersistent_flags+=("--image")
    local_nonpersistent_flags+=("--image=")
    flags+=("--kube-root=")
    two_word_flags+=("--kube-root")
    local_nonpersistent_flags+=("--kube-root")
    local_nonpersistent_flags+=("--kube-root=")
    flags+=("--type=")
    two_word_flags+=("--type")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_build()
{
    last_command="kind_build"

    command_aliases=()

    commands=()
    commands+=("node-image")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_completion_bash()
{
    last_command="kind_completion_bash"

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
    local_nonpersistent_flags+=("-h")
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_completion_fish()
{
    last_command="kind_completion_fish"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_completion_zsh()
{
    last_command="kind_completion_zsh"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_completion()
{
    last_command="kind_completion"

    command_aliases=()

    commands=()
    commands+=("bash")
    commands+=("fish")
    commands+=("zsh")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_create_cluster()
{
    last_command="kind_create_cluster"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    local_nonpersistent_flags+=("--config")
    local_nonpersistent_flags+=("--config=")
    flags+=("--image=")
    two_word_flags+=("--image")
    local_nonpersistent_flags+=("--image")
    local_nonpersistent_flags+=("--image=")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig=")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--retain")
    local_nonpersistent_flags+=("--retain")
    flags+=("--wait=")
    two_word_flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    local_nonpersistent_flags+=("--wait=")
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_create()
{
    last_command="kind_create"

    command_aliases=()

    commands=()
    commands+=("cluster")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_delete_cluster()
{
    last_command="kind_delete_cluster"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig=")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_delete_clusters()
{
    last_command="kind_delete_clusters"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig=")
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_delete()
{
    last_command="kind_delete"

    command_aliases=()

    commands=()
    commands+=("cluster")
    commands+=("clusters")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_export_kubeconfig()
{
    last_command="kind_export_kubeconfig"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig")
    local_nonpersistent_flags+=("--kubeconfig=")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_export_logs()
{
    last_command="kind_export_logs"

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
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_export()
{
    last_command="kind_export"

    command_aliases=()

    commands=()
    commands+=("kubeconfig")
    commands+=("logs")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_get_clusters()
{
    last_command="kind_get_clusters"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_get_kubeconfig()
{
    last_command="kind_get_kubeconfig"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--internal")
    local_nonpersistent_flags+=("--internal")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_get_nodes()
{
    last_command="kind_get_nodes"

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
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_get()
{
    last_command="kind_get"

    command_aliases=()

    commands=()
    commands+=("clusters")
    commands+=("kubeconfig")
    commands+=("nodes")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_help()
{
    last_command="kind_help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_kind_load_docker-image()
{
    last_command="kind_load_docker-image"

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
    flags+=("--nodes=")
    two_word_flags+=("--nodes")
    local_nonpersistent_flags+=("--nodes")
    local_nonpersistent_flags+=("--nodes=")
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_load_image-archive()
{
    last_command="kind_load_image-archive"

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
    flags+=("--nodes=")
    two_word_flags+=("--nodes")
    local_nonpersistent_flags+=("--nodes")
    local_nonpersistent_flags+=("--nodes=")
    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_load()
{
    last_command="kind_load"

    command_aliases=()

    commands=()
    commands+=("docker-image")
    commands+=("image-archive")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_version()
{
    last_command="kind_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kind_root_command()
{
    last_command="kind"

    command_aliases=()

    commands=()
    commands+=("build")
    commands+=("completion")
    commands+=("create")
    commands+=("delete")
    commands+=("export")
    commands+=("get")
    commands+=("help")
    commands+=("load")
    commands+=("version")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--loglevel=")
    two_word_flags+=("--loglevel")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--verbosity=")
    two_word_flags+=("--verbosity")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_kind()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __kind_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("kind")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function
    local last_command
    local nouns=()

    __kind_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_kind kind
else
    complete -o default -o nospace -F __start_kind kind
fi

# ex: ts=4 sw=4 et filetype=sh
