# bash completion for kubecm                               -*- shell-script -*-

__kubecm_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__kubecm_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__kubecm_index_of_word()
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

__kubecm_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__kubecm_handle_go_custom_completion()
{
    __kubecm_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly kubecm allows to handle aliases
    args=("${words[@]:1}")
    requestComp="${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __kubecm_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __kubecm_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __kubecm_debug "${FUNCNAME[0]}: calling ${requestComp}"
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
    __kubecm_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __kubecm_debug "${FUNCNAME[0]}: the completions are: ${out[*]}"

    if [ $((directive & 1)) -ne 0 ]; then
        # Error code.  No completion.
        __kubecm_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & 2)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __kubecm_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & 4)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __kubecm_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi

        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out[*]}" -- "$cur")
    fi
}

__kubecm_handle_reply()
{
    __kubecm_debug "${FUNCNAME[0]}"
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
                __kubecm_index_of_word "${flag}" "${flags_with_completion[@]}"
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
    __kubecm_index_of_word "${prev}" "${flags_with_completion[@]}"
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
    elif [[ -n "${has_completion_function}" ]]; then
        # if a go completion function is provided, defer to that function
        completions=()
        __kubecm_handle_go_custom_completion
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
		if declare -F __kubecm_custom_func >/dev/null; then
			# try command name qualified custom func
			__kubecm_custom_func
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
__kubecm_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__kubecm_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__kubecm_handle_flag()
{
    __kubecm_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __kubecm_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __kubecm_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __kubecm_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
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
    if [[ ${words[c]} != *"="* ]] && __kubecm_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __kubecm_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__kubecm_handle_noun()
{
    __kubecm_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __kubecm_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __kubecm_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__kubecm_handle_command()
{
    __kubecm_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_kubecm_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __kubecm_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__kubecm_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __kubecm_handle_reply
        return
    fi
    __kubecm_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __kubecm_handle_flag
    elif __kubecm_contains_word "${words[c]}" "${commands[@]}"; then
        __kubecm_handle_command
    elif [[ $c -eq 0 ]]; then
        __kubecm_handle_command
    elif __kubecm_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __kubecm_handle_command
        else
            __kubecm_handle_noun
        fi
    else
        __kubecm_handle_noun
    fi
    __kubecm_handle_word
}

_kubecm_add()
{
    last_command="kubecm_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--file=")
    two_word_flags+=("--file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--file=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_flag+=("--file=")
    must_have_one_flag+=("-f")
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_alias()
{
    last_command="kubecm_alias"

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
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_flag+=("--out=")
    must_have_one_flag+=("-o")
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_clear()
{
    last_command="kubecm_clear"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_completion()
{
    last_command="kubecm_completion"

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
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_create()
{
    last_command="kubecm_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_delete()
{
    last_command="kubecm_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_list()
{
    last_command="kubecm_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_merge()
{
    last_command="kubecm_merge"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--folder=")
    two_word_flags+=("--folder")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--folder=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_flag+=("--folder=")
    must_have_one_flag+=("-f")
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_namespace()
{
    last_command="kubecm_namespace"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_rename()
{
    last_command="kubecm_rename"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_switch()
{
    last_command="kubecm_switch"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_version()
{
    last_command="kubecm_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kubecm_root_command()
{
    last_command="kubecm"

    command_aliases=()

    commands=()
    commands+=("add")
    commands+=("alias")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("al")
        aliashash["al"]="alias"
    fi
    commands+=("clear")
    commands+=("completion")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="completion"
    fi
    commands+=("create")
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("l")
        aliashash["l"]="list"
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("merge")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("m")
        aliashash["m"]="merge"
    fi
    commands+=("namespace")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ns")
        aliashash["ns"]="namespace"
    fi
    commands+=("rename")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("r")
        aliashash["r"]="rename"
    fi
    commands+=("switch")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="switch"
    fi
    commands+=("version")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("v")
        aliashash["v"]="version"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_kubecm()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __kubecm_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("kubecm")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function
    local last_command
    local nouns=()

    __kubecm_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_kubecm kubecm
else
    complete -o default -o nospace -F __start_kubecm kubecm
fi

# ex: ts=4 sw=4 et filetype=sh
