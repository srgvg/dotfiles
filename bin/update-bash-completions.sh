#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: nil
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=true:

set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

##########################################################################################################
#
CURL_COMMAND="curl --silent --connect-timeout 5 --location"
source $HOME/etc/keys/tokens.bash && CURL_COMMAND="$CURL_COMMAND -u $GITHUB_USER:$GITHUB_TOKEN"

complpath="$HOME/.local/share/bash-completion/completions"
complext=""

completion_bash_commands=(
    argocd
    cilium
    civo
    clusterctl
    cmctl
    codex
    datree
    doctl
    dyff
    eksctl
    flux
    flux-operator
    forward-email
    go-chromecast
    hcloud
    helm
    hubble
    k9s
    kind
    kind
    kubectl
    kubelogin
    kubescape
    kubeshark
    kustomize
    mise
    pluto
    regctl
    regsync
    regbot
    sops
    talosctl
    talhelper
    yq
    zarf
    zli
)
completions_bash_commands=(
    starship
)
dashdash_completion_bash_commands=(
    stern
)
register_python_argcomplete_commands=(
    pipx
    )

#######################################################################################################################
#
generate_completion_bash() {
    local type
    local command
    type=$1
    command=$2
    if hash $command >&/dev/null || type -a $command >&/dev/null
    then
        if [ -x "$(which ${command})" ]
        then
            if [ ${type} = "register-python-argcomplete" ]
            then
                errout=$(register-python-argcomplete ${command} 2>&1 > /tmp/${command}${complext})
                rc=$?
            elif [ ${command} = "mise" ]
            then
                errout=$($command ${type} --include-bash-completion-lib bash 2>&1 > /tmp/${command}${complext})
                rc=$?
            else
                errout=$($command ${type} bash 2>&1 > /tmp/${command}${complext})
                rc=$?
            fi
            # [ -n "${errout:-}" ] && echo ERROUT $errout
            if [ $rc -eq 0 ]
            then
                if cmp /tmp/${command}${complext} ${complpath}/${command}${complext} >/dev/null 2>&1
                then
                    echo "unchanged ${command}"
                else
                    mv /tmp/${command}${complext} ${complpath}/${command}${complext}
                    chmod 644 ${complpath}/${command}${complext}
                    echo "updated   ${command}"
                fi
            else
                echo "error generating completions for ${command}:" >&2
                echo ${errout}
                echo
                return 1
            fi
        else
            echo -e "\n$command not executable"
            return 1
        fi
    else
        echo
        echo "$command not found"
        echo "consider removing $command from this tool and:"
        echo "rm -vf ${complpath}/${command}${complext}"
        echo
        return 1
    fi
}

#######################################################################################################################
#
for command in "${completion_bash_commands[@]}"
do
    generate_completion_bash completion $command ||:
done
for command in "${completions_bash_commands[@]}"
do
    generate_completion_bash completions $command ||:
done
for command in "${dashdash_completion_bash_commands[@]}"
do
    generate_completion_bash --completion $command ||:
done
for command in "${register_python_argcomplete_commands[@]}"
do
    generate_completion_bash register-python-argcomplete $command ||:
done
#######################################################################################################################
echo
#######################################################################################################################
# custom....
#
# scw
# https://github.com/scaleway/scaleway-cli/issues/1959#issuecomment-1451964559
command=scw
if scw autocomplete script shell=bash \
    | sed -E 's#(_?)\/([^ \n]*)scw#\1scw#g' \
    > ${complpath}/${command}${complext}
then
    chmod 644 ${complpath}/${command}${complext}
    echo "OK  ${command}"
else
    echo "NOK ${command}"
fi

# gcloud
command=gcloud
if GCLOUD_VERSION="$(gcloud version 2>/dev/null | grep "Google Cloud SDK" | sed 's/Google Cloud SDK //')"
then
    echo "source $HOME/.local/share/mise/installs/gcloud/${GCLOUD_VERSION}/completion.bash.inc" \
        > ${complpath}/gcloud${complext}
    chmod 644 ${complpath}/${command}${complext}
    echo "OK  ${command}"
else
    echo "NOK ${command}"
fi

# kubie
command=kubie
KUBIE_VERSION=$(kubie --version | sed 's/kubie /v/')
if $CURL_COMMAND https://raw.githubusercontent.com/sbstp/kubie/${KUBIE_VERSION}/completion/kubie.bash \
    >  ${complpath}/${command}${complext}
then
    chmod 644 ${complpath}/${command}${complext}
    echo "OK  ${command}"
else
    echo "NOK ${command}"
fi

# golang
command=go
if $CURL_COMMAND https://raw.github.com/kura/go-bash-completion/master/etc/bash_completion.d/go -o ${complpath}/${command}${complext}
then
    chmod 644 ${complpath}/${command}${complext}
    echo "OK  ${command}"
else
    echo "NOK ${command}"
fi


# azure-cli
command=az
if $CURL_COMMAND https://raw.githubusercontent.com/Azure/azure-cli/dev/az.completion -o ${complpath}/${command}${complext}
then
    chmod 644 ${complpath}/${command}${complext}
    echo "OK  ${command}"
else
    echo "NOK ${command}"
fi


## asdf
#command=asdf
#if ln -nfs $HOME/.asdf/completions/asdf.bash ${complpath}/${command}${complext}
#then
#    chmod 644 ${complpath}/${command}${complext}
#    echo "OK  ${command}"
#else
#    echo "NOK ${command}"
#fi

# kubectl stuff
ln -nfs ${complpath}/kubectl ${complpath}/k
ln -nfs ${complpath}/kubectl ${complpath}/kubecolor

#command=kubectl-plugin_completion
#if kubectl plugin_completion plugin-completion bash > ${complpath}/${command}${complext}
#then
#    chmod 644 ${complpath}/${command}${complext}
#    echo "OK  ${command}"
#else
#    echo "NOK ${command}"
#fi


# talosctl stuff
ln -nfs ${complpath}/talosctl ${complpath}/t


####################
