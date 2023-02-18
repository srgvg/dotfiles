#!/bin/bash -x

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
    kubescape
    kustomize
    mizu
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
    generate_completion_bash $command
done
for command in ${completions_bash_commands[@]}
do
    generate_completions_bash $command
done

#######################################################################################################################
#
# custom....
scw autocomplete script shell=bash  > ${complpath}/scw${complext}
#
hash kubecolor >&/dev/null && cat > ${complpath}/kubecolor${complext} <<- EOF
# autocomplete for kubecolor, k alias
source ${complpath}/kubectl${complext}
complete -o default -F __start_kubectl kubecolor
complete -o default -F __start_kubectl k
EOF
#
KUBIE_VERSION=$(kubie --version | sed 's/kubie /v/')
curl --no-progress-meter https://raw.githubusercontent.com/sbstp/kubie/${KUBIE_VERSION}/completion/kubie.bash \
                                                                    >  ${complpath}/kubie${complext}
#
ln -nfs $HOME/.asdf/completions/asdf.bash ${complpath}/asdf${complext}

####################

# gcloud
echo "source $HOME/.asdf/installs/gcloud/$(gcloud version 2>/dev/null | grep "Google Cloud SDK" | sed 's/Google Cloud SDK //')/completion.bash.inc" > ${complpath}/gcloud${complext}
