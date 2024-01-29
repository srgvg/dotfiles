#!/bin/bash

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
    datree
    doctl
    flux
    go-chromecast
    hcloud
    helm
    hubble
    k9s
    kind
    kind
    kubectl
    kubectl-plugin_completion
    kubescape
    kubeshark
    kustomize
    pluto
    regctl
    regsync
    regbot
    talosctl
    velero
)
completions_bash_commands=(
    starship
)
dashdash_completion_bash_commands=(
    stern
)

#######################################################################################################################
#
generate_completion_bash() {
    command=$1
    type=${2:-completion}
    source=${2:-}
    if hash $command >&/dev/null || type -a $command >&/dev/null
    then
        if [ -n "${source}" ]
        then
            echo "source <($command $type bash)" > ${complpath}/${command}${complext}
        elif [ -x "$(which ${command})" ]
        then
            if $command ${type} bash > /tmp/${command}${complext} 2>/dev/null
            then
                if cmp /tmp/${command}${complext} ${complpath}/${command}${complext}
                then
                    echo "unchanged ${command}"
                    return 0
                else
                    mv /tmp/${command}${complext} ${complpath}/${command}${complext}
                    chmod 644 ${complpath}/${command}${complext}
                    echo "updated   ${command}"
                    return 0
                fi
            else
                echo "error generating completions for ${command}" >&2
                return 1
            fi
        else
            echo -e "\n$command not executable"
            return 1
        fi
    else
        echo -e "\n$command not found"
        echo consider: rm -f ${complpath}/${command}${complext}
        return 1
    fi
}

#######################################################################################################################
#
for command in ${completion_bash_commands[@]}
do
    generate_completion_bash $command || echo $command NOK
done
for command in ${completions_bash_commands[@]}
do
    generate_completion_bash $command completions || echo $command NOK
done
for command in ${dashdash_completion_bash_commands[@]}
do
    generate_completion_bash $command --completion || echo $command NOK
done

#######################################################################################################################
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
    echo "source $HOME/.asdf/installs/gcloud/${GCLOUD_VERSION}/completion.bash.inc" \
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

####################

command=asdf
if ln -nfs $HOME/.asdf/completions/asdf.bash ${complpath}/${command}${complext}
then
    chmod 644 ${complpath}/${command}${complext}
    echo "OK  ${command}"
else
    echo "NOK ${command}"
fi

####################
