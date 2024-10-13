# bash completion for kustomize                            -*- shell-script -*-

__kustomize_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE:-} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__kustomize_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__kustomize_index_of_word()
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

__kustomize_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__kustomize_handle_go_custom_completion()
{
    __kustomize_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly kustomize allows handling aliases
    args=("${words[@]:1}")
    # Disable ActiveHelp which is not supported for bash completion v1
    requestComp="KUSTOMIZE_ACTIVE_HELP=0 ${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __kustomize_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __kustomize_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __kustomize_debug "${FUNCNAME[0]}: calling ${requestComp}"
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
    __kustomize_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __kustomize_debug "${FUNCNAME[0]}: the completions are: ${out}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __kustomize_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __kustomize_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __kustomize_debug "${FUNCNAME[0]}: activating no file completion"
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
        __kustomize_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subdir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out}")
        if [ -n "$subdir" ]; then
            __kustomize_debug "Listing directories in $subdir"
            __kustomize_handle_subdirs_in_dir_flag "$subdir"
        else
            __kustomize_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out}" -- "$cur")
    fi
}

__kustomize_handle_reply()
{
    __kustomize_debug "${FUNCNAME[0]}"
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
                __kustomize_index_of_word "${flag}" "${flags_with_completion[@]}"
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
    __kustomize_index_of_word "${prev}" "${flags_with_completion[@]}"
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
        __kustomize_handle_go_custom_completion
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
        if declare -F __kustomize_custom_func >/dev/null; then
            # try command name qualified custom func
            __kustomize_custom_func
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
__kustomize_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__kustomize_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__kustomize_handle_flag()
{
    __kustomize_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue=""
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __kustomize_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __kustomize_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __kustomize_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
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
    if [[ ${words[c]} != *"="* ]] && __kustomize_contains_word "${words[c]}" "${two_word_flags[@]}"; then
        __kustomize_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__kustomize_handle_noun()
{
    __kustomize_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __kustomize_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __kustomize_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__kustomize_handle_command()
{
    __kustomize_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_kustomize_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __kustomize_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__kustomize_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __kustomize_handle_reply
        return
    fi
    __kustomize_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __kustomize_handle_flag
    elif __kustomize_contains_word "${words[c]}" "${commands[@]}"; then
        __kustomize_handle_command
    elif [[ $c -eq 0 ]]; then
        __kustomize_handle_command
    elif __kustomize_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __kustomize_handle_command
        else
            __kustomize_handle_noun
        fi
    else
        __kustomize_handle_noun
    fi
    __kustomize_handle_word
}

_kustomize_build()
{
    last_command="kustomize_build"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--as-current-user")
    local_nonpersistent_flags+=("--as-current-user")
    flags+=("--enable-alpha-plugins")
    local_nonpersistent_flags+=("--enable-alpha-plugins")
    flags+=("--enable-exec")
    local_nonpersistent_flags+=("--enable-exec")
    flags+=("--enable-helm")
    local_nonpersistent_flags+=("--enable-helm")
    flags+=("--env=")
    two_word_flags+=("--env")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--env")
    local_nonpersistent_flags+=("--env=")
    local_nonpersistent_flags+=("-e")
    flags+=("--helm-api-versions=")
    two_word_flags+=("--helm-api-versions")
    local_nonpersistent_flags+=("--helm-api-versions")
    local_nonpersistent_flags+=("--helm-api-versions=")
    flags+=("--helm-command=")
    two_word_flags+=("--helm-command")
    local_nonpersistent_flags+=("--helm-command")
    local_nonpersistent_flags+=("--helm-command=")
    flags+=("--helm-debug")
    local_nonpersistent_flags+=("--helm-debug")
    flags+=("--helm-kube-version=")
    two_word_flags+=("--helm-kube-version")
    local_nonpersistent_flags+=("--helm-kube-version")
    local_nonpersistent_flags+=("--helm-kube-version=")
    flags+=("--load-restrictor=")
    two_word_flags+=("--load-restrictor")
    flags_with_completion+=("--load-restrictor")
    flags_completion+=("__kustomize_handle_go_custom_completion")
    local_nonpersistent_flags+=("--load-restrictor")
    local_nonpersistent_flags+=("--load-restrictor=")
    flags+=("--mount=")
    two_word_flags+=("--mount")
    local_nonpersistent_flags+=("--mount")
    local_nonpersistent_flags+=("--mount=")
    flags+=("--network")
    local_nonpersistent_flags+=("--network")
    flags+=("--network-name=")
    two_word_flags+=("--network-name")
    local_nonpersistent_flags+=("--network-name")
    local_nonpersistent_flags+=("--network-name=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_cfg_cat()
{
    last_command="kustomize_cfg_cat"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotate")
    local_nonpersistent_flags+=("--annotate")
    flags+=("--dest=")
    two_word_flags+=("--dest")
    local_nonpersistent_flags+=("--dest")
    local_nonpersistent_flags+=("--dest=")
    flags+=("--exclude-non-local")
    local_nonpersistent_flags+=("--exclude-non-local")
    flags+=("--format")
    local_nonpersistent_flags+=("--format")
    flags+=("--function-config=")
    two_word_flags+=("--function-config")
    local_nonpersistent_flags+=("--function-config")
    local_nonpersistent_flags+=("--function-config=")
    flags+=("--include-local")
    local_nonpersistent_flags+=("--include-local")
    flags+=("--recurse-subpackages")
    flags+=("-R")
    local_nonpersistent_flags+=("--recurse-subpackages")
    local_nonpersistent_flags+=("-R")
    flags+=("--strip-comments")
    local_nonpersistent_flags+=("--strip-comments")
    flags+=("--style=")
    two_word_flags+=("--style")
    local_nonpersistent_flags+=("--style")
    local_nonpersistent_flags+=("--style=")
    flags+=("--wrap-kind=")
    two_word_flags+=("--wrap-kind")
    local_nonpersistent_flags+=("--wrap-kind")
    local_nonpersistent_flags+=("--wrap-kind=")
    flags+=("--wrap-version=")
    two_word_flags+=("--wrap-version")
    local_nonpersistent_flags+=("--wrap-version")
    local_nonpersistent_flags+=("--wrap-version=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_cfg_count()
{
    last_command="kustomize_cfg_count"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--kind")
    local_nonpersistent_flags+=("--kind")
    flags+=("--recurse-subpackages")
    flags+=("-R")
    local_nonpersistent_flags+=("--recurse-subpackages")
    local_nonpersistent_flags+=("-R")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_cfg_grep()
{
    last_command="kustomize_cfg_grep"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotate")
    local_nonpersistent_flags+=("--annotate")
    flags+=("--invert-match")
    local_nonpersistent_flags+=("--invert-match")
    flags+=("--recurse-subpackages")
    flags+=("-R")
    local_nonpersistent_flags+=("--recurse-subpackages")
    local_nonpersistent_flags+=("-R")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_cfg_tree()
{
    last_command="kustomize_cfg_tree"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--args")
    local_nonpersistent_flags+=("--args")
    flags+=("--command")
    local_nonpersistent_flags+=("--command")
    flags+=("--env")
    local_nonpersistent_flags+=("--env")
    flags+=("--exclude-non-local")
    local_nonpersistent_flags+=("--exclude-non-local")
    flags+=("--field=")
    two_word_flags+=("--field")
    local_nonpersistent_flags+=("--field")
    local_nonpersistent_flags+=("--field=")
    flags+=("--graph-structure=")
    two_word_flags+=("--graph-structure")
    local_nonpersistent_flags+=("--graph-structure")
    local_nonpersistent_flags+=("--graph-structure=")
    flags+=("--image")
    local_nonpersistent_flags+=("--image")
    flags+=("--include-local")
    local_nonpersistent_flags+=("--include-local")
    flags+=("--name")
    local_nonpersistent_flags+=("--name")
    flags+=("--ports")
    local_nonpersistent_flags+=("--ports")
    flags+=("--replicas")
    local_nonpersistent_flags+=("--replicas")
    flags+=("--resources")
    local_nonpersistent_flags+=("--resources")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_cfg()
{
    last_command="kustomize_cfg"

    command_aliases=()

    commands=()
    commands+=("cat")
    commands+=("count")
    commands+=("grep")
    commands+=("tree")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_completion()
{
    last_command="kustomize_completion"

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
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    must_have_one_noun+=("bash")
    must_have_one_noun+=("fish")
    must_have_one_noun+=("powershell")
    must_have_one_noun+=("zsh")
    noun_aliases=()
}

_kustomize_create()
{
    last_command="kustomize_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotations=")
    two_word_flags+=("--annotations")
    local_nonpersistent_flags+=("--annotations")
    local_nonpersistent_flags+=("--annotations=")
    flags+=("--autodetect")
    local_nonpersistent_flags+=("--autodetect")
    flags+=("--labels=")
    two_word_flags+=("--labels")
    local_nonpersistent_flags+=("--labels")
    local_nonpersistent_flags+=("--labels=")
    flags+=("--nameprefix=")
    two_word_flags+=("--nameprefix")
    local_nonpersistent_flags+=("--nameprefix")
    local_nonpersistent_flags+=("--nameprefix=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--namesuffix=")
    two_word_flags+=("--namesuffix")
    local_nonpersistent_flags+=("--namesuffix")
    local_nonpersistent_flags+=("--namesuffix=")
    flags+=("--recursive")
    local_nonpersistent_flags+=("--recursive")
    flags+=("--resources=")
    two_word_flags+=("--resources")
    local_nonpersistent_flags+=("--resources")
    local_nonpersistent_flags+=("--resources=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_annotation()
{
    last_command="kustomize_edit_add_annotation"

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
    local_nonpersistent_flags+=("-f")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_base()
{
    last_command="kustomize_edit_add_base"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_buildmetadata()
{
    last_command="kustomize_edit_add_buildmetadata"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_component()
{
    last_command="kustomize_edit_add_component"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_configmap()
{
    last_command="kustomize_edit_add_configmap"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--behavior=")
    two_word_flags+=("--behavior")
    local_nonpersistent_flags+=("--behavior")
    local_nonpersistent_flags+=("--behavior=")
    flags+=("--disableNameSuffixHash")
    local_nonpersistent_flags+=("--disableNameSuffixHash")
    flags+=("--from-env-file=")
    two_word_flags+=("--from-env-file")
    local_nonpersistent_flags+=("--from-env-file")
    local_nonpersistent_flags+=("--from-env-file=")
    flags+=("--from-file=")
    two_word_flags+=("--from-file")
    local_nonpersistent_flags+=("--from-file")
    local_nonpersistent_flags+=("--from-file=")
    flags+=("--from-literal=")
    two_word_flags+=("--from-literal")
    local_nonpersistent_flags+=("--from-literal")
    local_nonpersistent_flags+=("--from-literal=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_generator()
{
    last_command="kustomize_edit_add_generator"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_label()
{
    last_command="kustomize_edit_add_label"

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
    local_nonpersistent_flags+=("-f")
    flags+=("--include-templates")
    local_nonpersistent_flags+=("--include-templates")
    flags+=("--without-selector")
    local_nonpersistent_flags+=("--without-selector")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_patch()
{
    last_command="kustomize_edit_add_patch"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotation-selector=")
    two_word_flags+=("--annotation-selector")
    local_nonpersistent_flags+=("--annotation-selector")
    local_nonpersistent_flags+=("--annotation-selector=")
    flags+=("--group=")
    two_word_flags+=("--group")
    local_nonpersistent_flags+=("--group")
    local_nonpersistent_flags+=("--group=")
    flags+=("--kind=")
    two_word_flags+=("--kind")
    local_nonpersistent_flags+=("--kind")
    local_nonpersistent_flags+=("--kind=")
    flags+=("--label-selector=")
    two_word_flags+=("--label-selector")
    local_nonpersistent_flags+=("--label-selector")
    local_nonpersistent_flags+=("--label-selector=")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--patch=")
    two_word_flags+=("--patch")
    local_nonpersistent_flags+=("--patch")
    local_nonpersistent_flags+=("--patch=")
    flags+=("--path=")
    two_word_flags+=("--path")
    local_nonpersistent_flags+=("--path")
    local_nonpersistent_flags+=("--path=")
    flags+=("--version=")
    two_word_flags+=("--version")
    local_nonpersistent_flags+=("--version")
    local_nonpersistent_flags+=("--version=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_resource()
{
    last_command="kustomize_edit_add_resource"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-verify")
    local_nonpersistent_flags+=("--no-verify")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_secret()
{
    last_command="kustomize_edit_add_secret"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--disableNameSuffixHash")
    local_nonpersistent_flags+=("--disableNameSuffixHash")
    flags+=("--from-env-file=")
    two_word_flags+=("--from-env-file")
    local_nonpersistent_flags+=("--from-env-file")
    local_nonpersistent_flags+=("--from-env-file=")
    flags+=("--from-file=")
    two_word_flags+=("--from-file")
    local_nonpersistent_flags+=("--from-file")
    local_nonpersistent_flags+=("--from-file=")
    flags+=("--from-literal=")
    two_word_flags+=("--from-literal")
    local_nonpersistent_flags+=("--from-literal")
    local_nonpersistent_flags+=("--from-literal=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--type=")
    two_word_flags+=("--type")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add_transformer()
{
    last_command="kustomize_edit_add_transformer"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_add()
{
    last_command="kustomize_edit_add"

    command_aliases=()

    commands=()
    commands+=("annotation")
    commands+=("base")
    commands+=("buildmetadata")
    commands+=("component")
    commands+=("configmap")
    commands+=("generator")
    commands+=("label")
    commands+=("patch")
    commands+=("resource")
    commands+=("secret")
    commands+=("transformer")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_alpha-list-builtin-plugin()
{
    last_command="kustomize_edit_alpha-list-builtin-plugin"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_fix()
{
    last_command="kustomize_edit_fix"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--vars")
    local_nonpersistent_flags+=("--vars")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_remove_annotation()
{
    last_command="kustomize_edit_remove_annotation"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--ignore-non-existence")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-non-existence")
    local_nonpersistent_flags+=("-i")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_remove_buildmetadata()
{
    last_command="kustomize_edit_remove_buildmetadata"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_remove_configmap()
{
    last_command="kustomize_edit_remove_configmap"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_remove_label()
{
    last_command="kustomize_edit_remove_label"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--ignore-non-existence")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-non-existence")
    local_nonpersistent_flags+=("-i")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_remove_patch()
{
    last_command="kustomize_edit_remove_patch"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotation-selector=")
    two_word_flags+=("--annotation-selector")
    local_nonpersistent_flags+=("--annotation-selector")
    local_nonpersistent_flags+=("--annotation-selector=")
    flags+=("--group=")
    two_word_flags+=("--group")
    local_nonpersistent_flags+=("--group")
    local_nonpersistent_flags+=("--group=")
    flags+=("--kind=")
    two_word_flags+=("--kind")
    local_nonpersistent_flags+=("--kind")
    local_nonpersistent_flags+=("--kind=")
    flags+=("--label-selector=")
    two_word_flags+=("--label-selector")
    local_nonpersistent_flags+=("--label-selector")
    local_nonpersistent_flags+=("--label-selector=")
    flags+=("--name=")
    two_word_flags+=("--name")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--patch=")
    two_word_flags+=("--patch")
    local_nonpersistent_flags+=("--patch")
    local_nonpersistent_flags+=("--patch=")
    flags+=("--path=")
    two_word_flags+=("--path")
    local_nonpersistent_flags+=("--path")
    local_nonpersistent_flags+=("--path=")
    flags+=("--version=")
    two_word_flags+=("--version")
    local_nonpersistent_flags+=("--version")
    local_nonpersistent_flags+=("--version=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_remove_resource()
{
    last_command="kustomize_edit_remove_resource"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_remove_secret()
{
    last_command="kustomize_edit_remove_secret"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_remove_transformer()
{
    last_command="kustomize_edit_remove_transformer"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_remove()
{
    last_command="kustomize_edit_remove"

    command_aliases=()

    commands=()
    commands+=("annotation")
    commands+=("buildmetadata")
    commands+=("configmap")
    commands+=("label")
    commands+=("patch")
    commands+=("resource")
    commands+=("secret")
    commands+=("transformer")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set_annotation()
{
    last_command="kustomize_edit_set_annotation"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set_buildmetadata()
{
    last_command="kustomize_edit_set_buildmetadata"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set_configmap()
{
    last_command="kustomize_edit_set_configmap"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--from-literal=")
    two_word_flags+=("--from-literal")
    local_nonpersistent_flags+=("--from-literal")
    local_nonpersistent_flags+=("--from-literal=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--new-namespace=")
    two_word_flags+=("--new-namespace")
    local_nonpersistent_flags+=("--new-namespace")
    local_nonpersistent_flags+=("--new-namespace=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set_image()
{
    last_command="kustomize_edit_set_image"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set_label()
{
    last_command="kustomize_edit_set_label"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set_nameprefix()
{
    last_command="kustomize_edit_set_nameprefix"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set_namespace()
{
    last_command="kustomize_edit_set_namespace"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set_namesuffix()
{
    last_command="kustomize_edit_set_namesuffix"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set_replicas()
{
    last_command="kustomize_edit_set_replicas"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set_secret()
{
    last_command="kustomize_edit_set_secret"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--from-literal=")
    two_word_flags+=("--from-literal")
    local_nonpersistent_flags+=("--from-literal")
    local_nonpersistent_flags+=("--from-literal=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--new-namespace=")
    two_word_flags+=("--new-namespace")
    local_nonpersistent_flags+=("--new-namespace")
    local_nonpersistent_flags+=("--new-namespace=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit_set()
{
    last_command="kustomize_edit_set"

    command_aliases=()

    commands=()
    commands+=("annotation")
    commands+=("buildmetadata")
    commands+=("configmap")
    commands+=("image")
    commands+=("label")
    commands+=("nameprefix")
    commands+=("namespace")
    commands+=("namesuffix")
    commands+=("replicas")
    commands+=("secret")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_edit()
{
    last_command="kustomize_edit"

    command_aliases=()

    commands=()
    commands+=("add")
    commands+=("alpha-list-builtin-plugin")
    commands+=("fix")
    commands+=("remove")
    commands+=("set")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_fn_run()
{
    last_command="kustomize_fn_run"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--as-current-user")
    local_nonpersistent_flags+=("--as-current-user")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--enable-exec")
    local_nonpersistent_flags+=("--enable-exec")
    flags+=("--env=")
    two_word_flags+=("--env")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--env")
    local_nonpersistent_flags+=("--env=")
    local_nonpersistent_flags+=("-e")
    flags+=("--exec-path=")
    two_word_flags+=("--exec-path")
    local_nonpersistent_flags+=("--exec-path")
    local_nonpersistent_flags+=("--exec-path=")
    flags+=("--fn-path=")
    two_word_flags+=("--fn-path")
    local_nonpersistent_flags+=("--fn-path")
    local_nonpersistent_flags+=("--fn-path=")
    flags+=("--global-scope")
    local_nonpersistent_flags+=("--global-scope")
    flags+=("--image=")
    two_word_flags+=("--image")
    local_nonpersistent_flags+=("--image")
    local_nonpersistent_flags+=("--image=")
    flags+=("--include-subpackages")
    local_nonpersistent_flags+=("--include-subpackages")
    flags+=("--log-steps")
    local_nonpersistent_flags+=("--log-steps")
    flags+=("--mount=")
    two_word_flags+=("--mount")
    local_nonpersistent_flags+=("--mount")
    local_nonpersistent_flags+=("--mount=")
    flags+=("--network")
    local_nonpersistent_flags+=("--network")
    flags+=("--results-dir=")
    two_word_flags+=("--results-dir")
    local_nonpersistent_flags+=("--results-dir")
    local_nonpersistent_flags+=("--results-dir=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_fn()
{
    last_command="kustomize_fn"

    command_aliases=()

    commands=()
    commands+=("run")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_help()
{
    last_command="kustomize_help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_kustomize_localize()
{
    last_command="kustomize_localize"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-verify")
    local_nonpersistent_flags+=("--no-verify")
    flags+=("--scope=")
    two_word_flags+=("--scope")
    local_nonpersistent_flags+=("--scope")
    local_nonpersistent_flags+=("--scope=")
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_version()
{
    last_command="kustomize_version"

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
    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_kustomize_root_command()
{
    last_command="kustomize"

    command_aliases=()

    commands=()
    commands+=("build")
    commands+=("cfg")
    commands+=("completion")
    commands+=("create")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("init")
        aliashash["init"]="create"
    fi
    commands+=("edit")
    commands+=("fn")
    commands+=("help")
    commands+=("localize")
    commands+=("version")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack-trace")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_kustomize()
{
    local cur prev words cword split
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __kustomize_init_completion -n "=" || return
    fi

    local c=0
    local flag_parsing_disabled=
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("kustomize")
    local command_aliases=()
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function=""
    local last_command=""
    local nouns=()
    local noun_aliases=()

    __kustomize_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_kustomize kustomize
else
    complete -o default -o nospace -F __start_kustomize kustomize
fi

# ex: ts=4 sw=4 et filetype=sh
