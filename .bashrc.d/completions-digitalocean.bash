# Copyright 2018 The Doctl Authors All rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# bash completion for doctl                                -*- shell-script -*-

__doctl_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__doctl_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__doctl_index_of_word()
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

__doctl_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__doctl_handle_reply()
{
    __doctl_debug "${FUNCNAME[0]}"
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
                __doctl_index_of_word "${flag}" "${flags_with_completion[@]}"
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
    __doctl_index_of_word "${prev}" "${flags_with_completion[@]}"
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
        declare -F __custom_func >/dev/null && __custom_func
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
__doctl_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__doctl_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1
}

__doctl_handle_flag()
{
    __doctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __doctl_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __doctl_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __doctl_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
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
    if __doctl_contains_word "${words[c]}" "${two_word_flags[@]}"; then
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__doctl_handle_noun()
{
    __doctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __doctl_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __doctl_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__doctl_handle_command()
{
    __doctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_doctl_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __doctl_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__doctl_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __doctl_handle_reply
        return
    fi
    __doctl_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __doctl_handle_flag
    elif __doctl_contains_word "${words[c]}" "${commands[@]}"; then
        __doctl_handle_command
    elif [[ $c -eq 0 ]]; then
        __doctl_handle_command
    elif __doctl_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __doctl_handle_command
        else
            __doctl_handle_noun
        fi
    else
        __doctl_handle_noun
    fi
    __doctl_handle_word
}

_doctl_account_get()
{
    last_command="doctl_account_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_account_ratelimit()
{
    last_command="doctl_account_ratelimit"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_account()
{
    last_command="doctl_account"

    command_aliases=()

    commands=()
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("ratelimit")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rl")
        aliashash["rl"]="ratelimit"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_auth_init()
{
    last_command="doctl_auth_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_auth_list()
{
    last_command="doctl_auth_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_auth_switch()
{
    last_command="doctl_auth_switch"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_auth()
{
    last_command="doctl_auth"

    command_aliases=()

    commands=()
    commands+=("init")
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("switch")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_balance_get()
{
    last_command="doctl_balance_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_balance()
{
    last_command="doctl_balance"

    command_aliases=()

    commands=()
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_completion_bash()
{
    last_command="doctl_completion_bash"

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
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_completion_zsh()
{
    last_command="doctl_completion_zsh"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_completion()
{
    last_command="doctl_completion"

    command_aliases=()

    commands=()
    commands+=("bash")
    commands+=("zsh")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_action_get()
{
    last_command="doctl_compute_action_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_action_list()
{
    last_command="doctl_compute_action_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--action-type=")
    local_nonpersistent_flags+=("--action-type=")
    flags+=("--after=")
    local_nonpersistent_flags+=("--after=")
    flags+=("--before=")
    local_nonpersistent_flags+=("--before=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--resource-type=")
    local_nonpersistent_flags+=("--resource-type=")
    flags+=("--status=")
    local_nonpersistent_flags+=("--status=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_action_wait()
{
    last_command="doctl_compute_action_wait"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--poll-timeout=")
    local_nonpersistent_flags+=("--poll-timeout=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_action()
{
    last_command="doctl_compute_action"

    command_aliases=()

    commands=()
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("wait")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("w")
        aliashash["w"]="wait"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_cdn_create()
{
    last_command="doctl_compute_cdn_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--certificate-id=")
    local_nonpersistent_flags+=("--certificate-id=")
    flags+=("--domain=")
    local_nonpersistent_flags+=("--domain=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--ttl=")
    local_nonpersistent_flags+=("--ttl=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_cdn_delete()
{
    last_command="doctl_compute_cdn_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_cdn_flush()
{
    last_command="doctl_compute_cdn_flush"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--files=")
    local_nonpersistent_flags+=("--files=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_cdn_get()
{
    last_command="doctl_compute_cdn_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_cdn_list()
{
    last_command="doctl_compute_cdn_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_cdn_update()
{
    last_command="doctl_compute_cdn_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--certificate-id=")
    local_nonpersistent_flags+=("--certificate-id=")
    flags+=("--domain=")
    local_nonpersistent_flags+=("--domain=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--ttl=")
    local_nonpersistent_flags+=("--ttl=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_cdn()
{
    last_command="doctl_compute_cdn"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("flush")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("fc")
        aliashash["fc"]="flush"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_certificate_create()
{
    last_command="doctl_compute_certificate_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--certificate-chain-path=")
    local_nonpersistent_flags+=("--certificate-chain-path=")
    flags+=("--dns-names=")
    local_nonpersistent_flags+=("--dns-names=")
    flags+=("--leaf-certificate-path=")
    local_nonpersistent_flags+=("--leaf-certificate-path=")
    flags+=("--name=")
    local_nonpersistent_flags+=("--name=")
    flags+=("--private-key-path=")
    local_nonpersistent_flags+=("--private-key-path=")
    flags+=("--type=")
    local_nonpersistent_flags+=("--type=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_certificate_delete()
{
    last_command="doctl_compute_certificate_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_certificate_get()
{
    last_command="doctl_compute_certificate_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_certificate_list()
{
    last_command="doctl_compute_certificate_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_certificate()
{
    last_command="doctl_compute_certificate"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_domain_create()
{
    last_command="doctl_compute_domain_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--ip-address=")
    local_nonpersistent_flags+=("--ip-address=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_domain_delete()
{
    last_command="doctl_compute_domain_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_domain_get()
{
    last_command="doctl_compute_domain_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_domain_list()
{
    last_command="doctl_compute_domain_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_domain_records_create()
{
    last_command="doctl_compute_domain_records_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--record-data=")
    local_nonpersistent_flags+=("--record-data=")
    flags+=("--record-flags=")
    local_nonpersistent_flags+=("--record-flags=")
    flags+=("--record-name=")
    local_nonpersistent_flags+=("--record-name=")
    flags+=("--record-port=")
    local_nonpersistent_flags+=("--record-port=")
    flags+=("--record-priority=")
    local_nonpersistent_flags+=("--record-priority=")
    flags+=("--record-tag=")
    local_nonpersistent_flags+=("--record-tag=")
    flags+=("--record-ttl=")
    local_nonpersistent_flags+=("--record-ttl=")
    flags+=("--record-type=")
    local_nonpersistent_flags+=("--record-type=")
    flags+=("--record-weight=")
    local_nonpersistent_flags+=("--record-weight=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_domain_records_delete()
{
    last_command="doctl_compute_domain_records_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_domain_records_list()
{
    last_command="doctl_compute_domain_records_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_domain_records_update()
{
    last_command="doctl_compute_domain_records_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--record-data=")
    local_nonpersistent_flags+=("--record-data=")
    flags+=("--record-flags=")
    local_nonpersistent_flags+=("--record-flags=")
    flags+=("--record-id=")
    local_nonpersistent_flags+=("--record-id=")
    flags+=("--record-name=")
    local_nonpersistent_flags+=("--record-name=")
    flags+=("--record-port=")
    local_nonpersistent_flags+=("--record-port=")
    flags+=("--record-priority=")
    local_nonpersistent_flags+=("--record-priority=")
    flags+=("--record-tag=")
    local_nonpersistent_flags+=("--record-tag=")
    flags+=("--record-ttl=")
    local_nonpersistent_flags+=("--record-ttl=")
    flags+=("--record-type=")
    local_nonpersistent_flags+=("--record-type=")
    flags+=("--record-weight=")
    local_nonpersistent_flags+=("--record-weight=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_domain_records()
{
    last_command="doctl_compute_domain_records"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_domain()
{
    last_command="doctl_compute_domain"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("records")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_actions()
{
    last_command="doctl_compute_droplet_actions"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_backups()
{
    last_command="doctl_compute_droplet_backups"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_create()
{
    last_command="doctl_compute_droplet_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--enable-backups")
    local_nonpersistent_flags+=("--enable-backups")
    flags+=("--enable-ipv6")
    local_nonpersistent_flags+=("--enable-ipv6")
    flags+=("--enable-monitoring")
    local_nonpersistent_flags+=("--enable-monitoring")
    flags+=("--enable-private-networking")
    local_nonpersistent_flags+=("--enable-private-networking")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--image=")
    local_nonpersistent_flags+=("--image=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--size=")
    local_nonpersistent_flags+=("--size=")
    flags+=("--ssh-keys=")
    local_nonpersistent_flags+=("--ssh-keys=")
    flags+=("--tag-name=")
    local_nonpersistent_flags+=("--tag-name=")
    flags+=("--tag-names=")
    local_nonpersistent_flags+=("--tag-names=")
    flags+=("--user-data=")
    local_nonpersistent_flags+=("--user-data=")
    flags+=("--user-data-file=")
    local_nonpersistent_flags+=("--user-data-file=")
    flags+=("--volumes=")
    local_nonpersistent_flags+=("--volumes=")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_delete()
{
    last_command="doctl_compute_droplet_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--tag-name=")
    local_nonpersistent_flags+=("--tag-name=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_get()
{
    last_command="doctl_compute_droplet_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--template=")
    local_nonpersistent_flags+=("--template=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_kernels()
{
    last_command="doctl_compute_droplet_kernels"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_list()
{
    last_command="doctl_compute_droplet_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--tag-name=")
    local_nonpersistent_flags+=("--tag-name=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_neighbors()
{
    last_command="doctl_compute_droplet_neighbors"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_snapshots()
{
    last_command="doctl_compute_droplet_snapshots"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_tag()
{
    last_command="doctl_compute_droplet_tag"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--tag-name=")
    local_nonpersistent_flags+=("--tag-name=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet_untag()
{
    last_command="doctl_compute_droplet_untag"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--tag-name=")
    local_nonpersistent_flags+=("--tag-name=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet()
{
    last_command="doctl_compute_droplet"

    command_aliases=()

    commands=()
    commands+=("actions")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("a")
        aliashash["a"]="actions"
    fi
    commands+=("backups")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("b")
        aliashash["b"]="backups"
    fi
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
        command_aliases+=("del")
        aliashash["del"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("kernels")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("k")
        aliashash["k"]="kernels"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("neighbors")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("n")
        aliashash["n"]="neighbors"
    fi
    commands+=("snapshots")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="snapshots"
    fi
    commands+=("tag")
    commands+=("untag")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_change-kernel()
{
    last_command="doctl_compute_droplet-action_change-kernel"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--kernel-id=")
    local_nonpersistent_flags+=("--kernel-id=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_disable-backups()
{
    last_command="doctl_compute_droplet-action_disable-backups"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_enable-backups()
{
    last_command="doctl_compute_droplet-action_enable-backups"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_enable-ipv6()
{
    last_command="doctl_compute_droplet-action_enable-ipv6"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_enable-private-networking()
{
    last_command="doctl_compute_droplet-action_enable-private-networking"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_get()
{
    last_command="doctl_compute_droplet-action_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--action-id=")
    local_nonpersistent_flags+=("--action-id=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_password-reset()
{
    last_command="doctl_compute_droplet-action_password-reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_power-cycle()
{
    last_command="doctl_compute_droplet-action_power-cycle"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_power-off()
{
    last_command="doctl_compute_droplet-action_power-off"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_power-on()
{
    last_command="doctl_compute_droplet-action_power-on"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_reboot()
{
    last_command="doctl_compute_droplet-action_reboot"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_rebuild()
{
    last_command="doctl_compute_droplet-action_rebuild"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--image=")
    local_nonpersistent_flags+=("--image=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_rename()
{
    last_command="doctl_compute_droplet-action_rename"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--droplet-name=")
    local_nonpersistent_flags+=("--droplet-name=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_resize()
{
    last_command="doctl_compute_droplet-action_resize"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--resize-disk")
    local_nonpersistent_flags+=("--resize-disk")
    flags+=("--size=")
    local_nonpersistent_flags+=("--size=")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_restore()
{
    last_command="doctl_compute_droplet-action_restore"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--image-id=")
    local_nonpersistent_flags+=("--image-id=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_shutdown()
{
    last_command="doctl_compute_droplet-action_shutdown"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action_snapshot()
{
    last_command="doctl_compute_droplet-action_snapshot"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--snapshot-name=")
    local_nonpersistent_flags+=("--snapshot-name=")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_droplet-action()
{
    last_command="doctl_compute_droplet-action"

    command_aliases=()

    commands=()
    commands+=("change-kernel")
    commands+=("disable-backups")
    commands+=("enable-backups")
    commands+=("enable-ipv6")
    commands+=("enable-private-networking")
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("password-reset")
    commands+=("power-cycle")
    commands+=("power-off")
    commands+=("power-on")
    commands+=("reboot")
    commands+=("rebuild")
    commands+=("rename")
    commands+=("resize")
    commands+=("restore")
    commands+=("shutdown")
    commands+=("snapshot")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_add-droplets()
{
    last_command="doctl_compute_firewall_add-droplets"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--droplet-ids=")
    local_nonpersistent_flags+=("--droplet-ids=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_add-rules()
{
    last_command="doctl_compute_firewall_add-rules"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--inbound-rules=")
    local_nonpersistent_flags+=("--inbound-rules=")
    flags+=("--outbound-rules=")
    local_nonpersistent_flags+=("--outbound-rules=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_add-tags()
{
    last_command="doctl_compute_firewall_add-tags"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--tag-names=")
    local_nonpersistent_flags+=("--tag-names=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_create()
{
    last_command="doctl_compute_firewall_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--droplet-ids=")
    local_nonpersistent_flags+=("--droplet-ids=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--inbound-rules=")
    local_nonpersistent_flags+=("--inbound-rules=")
    flags+=("--name=")
    local_nonpersistent_flags+=("--name=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--outbound-rules=")
    local_nonpersistent_flags+=("--outbound-rules=")
    flags+=("--tag-names=")
    local_nonpersistent_flags+=("--tag-names=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_delete()
{
    last_command="doctl_compute_firewall_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_get()
{
    last_command="doctl_compute_firewall_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_list()
{
    last_command="doctl_compute_firewall_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_list-by-droplet()
{
    last_command="doctl_compute_firewall_list-by-droplet"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_remove-droplets()
{
    last_command="doctl_compute_firewall_remove-droplets"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--droplet-ids=")
    local_nonpersistent_flags+=("--droplet-ids=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_remove-rules()
{
    last_command="doctl_compute_firewall_remove-rules"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--inbound-rules=")
    local_nonpersistent_flags+=("--inbound-rules=")
    flags+=("--outbound-rules=")
    local_nonpersistent_flags+=("--outbound-rules=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_remove-tags()
{
    last_command="doctl_compute_firewall_remove-tags"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--tag-names=")
    local_nonpersistent_flags+=("--tag-names=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall_update()
{
    last_command="doctl_compute_firewall_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--droplet-ids=")
    local_nonpersistent_flags+=("--droplet-ids=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--inbound-rules=")
    local_nonpersistent_flags+=("--inbound-rules=")
    flags+=("--name=")
    local_nonpersistent_flags+=("--name=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--outbound-rules=")
    local_nonpersistent_flags+=("--outbound-rules=")
    flags+=("--tag-names=")
    local_nonpersistent_flags+=("--tag-names=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_firewall()
{
    last_command="doctl_compute_firewall"

    command_aliases=()

    commands=()
    commands+=("add-droplets")
    commands+=("add-rules")
    commands+=("add-tags")
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("list-by-droplet")
    commands+=("remove-droplets")
    commands+=("remove-rules")
    commands+=("remove-tags")
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_floating-ip_create()
{
    last_command="doctl_compute_floating-ip_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--droplet-id=")
    local_nonpersistent_flags+=("--droplet-id=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_floating-ip_delete()
{
    last_command="doctl_compute_floating-ip_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_floating-ip_get()
{
    last_command="doctl_compute_floating-ip_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_floating-ip_list()
{
    last_command="doctl_compute_floating-ip_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_floating-ip()
{
    last_command="doctl_compute_floating-ip"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_floating-ip-action_assign()
{
    last_command="doctl_compute_floating-ip-action_assign"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_floating-ip-action_get()
{
    last_command="doctl_compute_floating-ip-action_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_floating-ip-action_unassign()
{
    last_command="doctl_compute_floating-ip-action_unassign"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_floating-ip-action()
{
    last_command="doctl_compute_floating-ip-action"

    command_aliases=()

    commands=()
    commands+=("assign")
    commands+=("get")
    commands+=("unassign")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image_create()
{
    last_command="doctl_compute_image_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--image-description=")
    local_nonpersistent_flags+=("--image-description=")
    flags+=("--image-distribution=")
    local_nonpersistent_flags+=("--image-distribution=")
    flags+=("--image-url=")
    local_nonpersistent_flags+=("--image-url=")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--tag-names=")
    local_nonpersistent_flags+=("--tag-names=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image_delete()
{
    last_command="doctl_compute_image_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image_get()
{
    last_command="doctl_compute_image_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image_list()
{
    last_command="doctl_compute_image_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--public")
    local_nonpersistent_flags+=("--public")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image_list-application()
{
    last_command="doctl_compute_image_list-application"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--public")
    local_nonpersistent_flags+=("--public")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image_list-distribution()
{
    last_command="doctl_compute_image_list-distribution"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--public")
    local_nonpersistent_flags+=("--public")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image_list-user()
{
    last_command="doctl_compute_image_list-user"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--public")
    local_nonpersistent_flags+=("--public")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image_update()
{
    last_command="doctl_compute_image_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--image-name=")
    local_nonpersistent_flags+=("--image-name=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image()
{
    last_command="doctl_compute_image"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("delete")
    commands+=("get")
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("list-application")
    commands+=("list-distribution")
    commands+=("list-user")
    commands+=("update")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image-action_get()
{
    last_command="doctl_compute_image-action_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--action-id=")
    local_nonpersistent_flags+=("--action-id=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image-action_transfer()
{
    last_command="doctl_compute_image-action_transfer"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_image-action()
{
    last_command="doctl_compute_image-action"

    command_aliases=()

    commands=()
    commands+=("get")
    commands+=("transfer")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_load-balancer_add-droplets()
{
    last_command="doctl_compute_load-balancer_add-droplets"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--droplet-ids=")
    local_nonpersistent_flags+=("--droplet-ids=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_load-balancer_add-forwarding-rules()
{
    last_command="doctl_compute_load-balancer_add-forwarding-rules"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--forwarding-rules=")
    local_nonpersistent_flags+=("--forwarding-rules=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_load-balancer_create()
{
    last_command="doctl_compute_load-balancer_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--algorithm=")
    local_nonpersistent_flags+=("--algorithm=")
    flags+=("--droplet-ids=")
    local_nonpersistent_flags+=("--droplet-ids=")
    flags+=("--forwarding-rules=")
    local_nonpersistent_flags+=("--forwarding-rules=")
    flags+=("--health-check=")
    local_nonpersistent_flags+=("--health-check=")
    flags+=("--name=")
    local_nonpersistent_flags+=("--name=")
    flags+=("--redirect-http-to-https")
    local_nonpersistent_flags+=("--redirect-http-to-https")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--sticky-sessions=")
    local_nonpersistent_flags+=("--sticky-sessions=")
    flags+=("--tag-name=")
    local_nonpersistent_flags+=("--tag-name=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_load-balancer_delete()
{
    last_command="doctl_compute_load-balancer_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_load-balancer_get()
{
    last_command="doctl_compute_load-balancer_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_load-balancer_list()
{
    last_command="doctl_compute_load-balancer_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_load-balancer_remove-droplets()
{
    last_command="doctl_compute_load-balancer_remove-droplets"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--droplet-ids=")
    local_nonpersistent_flags+=("--droplet-ids=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_load-balancer_remove-forwarding-rules()
{
    last_command="doctl_compute_load-balancer_remove-forwarding-rules"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--forwarding-rules=")
    local_nonpersistent_flags+=("--forwarding-rules=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_load-balancer_update()
{
    last_command="doctl_compute_load-balancer_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--algorithm=")
    local_nonpersistent_flags+=("--algorithm=")
    flags+=("--droplet-ids=")
    local_nonpersistent_flags+=("--droplet-ids=")
    flags+=("--forwarding-rules=")
    local_nonpersistent_flags+=("--forwarding-rules=")
    flags+=("--health-check=")
    local_nonpersistent_flags+=("--health-check=")
    flags+=("--name=")
    local_nonpersistent_flags+=("--name=")
    flags+=("--redirect-http-to-https")
    local_nonpersistent_flags+=("--redirect-http-to-https")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--sticky-sessions=")
    local_nonpersistent_flags+=("--sticky-sessions=")
    flags+=("--tag-name=")
    local_nonpersistent_flags+=("--tag-name=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_load-balancer()
{
    last_command="doctl_compute_load-balancer"

    command_aliases=()

    commands=()
    commands+=("add-droplets")
    commands+=("add-forwarding-rules")
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("remove-droplets")
    commands+=("remove-forwarding-rules")
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_region_list()
{
    last_command="doctl_compute_region_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_region()
{
    last_command="doctl_compute_region"

    command_aliases=()

    commands=()
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_size_list()
{
    last_command="doctl_compute_size_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_size()
{
    last_command="doctl_compute_size"

    command_aliases=()

    commands=()
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_snapshot_delete()
{
    last_command="doctl_compute_snapshot_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_snapshot_get()
{
    last_command="doctl_compute_snapshot_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_snapshot_list()
{
    last_command="doctl_compute_snapshot_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--resource=")
    local_nonpersistent_flags+=("--resource=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_snapshot()
{
    last_command="doctl_compute_snapshot"

    command_aliases=()

    commands=()
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_ssh()
{
    last_command="doctl_compute_ssh"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--ssh-agent-forwarding")
    local_nonpersistent_flags+=("--ssh-agent-forwarding")
    flags+=("--ssh-command=")
    local_nonpersistent_flags+=("--ssh-command=")
    flags+=("--ssh-key-path=")
    local_nonpersistent_flags+=("--ssh-key-path=")
    flags+=("--ssh-port=")
    local_nonpersistent_flags+=("--ssh-port=")
    flags+=("--ssh-private-ip")
    local_nonpersistent_flags+=("--ssh-private-ip")
    flags+=("--ssh-user=")
    local_nonpersistent_flags+=("--ssh-user=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_ssh-key_create()
{
    last_command="doctl_compute_ssh-key_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--public-key=")
    local_nonpersistent_flags+=("--public-key=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_ssh-key_delete()
{
    last_command="doctl_compute_ssh-key_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_ssh-key_get()
{
    last_command="doctl_compute_ssh-key_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_ssh-key_import()
{
    last_command="doctl_compute_ssh-key_import"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--public-key-file=")
    local_nonpersistent_flags+=("--public-key-file=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_ssh-key_list()
{
    last_command="doctl_compute_ssh-key_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_ssh-key_update()
{
    last_command="doctl_compute_ssh-key_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--key-name=")
    local_nonpersistent_flags+=("--key-name=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_ssh-key()
{
    last_command="doctl_compute_ssh-key"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("import")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("i")
        aliashash["i"]="import"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_tag_create()
{
    last_command="doctl_compute_tag_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_tag_delete()
{
    last_command="doctl_compute_tag_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_tag_get()
{
    last_command="doctl_compute_tag_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_tag_list()
{
    last_command="doctl_compute_tag_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_tag()
{
    last_command="doctl_compute_tag"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("delete")
    commands+=("get")
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume_create()
{
    last_command="doctl_compute_volume_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--desc=")
    local_nonpersistent_flags+=("--desc=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--fs-label=")
    local_nonpersistent_flags+=("--fs-label=")
    flags+=("--fs-type=")
    local_nonpersistent_flags+=("--fs-type=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--size=")
    local_nonpersistent_flags+=("--size=")
    flags+=("--snapshot=")
    local_nonpersistent_flags+=("--snapshot=")
    flags+=("--tag=")
    local_nonpersistent_flags+=("--tag=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume_delete()
{
    last_command="doctl_compute_volume_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume_get()
{
    last_command="doctl_compute_volume_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume_list()
{
    last_command="doctl_compute_volume_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume_snapshot()
{
    last_command="doctl_compute_volume_snapshot"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--snapshot-desc=")
    local_nonpersistent_flags+=("--snapshot-desc=")
    flags+=("--snapshot-name=")
    local_nonpersistent_flags+=("--snapshot-name=")
    flags+=("--tag=")
    local_nonpersistent_flags+=("--tag=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume()
{
    last_command="doctl_compute_volume"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("snapshot")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="snapshot"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume-action_attach()
{
    last_command="doctl_compute_volume-action_attach"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume-action_detach()
{
    last_command="doctl_compute_volume-action_detach"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume-action_detach-by-droplet-id()
{
    last_command="doctl_compute_volume-action_detach-by-droplet-id"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume-action_resize()
{
    last_command="doctl_compute_volume-action_resize"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--size=")
    local_nonpersistent_flags+=("--size=")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute_volume-action()
{
    last_command="doctl_compute_volume-action"

    command_aliases=()

    commands=()
    commands+=("attach")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("a")
        aliashash["a"]="attach"
    fi
    commands+=("detach")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="detach"
    fi
    commands+=("detach-by-droplet-id")
    commands+=("resize")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("r")
        aliashash["r"]="resize"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_compute()
{
    last_command="doctl_compute"

    command_aliases=()

    commands=()
    commands+=("action")
    commands+=("cdn")
    commands+=("certificate")
    commands+=("domain")
    commands+=("droplet")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="droplet"
    fi
    commands+=("droplet-action")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("da")
        aliashash["da"]="droplet-action"
    fi
    commands+=("firewall")
    commands+=("floating-ip")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("fip")
        aliashash["fip"]="floating-ip"
    fi
    commands+=("floating-ip-action")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("fipa")
        aliashash["fipa"]="floating-ip-action"
    fi
    commands+=("image")
    commands+=("image-action")
    commands+=("load-balancer")
    commands+=("region")
    commands+=("size")
    commands+=("snapshot")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="snapshot"
    fi
    commands+=("ssh")
    commands+=("ssh-key")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("k")
        aliashash["k"]="ssh-key"
    fi
    commands+=("tag")
    commands+=("volume")
    commands+=("volume-action")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_backups()
{
    last_command="doctl_databases_backups"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_connection()
{
    last_command="doctl_databases_connection"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_create()
{
    last_command="doctl_databases_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--engine=")
    local_nonpersistent_flags+=("--engine=")
    flags+=("--num-nodes=")
    local_nonpersistent_flags+=("--num-nodes=")
    flags+=("--private-network-uuid=")
    local_nonpersistent_flags+=("--private-network-uuid=")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--size=")
    local_nonpersistent_flags+=("--size=")
    flags+=("--version=")
    local_nonpersistent_flags+=("--version=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_db_create()
{
    last_command="doctl_databases_db_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_db_delete()
{
    last_command="doctl_databases_db_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_db_get()
{
    last_command="doctl_databases_db_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_db_list()
{
    last_command="doctl_databases_db_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_db()
{
    last_command="doctl_databases_db"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_delete()
{
    last_command="doctl_databases_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_get()
{
    last_command="doctl_databases_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_list()
{
    last_command="doctl_databases_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_maintenance-window_get()
{
    last_command="doctl_databases_maintenance-window_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_maintenance-window_update()
{
    last_command="doctl_databases_maintenance-window_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--day=")
    local_nonpersistent_flags+=("--day=")
    flags+=("--hour=")
    local_nonpersistent_flags+=("--hour=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_maintenance-window()
{
    last_command="doctl_databases_maintenance-window"

    command_aliases=()

    commands=()
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_migrate()
{
    last_command="doctl_databases_migrate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--private-network-uuid=")
    local_nonpersistent_flags+=("--private-network-uuid=")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_pool_create()
{
    last_command="doctl_databases_pool_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--db=")
    local_nonpersistent_flags+=("--db=")
    flags+=("--mode=")
    local_nonpersistent_flags+=("--mode=")
    flags+=("--size=")
    local_nonpersistent_flags+=("--size=")
    flags+=("--user=")
    local_nonpersistent_flags+=("--user=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_pool_delete()
{
    last_command="doctl_databases_pool_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_pool_get()
{
    last_command="doctl_databases_pool_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_pool_list()
{
    last_command="doctl_databases_pool_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_pool()
{
    last_command="doctl_databases_pool"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_replica_connection()
{
    last_command="doctl_databases_replica_connection"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_replica_create()
{
    last_command="doctl_databases_replica_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--private-network-uuid=")
    local_nonpersistent_flags+=("--private-network-uuid=")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--size=")
    local_nonpersistent_flags+=("--size=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_replica_delete()
{
    last_command="doctl_databases_replica_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_replica_get()
{
    last_command="doctl_databases_replica_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_replica_list()
{
    last_command="doctl_databases_replica_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_replica()
{
    last_command="doctl_databases_replica"

    command_aliases=()

    commands=()
    commands+=("connection")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("conn")
        aliashash["conn"]="connection"
    fi
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_resize()
{
    last_command="doctl_databases_resize"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--num-nodes=")
    local_nonpersistent_flags+=("--num-nodes=")
    flags+=("--size=")
    local_nonpersistent_flags+=("--size=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_sql-mode_get()
{
    last_command="doctl_databases_sql-mode_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_sql-mode_set()
{
    last_command="doctl_databases_sql-mode_set"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_sql-mode()
{
    last_command="doctl_databases_sql-mode"

    command_aliases=()

    commands=()
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("set")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="set"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_user_create()
{
    last_command="doctl_databases_user_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--mysql-auth-plugin=")
    local_nonpersistent_flags+=("--mysql-auth-plugin=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_user_delete()
{
    last_command="doctl_databases_user_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_user_get()
{
    last_command="doctl_databases_user_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_user_list()
{
    last_command="doctl_databases_user_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_user_reset()
{
    last_command="doctl_databases_user_reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases_user()
{
    last_command="doctl_databases_user"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("reset")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rs")
        aliashash["rs"]="reset"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_databases()
{
    last_command="doctl_databases"

    command_aliases=()

    commands=()
    commands+=("backups")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("bu")
        aliashash["bu"]="backups"
    fi
    commands+=("connection")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("conn")
        aliashash["conn"]="connection"
    fi
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("db")
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("maintenance-window")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("main")
        aliashash["main"]="maintenance-window"
        command_aliases+=("maintenance")
        aliashash["maintenance"]="maintenance-window"
        command_aliases+=("mw")
        aliashash["mw"]="maintenance-window"
    fi
    commands+=("migrate")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("m")
        aliashash["m"]="migrate"
    fi
    commands+=("pool")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("p")
        aliashash["p"]="pool"
    fi
    commands+=("replica")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("r")
        aliashash["r"]="replica"
        command_aliases+=("rep")
        aliashash["rep"]="replica"
    fi
    commands+=("resize")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rs")
        aliashash["rs"]="resize"
    fi
    commands+=("sql-mode")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("sm")
        aliashash["sm"]="sql-mode"
    fi
    commands+=("user")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="user"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_invoice_csv()
{
    last_command="doctl_invoice_csv"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_invoice_get()
{
    last_command="doctl_invoice_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_invoice_list()
{
    last_command="doctl_invoice_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_invoice_pdf()
{
    last_command="doctl_invoice_pdf"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_invoice_summary()
{
    last_command="doctl_invoice_summary"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_invoice()
{
    last_command="doctl_invoice"

    command_aliases=()

    commands=()
    commands+=("csv")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="csv"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("pdf")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("p")
        aliashash["p"]="pdf"
    fi
    commands+=("summary")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="summary"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_create()
{
    last_command="doctl_kubernetes_cluster_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auto-upgrade")
    local_nonpersistent_flags+=("--auto-upgrade")
    flags+=("--count=")
    local_nonpersistent_flags+=("--count=")
    flags+=("--maintenance-window=")
    local_nonpersistent_flags+=("--maintenance-window=")
    flags+=("--node-pool=")
    local_nonpersistent_flags+=("--node-pool=")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--set-current-context")
    local_nonpersistent_flags+=("--set-current-context")
    flags+=("--size=")
    local_nonpersistent_flags+=("--size=")
    flags+=("--tag=")
    local_nonpersistent_flags+=("--tag=")
    flags+=("--update-kubeconfig")
    local_nonpersistent_flags+=("--update-kubeconfig")
    flags+=("--version=")
    local_nonpersistent_flags+=("--version=")
    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_delete()
{
    last_command="doctl_kubernetes_cluster_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--update-kubeconfig")
    local_nonpersistent_flags+=("--update-kubeconfig")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_get()
{
    last_command="doctl_kubernetes_cluster_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_get-upgrades()
{
    last_command="doctl_kubernetes_cluster_get-upgrades"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_kubeconfig_remove()
{
    last_command="doctl_kubernetes_cluster_kubeconfig_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_kubeconfig_save()
{
    last_command="doctl_kubernetes_cluster_kubeconfig_save"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--set-current-context")
    local_nonpersistent_flags+=("--set-current-context")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_kubeconfig_show()
{
    last_command="doctl_kubernetes_cluster_kubeconfig_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_kubeconfig()
{
    last_command="doctl_kubernetes_cluster_kubeconfig"

    command_aliases=()

    commands=()
    commands+=("remove")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("save")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="save"
    fi
    commands+=("show")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="show"
        command_aliases+=("p")
        aliashash["p"]="show"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_list()
{
    last_command="doctl_kubernetes_cluster_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_node-pool_create()
{
    last_command="doctl_kubernetes_cluster_node-pool_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auto-scale")
    local_nonpersistent_flags+=("--auto-scale")
    flags+=("--count=")
    local_nonpersistent_flags+=("--count=")
    flags+=("--label=")
    local_nonpersistent_flags+=("--label=")
    flags+=("--max-nodes=")
    local_nonpersistent_flags+=("--max-nodes=")
    flags+=("--min-nodes=")
    local_nonpersistent_flags+=("--min-nodes=")
    flags+=("--name=")
    local_nonpersistent_flags+=("--name=")
    flags+=("--size=")
    local_nonpersistent_flags+=("--size=")
    flags+=("--tag=")
    local_nonpersistent_flags+=("--tag=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_node-pool_delete()
{
    last_command="doctl_kubernetes_cluster_node-pool_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_node-pool_delete-node()
{
    last_command="doctl_kubernetes_cluster_node-pool_delete-node"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--skip-drain")
    local_nonpersistent_flags+=("--skip-drain")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_node-pool_get()
{
    last_command="doctl_kubernetes_cluster_node-pool_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_node-pool_list()
{
    last_command="doctl_kubernetes_cluster_node-pool_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_node-pool_replace-node()
{
    last_command="doctl_kubernetes_cluster_node-pool_replace-node"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--skip-drain")
    local_nonpersistent_flags+=("--skip-drain")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_node-pool_update()
{
    last_command="doctl_kubernetes_cluster_node-pool_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auto-scale")
    local_nonpersistent_flags+=("--auto-scale")
    flags+=("--count=")
    local_nonpersistent_flags+=("--count=")
    flags+=("--label=")
    local_nonpersistent_flags+=("--label=")
    flags+=("--max-nodes=")
    local_nonpersistent_flags+=("--max-nodes=")
    flags+=("--min-nodes=")
    local_nonpersistent_flags+=("--min-nodes=")
    flags+=("--name=")
    local_nonpersistent_flags+=("--name=")
    flags+=("--tag=")
    local_nonpersistent_flags+=("--tag=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_node-pool()
{
    last_command="doctl_kubernetes_cluster_node-pool"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("delete-node")
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("replace-node")
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_update()
{
    last_command="doctl_kubernetes_cluster_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auto-upgrade")
    local_nonpersistent_flags+=("--auto-upgrade")
    flags+=("--cluster-name=")
    local_nonpersistent_flags+=("--cluster-name=")
    flags+=("--maintenance-window=")
    local_nonpersistent_flags+=("--maintenance-window=")
    flags+=("--set-current-context")
    local_nonpersistent_flags+=("--set-current-context")
    flags+=("--tag=")
    local_nonpersistent_flags+=("--tag=")
    flags+=("--update-kubeconfig")
    local_nonpersistent_flags+=("--update-kubeconfig")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster_upgrade()
{
    last_command="doctl_kubernetes_cluster_upgrade"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--version=")
    local_nonpersistent_flags+=("--version=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_cluster()
{
    last_command="doctl_kubernetes_cluster"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("get-upgrades")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("gu")
        aliashash["gu"]="get-upgrades"
    fi
    commands+=("kubeconfig")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("cfg")
        aliashash["cfg"]="kubeconfig"
        command_aliases+=("config")
        aliashash["config"]="kubeconfig"
        command_aliases+=("k8scfg")
        aliashash["k8scfg"]="kubeconfig"
        command_aliases+=("kubecfg")
        aliashash["kubecfg"]="kubeconfig"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("node-pool")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("node-pools")
        aliashash["node-pools"]="node-pool"
        command_aliases+=("nodepool")
        aliashash["nodepool"]="node-pool"
        command_aliases+=("nodepools")
        aliashash["nodepools"]="node-pool"
        command_aliases+=("np")
        aliashash["np"]="node-pool"
        command_aliases+=("p")
        aliashash["p"]="node-pool"
        command_aliases+=("pool")
        aliashash["pool"]="node-pool"
        command_aliases+=("pools")
        aliashash["pools"]="node-pool"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="update"
    fi
    commands+=("upgrade")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_options_regions()
{
    last_command="doctl_kubernetes_options_regions"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_options_sizes()
{
    last_command="doctl_kubernetes_options_sizes"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_options_versions()
{
    last_command="doctl_kubernetes_options_versions"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes_options()
{
    last_command="doctl_kubernetes_options"

    command_aliases=()

    commands=()
    commands+=("regions")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("r")
        aliashash["r"]="regions"
    fi
    commands+=("sizes")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="sizes"
    fi
    commands+=("versions")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("v")
        aliashash["v"]="versions"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_kubernetes()
{
    last_command="doctl_kubernetes"

    command_aliases=()

    commands=()
    commands+=("cluster")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="cluster"
        command_aliases+=("clusters")
        aliashash["clusters"]="cluster"
    fi
    commands+=("options")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("o")
        aliashash["o"]="options"
        command_aliases+=("opts")
        aliashash["opts"]="options"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_projects_create()
{
    last_command="doctl_projects_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--description=")
    local_nonpersistent_flags+=("--description=")
    flags+=("--environment=")
    local_nonpersistent_flags+=("--environment=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--name=")
    local_nonpersistent_flags+=("--name=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--purpose=")
    local_nonpersistent_flags+=("--purpose=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_projects_delete()
{
    last_command="doctl_projects_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_projects_get()
{
    last_command="doctl_projects_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_projects_list()
{
    last_command="doctl_projects_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_projects_resources_assign()
{
    last_command="doctl_projects_resources_assign"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--resource=")
    local_nonpersistent_flags+=("--resource=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_projects_resources_get()
{
    last_command="doctl_projects_resources_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_projects_resources_list()
{
    last_command="doctl_projects_resources_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_projects_resources()
{
    last_command="doctl_projects_resources"

    command_aliases=()

    commands=()
    commands+=("assign")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("a")
        aliashash["a"]="assign"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_projects_update()
{
    last_command="doctl_projects_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--description=")
    local_nonpersistent_flags+=("--description=")
    flags+=("--environment=")
    local_nonpersistent_flags+=("--environment=")
    flags+=("--format=")
    local_nonpersistent_flags+=("--format=")
    flags+=("--is_default")
    local_nonpersistent_flags+=("--is_default")
    flags+=("--name=")
    local_nonpersistent_flags+=("--name=")
    flags+=("--no-header")
    local_nonpersistent_flags+=("--no-header")
    flags+=("--purpose=")
    local_nonpersistent_flags+=("--purpose=")
    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_projects()
{
    last_command="doctl_projects"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="create"
    fi
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("get")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("g")
        aliashash["g"]="get"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("resources")
    commands+=("update")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_version()
{
    last_command="doctl_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_doctl_root_command()
{
    last_command="doctl"

    command_aliases=()

    commands=()
    commands+=("account")
    commands+=("auth")
    commands+=("balance")
    
    commands+=("compute")
    commands+=("databases")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="databases"
        command_aliases+=("database")
        aliashash["database"]="databases"
        command_aliases+=("db")
        aliashash["db"]="databases"
        command_aliases+=("dbs")
        aliashash["dbs"]="databases"
    fi
    commands+=("invoice")
    commands+=("kubernetes")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("k")
        aliashash["k"]="kubernetes"
        command_aliases+=("k8s")
        aliashash["k8s"]="kubernetes"
        command_aliases+=("kube")
        aliashash["kube"]="kubernetes"
    fi
    commands+=("projects")
    commands+=("version")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-token=")
    two_word_flags+=("-t")
    flags+=("--api-url=")
    two_word_flags+=("-u")
    flags+=("--config=")
    two_word_flags+=("-c")
    flags+=("--context=")
    flags+=("--output=")
    two_word_flags+=("-o")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_doctl()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __doctl_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("doctl")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local last_command
    local nouns=()

    __doctl_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_doctl doctl
else
    complete -o default -o nospace -F __start_doctl doctl
fi

# ex: ts=4 sw=4 et filetype=sh
