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
    civo
    doctl
    flux
    helm
    hcloud
    kind
    oc
    velero
    havener
    kubescape
    kubecm
    kustomize
    cmctl
    datree
    k9s
    arkade
    krew
    argocd
    mizu
    talosctl
    clusterctl
    nova
    kanctl
    kando
    kind
    kubectl-plugin_completion
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
EOF
#
KUBIE_VERSION=$(kubie --version | sed 's/kubie /v/')
curl --no-progress-meter https://raw.githubusercontent.com/sbstp/kubie/${KUBIE_VERSION}/completion/kubie.bash \
                                                                    >  ${complpath}/kubie${complext}
#
ln -nfs $HOME/.asdf/completions/asdf.bash ${complpath}/asdf${complext}
