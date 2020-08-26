# bash completion for civo                                 -*- shell-script -*-

__civo_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__civo_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__civo_index_of_word()
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

__civo_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__civo_handle_go_custom_completion()
{
    __civo_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly civo allows to handle aliases
    args=("${words[@]:1}")
    requestComp="${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __civo_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __civo_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __civo_debug "${FUNCNAME[0]}: calling ${requestComp}"
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
    __civo_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __civo_debug "${FUNCNAME[0]}: the completions are: ${out[*]}"

    if [ $((directive & 1)) -ne 0 ]; then
        # Error code.  No completion.
        __civo_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & 2)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __civo_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & 4)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __civo_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi

        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out[*]}" -- "$cur")
    fi
}

__civo_handle_reply()
{
    __civo_debug "${FUNCNAME[0]}"
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
                __civo_index_of_word "${flag}" "${flags_with_completion[@]}"
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
    __civo_index_of_word "${prev}" "${flags_with_completion[@]}"
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
        __civo_handle_go_custom_completion
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
		if declare -F __civo_custom_func >/dev/null; then
			# try command name qualified custom func
			__civo_custom_func
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
__civo_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__civo_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__civo_handle_flag()
{
    __civo_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __civo_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __civo_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __civo_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
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
    if [[ ${words[c]} != *"="* ]] && __civo_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __civo_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__civo_handle_noun()
{
    __civo_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __civo_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __civo_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__civo_handle_command()
{
    __civo_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_civo_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __civo_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__civo_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __civo_handle_reply
        return
    fi
    __civo_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __civo_handle_flag
    elif __civo_contains_word "${words[c]}" "${commands[@]}"; then
        __civo_handle_command
    elif [[ $c -eq 0 ]]; then
        __civo_handle_command
    elif __civo_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __civo_handle_command
        else
            __civo_handle_noun
        fi
    else
        __civo_handle_noun
    fi
    __civo_handle_word
}

_civo_apikey_current()
{
    last_command="civo_apikey_current"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_apikey_ls()
{
    last_command="civo_apikey_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_apikey_remove()
{
    last_command="civo_apikey_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_apikey_save()
{
    last_command="civo_apikey_save"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_apikey()
{
    last_command="civo_apikey"

    command_aliases=()

    commands=()
    commands+=("current")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("default")
        aliashash["default"]="current"
        command_aliases+=("set")
        aliashash["set"]="current"
        command_aliases+=("use")
        aliashash["use"]="current"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("save")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="save"
        command_aliases+=("create")
        aliashash["create"]="save"
        command_aliases+=("new")
        aliashash["new"]="save"
        command_aliases+=("store")
        aliashash["store"]="save"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_completion_bash()
{
    last_command="civo_completion_bash"

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
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_completion_zsh()
{
    last_command="civo_completion_zsh"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_completion()
{
    last_command="civo_completion"

    command_aliases=()

    commands=()
    commands+=("bash")
    commands+=("zsh")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_domain_create()
{
    last_command="civo_domain_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_domain_ls()
{
    last_command="civo_domain_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_domain_record_create()
{
    last_command="civo_domain_record_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--priority=")
    two_word_flags+=("--priority")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--priority=")
    flags+=("--ttl=")
    two_word_flags+=("--ttl")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--ttl=")
    flags+=("--type=")
    two_word_flags+=("--type")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--type=")
    flags+=("--value=")
    two_word_flags+=("--value")
    two_word_flags+=("-v")
    local_nonpersistent_flags+=("--value=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_domain_record_ls()
{
    last_command="civo_domain_record_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_civo_domain_record_remove()
{
    last_command="civo_domain_record_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_domain_record_show()
{
    last_command="civo_domain_record_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_domain_record()
{
    last_command="civo_domain_record"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("show")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("get")
        aliashash["get"]="show"
        command_aliases+=("inspect")
        aliashash["inspect"]="show"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_domain_remove()
{
    last_command="civo_domain_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_domain()
{
    last_command="civo_domain"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("record")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("records")
        aliashash["records"]="record"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_firewall_create()
{
    last_command="civo_firewall_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_firewall_ls()
{
    last_command="civo_firewall_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_firewall_remove()
{
    last_command="civo_firewall_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_firewall_rule_create()
{
    last_command="civo_firewall_rule_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cidr=")
    two_word_flags+=("--cidr")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cidr=")
    flags+=("--direction=")
    two_word_flags+=("--direction")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--direction=")
    flags+=("--endport=")
    two_word_flags+=("--endport")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--endport=")
    flags+=("--label=")
    two_word_flags+=("--label")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label=")
    flags+=("--protocol=")
    two_word_flags+=("--protocol")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--protocol=")
    flags+=("--startport=")
    two_word_flags+=("--startport")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--startport=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_firewall_rule_ls()
{
    last_command="civo_firewall_rule_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_firewall_rule_remove()
{
    last_command="civo_firewall_rule_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_firewall_rule()
{
    last_command="civo_firewall_rule"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_firewall_update()
{
    last_command="civo_firewall_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_firewall()
{
    last_command="civo_firewall"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("rule")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rules")
        aliashash["rules"]="rule"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("change")
        aliashash["change"]="update"
        command_aliases+=("rename")
        aliashash["rename"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_console()
{
    last_command="civo_instance_console"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_create()
{
    last_command="civo_instance_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--hostname=")
    two_word_flags+=("--hostname")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--hostname=")
    flags+=("--initialuser=")
    two_word_flags+=("--initialuser")
    two_word_flags+=("-u")
    local_nonpersistent_flags+=("--initialuser=")
    flags+=("--network=")
    two_word_flags+=("--network")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--network=")
    flags+=("--publicip=")
    two_word_flags+=("--publicip")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--publicip=")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--region=")
    flags+=("--size=")
    two_word_flags+=("--size")
    two_word_flags+=("-i")
    local_nonpersistent_flags+=("--size=")
    flags+=("--snapshot=")
    two_word_flags+=("--snapshot")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--snapshot=")
    flags+=("--sshkey=")
    two_word_flags+=("--sshkey")
    two_word_flags+=("-k")
    local_nonpersistent_flags+=("--sshkey=")
    flags+=("--tags=")
    two_word_flags+=("--tags")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--tags=")
    flags+=("--template=")
    two_word_flags+=("--template")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--template=")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_firewall()
{
    last_command="civo_instance_firewall"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_ls()
{
    last_command="civo_instance_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_move-ip()
{
    last_command="civo_instance_move-ip"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_password()
{
    last_command="civo_instance_password"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_public-ip()
{
    last_command="civo_instance_public-ip"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_reboot()
{
    last_command="civo_instance_reboot"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_remove()
{
    last_command="civo_instance_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_show()
{
    last_command="civo_instance_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_soft-reboot()
{
    last_command="civo_instance_soft-reboot"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_start()
{
    last_command="civo_instance_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_stop()
{
    last_command="civo_instance_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_tag()
{
    last_command="civo_instance_tag"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_update()
{
    last_command="civo_instance_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--hostname=")
    two_word_flags+=("--hostname")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--hostname=")
    flags+=("--notes=")
    two_word_flags+=("--notes")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--notes=")
    flags+=("--reverse-dns=")
    two_word_flags+=("--reverse-dns")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reverse-dns=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance_upgrade()
{
    last_command="civo_instance_upgrade"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_instance()
{
    last_command="civo_instance"

    command_aliases=()

    commands=()
    commands+=("console")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("shell")
        aliashash["shell"]="console"
        command_aliases+=("terminal")
        aliashash["terminal"]="console"
    fi
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("firewall")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("change-firewall")
        aliashash["change-firewall"]="firewall"
        command_aliases+=("fw")
        aliashash["fw"]="firewall"
        command_aliases+=("set-firewall")
        aliashash["set-firewall"]="firewall"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("move-ip")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("moveip")
        aliashash["moveip"]="move-ip"
        command_aliases+=("switch-ip")
        aliashash["switch-ip"]="move-ip"
        command_aliases+=("switchip")
        aliashash["switchip"]="move-ip"
    fi
    commands+=("password")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("pw")
        aliashash["pw"]="password"
    fi
    commands+=("public-ip")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ip")
        aliashash["ip"]="public-ip"
        command_aliases+=("publicip")
        aliashash["publicip"]="public-ip"
    fi
    commands+=("reboot")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("hard-reboot")
        aliashash["hard-reboot"]="reboot"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("show")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("get")
        aliashash["get"]="show"
        command_aliases+=("inspect")
        aliashash["inspect"]="show"
    fi
    commands+=("soft-reboot")
    commands+=("start")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("boot")
        aliashash["boot"]="start"
        command_aliases+=("run")
        aliashash["run"]="start"
    fi
    commands+=("stop")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("shutdown")
        aliashash["shutdown"]="stop"
    fi
    commands+=("tag")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("tags")
        aliashash["tags"]="tag"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("set")
        aliashash["set"]="update"
    fi
    commands+=("upgrade")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("resize")
        aliashash["resize"]="upgrade"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_applications_add()
{
    last_command="civo_kubernetes_applications_add"

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
    local_nonpersistent_flags+=("--cluster=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_applications_ls()
{
    last_command="civo_kubernetes_applications_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_applications()
{
    last_command="civo_kubernetes_applications"

    command_aliases=()

    commands=()
    commands+=("add")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("install")
        aliashash["install"]="add"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_config()
{
    last_command="civo_kubernetes_config"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--local-path=")
    two_word_flags+=("--local-path")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--local-path=")
    flags+=("--merge")
    flags+=("-m")
    local_nonpersistent_flags+=("--merge")
    flags+=("--save")
    flags+=("-s")
    local_nonpersistent_flags+=("--save")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_create()
{
    last_command="civo_kubernetes_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--nodes=")
    two_word_flags+=("--nodes")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--nodes=")
    flags+=("--size=")
    two_word_flags+=("--size")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--size=")
    flags+=("--version=")
    two_word_flags+=("--version")
    two_word_flags+=("-v")
    local_nonpersistent_flags+=("--version=")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_ls()
{
    last_command="civo_kubernetes_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_remove()
{
    last_command="civo_kubernetes_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_rename()
{
    last_command="civo_kubernetes_rename"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_scale()
{
    last_command="civo_kubernetes_scale"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--nodes=")
    two_word_flags+=("--nodes")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--nodes=")
    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_show()
{
    last_command="civo_kubernetes_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_upgrade()
{
    last_command="civo_kubernetes_upgrade"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--version=")
    two_word_flags+=("--version")
    two_word_flags+=("-v")
    local_nonpersistent_flags+=("--version=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_flag+=("--version=")
    must_have_one_flag+=("-v")
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes_versions()
{
    last_command="civo_kubernetes_versions"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_kubernetes()
{
    last_command="civo_kubernetes"

    command_aliases=()

    commands=()
    commands+=("applications")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("addon")
        aliashash["addon"]="applications"
        command_aliases+=("addons")
        aliashash["addons"]="applications"
        command_aliases+=("app")
        aliashash["app"]="applications"
        command_aliases+=("app")
        aliashash["app"]="applications"
        command_aliases+=("application")
        aliashash["application"]="applications"
        command_aliases+=("application")
        aliashash["application"]="applications"
        command_aliases+=("apps")
        aliashash["apps"]="applications"
        command_aliases+=("k3s-app")
        aliashash["k3s-app"]="applications"
        command_aliases+=("k3s-apps")
        aliashash["k3s-apps"]="applications"
        command_aliases+=("k8s-app")
        aliashash["k8s-app"]="applications"
        command_aliases+=("k8s-apps")
        aliashash["k8s-apps"]="applications"
        command_aliases+=("marketplace")
        aliashash["marketplace"]="applications"
    fi
    commands+=("config")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("conf")
        aliashash["conf"]="config"
    fi
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("rename")
    commands+=("scale")
    commands+=("show")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("get")
        aliashash["get"]="show"
        command_aliases+=("inspect")
        aliashash["inspect"]="show"
    fi
    commands+=("upgrade")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("change")
        aliashash["change"]="upgrade"
        command_aliases+=("modify")
        aliashash["modify"]="upgrade"
    fi
    commands+=("versions")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("version")
        aliashash["version"]="versions"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_loadbalancer_create()
{
    last_command="civo_loadbalancer_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--backends=")
    two_word_flags+=("--backends")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--backends=")
    flags+=("--fail_timeout=")
    two_word_flags+=("--fail_timeout")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--fail_timeout=")
    flags+=("--health_check_path=")
    two_word_flags+=("--health_check_path")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--health_check_path=")
    flags+=("--hostname=")
    two_word_flags+=("--hostname")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--hostname=")
    flags+=("--ignore_invalid_backend_tls")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore_invalid_backend_tls")
    flags+=("--max_connections=")
    two_word_flags+=("--max_connections")
    two_word_flags+=("-x")
    local_nonpersistent_flags+=("--max_connections=")
    flags+=("--max_request_size=")
    two_word_flags+=("--max_request_size")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--max_request_size=")
    flags+=("--policy=")
    two_word_flags+=("--policy")
    local_nonpersistent_flags+=("--policy=")
    flags+=("--port=")
    two_word_flags+=("--port")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--port=")
    flags+=("--protocol=")
    two_word_flags+=("--protocol")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--protocol=")
    flags+=("--tls_certificate=")
    two_word_flags+=("--tls_certificate")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--tls_certificate=")
    flags+=("--tls_key=")
    two_word_flags+=("--tls_key")
    two_word_flags+=("-k")
    local_nonpersistent_flags+=("--tls_key=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_loadbalancer_ls()
{
    last_command="civo_loadbalancer_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_loadbalancer_remove()
{
    last_command="civo_loadbalancer_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_loadbalancer_update()
{
    last_command="civo_loadbalancer_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--backends=")
    two_word_flags+=("--backends")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--backends=")
    flags+=("--fail_timeout=")
    two_word_flags+=("--fail_timeout")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--fail_timeout=")
    flags+=("--health_check_path=")
    two_word_flags+=("--health_check_path")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--health_check_path=")
    flags+=("--hostname=")
    two_word_flags+=("--hostname")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--hostname=")
    flags+=("--ignore_invalid_backend_tls")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore_invalid_backend_tls")
    flags+=("--max_connections=")
    two_word_flags+=("--max_connections")
    two_word_flags+=("-x")
    local_nonpersistent_flags+=("--max_connections=")
    flags+=("--max_request_size=")
    two_word_flags+=("--max_request_size")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--max_request_size=")
    flags+=("--policy=")
    two_word_flags+=("--policy")
    local_nonpersistent_flags+=("--policy=")
    flags+=("--port=")
    two_word_flags+=("--port")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--port=")
    flags+=("--protocol=")
    two_word_flags+=("--protocol")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--protocol=")
    flags+=("--tls_certificate=")
    two_word_flags+=("--tls_certificate")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--tls_certificate=")
    flags+=("--tls_key=")
    two_word_flags+=("--tls_key")
    two_word_flags+=("-k")
    local_nonpersistent_flags+=("--tls_key=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_loadbalancer()
{
    last_command="civo_loadbalancer"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("change")
        aliashash["change"]="update"
        command_aliases+=("modify")
        aliashash["modify"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_network_create()
{
    last_command="civo_network_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_network_ls()
{
    last_command="civo_network_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_network_remove()
{
    last_command="civo_network_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_network_update()
{
    last_command="civo_network_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_network()
{
    last_command="civo_network"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("change")
        aliashash["change"]="update"
        command_aliases+=("modify")
        aliashash["modify"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_quota_show()
{
    last_command="civo_quota_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_quota()
{
    last_command="civo_quota"

    command_aliases=()

    commands=()
    commands+=("show")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("get")
        aliashash["get"]="show"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_region_ls()
{
    last_command="civo_region_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_region()
{
    last_command="civo_region"

    command_aliases=()

    commands=()
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_size_ls()
{
    last_command="civo_size_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_size()
{
    last_command="civo_size"

    command_aliases=()

    commands=()
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_snapshot_create()
{
    last_command="civo_snapshot_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cron=")
    two_word_flags+=("--cron")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--cron=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_snapshot_ls()
{
    last_command="civo_snapshot_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_snapshot_remove()
{
    last_command="civo_snapshot_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_snapshot()
{
    last_command="civo_snapshot"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_sshkey_create()
{
    last_command="civo_sshkey_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--key=")
    two_word_flags+=("--key")
    two_word_flags+=("-k")
    local_nonpersistent_flags+=("--key=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_flag+=("--key=")
    must_have_one_flag+=("-k")
    must_have_one_noun=()
    noun_aliases=()
}

_civo_sshkey_ls()
{
    last_command="civo_sshkey_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_sshkey_remove()
{
    last_command="civo_sshkey_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_sshkey()
{
    last_command="civo_sshkey"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_template_create()
{
    last_command="civo_template_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cloudconfig=")
    two_word_flags+=("--cloudconfig")
    two_word_flags+=("-i")
    local_nonpersistent_flags+=("--cloudconfig=")
    flags+=("--code=")
    two_word_flags+=("--code")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--code=")
    flags+=("--default-username=")
    two_word_flags+=("--default-username")
    two_word_flags+=("-u")
    local_nonpersistent_flags+=("--default-username=")
    flags+=("--description=")
    two_word_flags+=("--description")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--description=")
    flags+=("--image-id=")
    two_word_flags+=("--image-id")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--image-id=")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--short-description=")
    two_word_flags+=("--short-description")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--short-description=")
    flags+=("--volume-id=")
    two_word_flags+=("--volume-id")
    two_word_flags+=("-v")
    local_nonpersistent_flags+=("--volume-id=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_flag+=("--code=")
    must_have_one_flag+=("-c")
    must_have_one_noun=()
    noun_aliases=()
}

_civo_template_ls()
{
    last_command="civo_template_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_template_remove()
{
    last_command="civo_template_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_template_show()
{
    last_command="civo_template_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_template_update()
{
    last_command="civo_template_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cloudconfig=")
    two_word_flags+=("--cloudconfig")
    two_word_flags+=("-i")
    local_nonpersistent_flags+=("--cloudconfig=")
    flags+=("--default-username=")
    two_word_flags+=("--default-username")
    two_word_flags+=("-u")
    local_nonpersistent_flags+=("--default-username=")
    flags+=("--description=")
    two_word_flags+=("--description")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--description=")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--short-description=")
    two_word_flags+=("--short-description")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--short-description=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_template()
{
    last_command="civo_template"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("show")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("get")
        aliashash["get"]="show"
        command_aliases+=("inspect")
        aliashash["inspect"]="show"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("change")
        aliashash["change"]="update"
        command_aliases+=("modify")
        aliashash["modify"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_version()
{
    last_command="civo_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--quiet")
    flags+=("-q")
    local_nonpersistent_flags+=("--quiet")
    flags+=("--verbose")
    flags+=("-v")
    local_nonpersistent_flags+=("--verbose")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_volume_attach()
{
    last_command="civo_volume_attach"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_volume_create()
{
    last_command="civo_volume_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--bootable")
    flags+=("-b")
    local_nonpersistent_flags+=("--bootable")
    flags+=("--size-gb=")
    two_word_flags+=("--size-gb")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--size-gb=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_flag+=("--size-gb=")
    must_have_one_flag+=("-s")
    must_have_one_noun=()
    noun_aliases=()
}

_civo_volume_detach()
{
    last_command="civo_volume_detach"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--wait")
    flags+=("-w")
    local_nonpersistent_flags+=("--wait")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_volume_ls()
{
    last_command="civo_volume_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_volume_remove()
{
    last_command="civo_volume_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_volume_resize()
{
    last_command="civo_volume_resize"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--size-gb=")
    two_word_flags+=("--size-gb")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--size-gb=")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_flag+=("--size-gb=")
    must_have_one_flag+=("-s")
    must_have_one_noun=()
    noun_aliases=()
}

_civo_volume()
{
    last_command="civo_volume"

    command_aliases=()

    commands=()
    commands+=("attach")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("connect")
        aliashash["connect"]="attach"
        command_aliases+=("link")
        aliashash["link"]="attach"
    fi
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("detach")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("disconnect")
        aliashash["disconnect"]="detach"
        command_aliases+=("unlink")
        aliashash["unlink"]="detach"
    fi
    commands+=("ls")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("all")
        aliashash["all"]="ls"
        command_aliases+=("list")
        aliashash["list"]="ls"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
        command_aliases+=("destroy")
        aliashash["destroy"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("resize")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_civo_root_command()
{
    last_command="civo"

    command_aliases=()

    commands=()
    commands+=("apikey")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("apikeys")
        aliashash["apikeys"]="apikey"
    fi
    commands+=("completion")
    commands+=("domain")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("domains")
        aliashash["domains"]="domain"
    fi
    commands+=("firewall")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("firewalls")
        aliashash["firewalls"]="firewall"
        command_aliases+=("fw")
        aliashash["fw"]="firewall"
    fi
    commands+=("instance")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("instances")
        aliashash["instances"]="instance"
    fi
    commands+=("kubernetes")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("k3s")
        aliashash["k3s"]="kubernetes"
        command_aliases+=("k8s")
        aliashash["k8s"]="kubernetes"
        command_aliases+=("kube")
        aliashash["kube"]="kubernetes"
    fi
    commands+=("loadbalancer")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("lb")
        aliashash["lb"]="loadbalancer"
        command_aliases+=("loadbalancers")
        aliashash["loadbalancers"]="loadbalancer"
    fi
    commands+=("network")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("net")
        aliashash["net"]="network"
        command_aliases+=("networks")
        aliashash["networks"]="network"
    fi
    commands+=("quota")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("quotas")
        aliashash["quotas"]="quota"
    fi
    commands+=("region")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("regions")
        aliashash["regions"]="region"
    fi
    commands+=("size")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("sizes")
        aliashash["sizes"]="size"
    fi
    commands+=("snapshot")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("snapshots")
        aliashash["snapshots"]="snapshot"
    fi
    commands+=("sshkey")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ssh")
        aliashash["ssh"]="sshkey"
        command_aliases+=("ssh-key")
        aliashash["ssh-key"]="sshkey"
        command_aliases+=("sshkeys")
        aliashash["sshkeys"]="sshkey"
    fi
    commands+=("template")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("templates")
        aliashash["templates"]="template"
    fi
    commands+=("version")
    commands+=("volume")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("volumes")
        aliashash["volumes"]="volume"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_civo()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __civo_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("civo")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function
    local last_command
    local nouns=()

    __civo_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_civo civo
else
    complete -o default -o nospace -F __start_civo civo
fi

# ex: ts=4 sw=4 et filetype=sh
