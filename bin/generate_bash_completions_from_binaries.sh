#!/bin/bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: nil
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=true:


# bash-completion’s on-demand loading.
# Whenever completions for command cmd are needed for the first time,
# bash-completion looks for ~/.local/share/bash-completion/completions/cmd
# or /usr/share/bash-completion/completions/cmd.

complpath="$HOME/.local/share/bash-completion/completions"
complext=""

completion_bash_commands=(
    argocd
    arkade
    civo
    clusterctl
    cmctl
    datree
    doctl
    flux
    havener
    hcloud
    helm
    k9s
    kanctl
    kando
    kind
    kind
    krew
    kubecm
    kubectl
    kubectl-plugin_completion
    kustomize
    nova
    oc
    talosctl
    velero
)
completions_bash_commands=(
    starship
)

#######################################################################################################################
#
generate_completion_bash() {
    command=$1
    source=${2:-}
    if hash $command >&/dev/null
    then
        if [ -n "${source}" ]
        then
            echo "source <($command completion bash)" > ${complpath}/${command}${complext}
        else
            $command completion bash > ${complpath}/${command}${complext}
        fi
    fi
}

generate_completions_bash() {
    command=$1
    if hash $command >&/dev/null
    then
        $command completions bash > ${complpath}/${command}${complext}
    fi
}

#######################################################################################################################
#
for command in ${completion_bash_commands[@]}
do
    echo -n .
    generate_completion_bash $command || echo $command NOK
done
for command in ${completions_bash_commands[@]}
do
    echo -n .
    generate_completions_bash $command || echo $command NOK
done

#######################################################################################################################
# custom....
#
# scw
echo -n .
# https://github.com/scaleway/scaleway-cli/issues/1959#issuecomment-1451964559
scw autocomplete script shell=bash \
    | sed -E 's#(_?)\/([^ \n]*)scw#\1scw#g' \
    > ${complpath}/scw${complext} || echo scw NOK

# gcloud
echo -n .
echo "source $HOME/.asdf/installs/gcloud/$(gcloud version 2>/dev/null \
    | grep "Google Cloud SDK" \
    | sed 's/Google Cloud SDK //')/completion.bash.inc" \
    > ${complpath}/gcloud${complext} || echo gcloud NOK

# kubie
echo .
KUBIE_VERSION=$(kubie --version | sed 's/kubie /v/')
curl -L --no-progress-meter https://raw.githubusercontent.com/sbstp/kubie/${KUBIE_VERSION}/completion/kubie.bash \
    >  ${complpath}/kubie${complext} || echo kubie NOK

####################

ln -vnfs $HOME/.asdf/completions/asdf.bash ${complpath}/asdf${complext}

####################
