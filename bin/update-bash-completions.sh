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
    krew
    kubectl
    kubectl-plugin_completion
    kubescape
    kubeshark
    kustomize
    nova
    talosctl
)
completions_bash_commands=(
    starship
)

#######################################################################################################################
#
generate_completion_bash() {
    command=$1
    source=${2:-}
    if hash $command >&/dev/null || type -a $command >&/dev/null
    then
        if [ -n "${source}" ]
        then
            echo "source <($command completion bash)" > ${complpath}/${command}${complext}
        else
            $command completion bash > ${complpath}/${command}${complext}
            chmod 644 ${complpath}/${command}${complext}
        fi
    else
        echo -e "\n$command not found"
        echo consider: rm -f ${complpath}/${command}${complext}
        return 1
    fi
}

generate_completions_bash() {
    command=$1
    if hash $command >&/dev/null || type -a $command >&/dev/null
    then
        $command completions bash > ${complpath}/${command}${complext}
        chmod 644 ${complpath}/${command}${complext}
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
    echo -n .
    generate_completion_bash $command
done
for command in ${completions_bash_commands[@]}
do
    echo -n .
    generate_completions_bash $command
done

#######################################################################################################################
#######################################################################################################################
# custom....
#
# scw
echo -n .
# https://github.com/scaleway/scaleway-cli/issues/1959#issuecomment-1451964559
command=scw
scw autocomplete script shell=bash \
    | sed -E 's#(_?)\/([^ \n]*)scw#\1scw#g' \
    > ${complpath}/scw${complext} || echo scw NOK
    chmod 644 ${complpath}/${command}${complext}

# gcloud
echo -n .
command=gcloud
echo "source $HOME/.asdf/installs/gcloud/$(gcloud version 2>/dev/null \
    | grep "Google Cloud SDK" \
    | sed 's/Google Cloud SDK //')/completion.bash.inc" \
    > ${complpath}/gcloud${complext} || echo gcloud NOK
    chmod 644 ${complpath}/${command}${complext}

# kubie
echo .
KUBIE_VERSION=$(kubie --version | sed 's/kubie /v/')
command=kubie
curl -L --no-progress-meter https://raw.githubusercontent.com/sbstp/kubie/${KUBIE_VERSION}/completion/kubie.bash \
    >  ${complpath}/kubie${complext} || echo kubie NOK
    chmod 644 ${complpath}/${command}${complext}

# golang
wget https://raw.github.com/kura/go-bash-completion/master/etc/bash_completion.d/go -O ${complpath}/go${complext}

####################

ln -vnfs $HOME/.asdf/completions/asdf.bash ${complpath}/asdf${complext}

####################
