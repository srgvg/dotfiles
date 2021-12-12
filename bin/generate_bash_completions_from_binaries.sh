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

hash civo >&/dev/null &&        civo completion bash                > ${complpath}/civo${complext}
hash doctl >&/dev/null &&       doctl completion bash               > ${complpath}/digitalocean${complext}
hash flux >&/dev/null &&        flux completion bash                > ${complpath}/flux${complext}
hash helm >&/dev/null &&        helm completion bash                > ${complpath}/helm${complext}
hash hcloud >&/dev/null &&      hcloud completion bash              > ${complpath}/hetzner${complext}
hash kind >&/dev/null &&        kind completion bash                > ${complpath}/kind${complext}
hash kubectl >&/dev/null &&     kubectl completion bash             > ${complpath}/kubectl${complext}
hash oc >&/dev/null &&          oc completion bash                  > ${complpath}/oc${complext}
hash scw >&/dev/null &&         scw autocomplete script shell=bash  > ${complpath}/scw${complext}
hash starship >&/dev/null &&    starship completions                > ${complpath}/starship${complext}
hash velero >&/dev/null &&      velero completion bash              > ${complpath}/velero${complext}
hash havener >&/dev/null &&     havener completion bash             > ${complpath}/havener${complext}
hash kubescape >&/dev/null &&   kubescape completion bash           > ${complpath}/kubescape${complext}
hash kubecm >&/dev/null &&      kubecm completion bash              > ${complpath}/kubecm${complext}
hash kustomize >&/dev/null &&   kustomize completion bash           > ${complpath}/kustomize${complext}
hash cmctl >&/dev/null &&       cmctl completion bash               > ${complpath}/cmctl${complext}
hash datree >&/dev/null &&      datree completion bash              > ${complpath}/datree${complext}
hash k9s >&/dev/null &&         k9s completion bash                 > ${complpath}/k9s${complext}

cat                                                                >> ${complpath}/kubectl${complext}  <<- EOF
# autocomplete for kubecolor
complete -o default -F __start_kubectl kubecolor
EOF

KUBIE_VERSION=$(kubie --version | sed 's/kubie /v/')
curl --no-progress-meter https://raw.githubusercontent.com/sbstp/kubie/${KUBIE_VERSION}/completion/kubie.bash \
                                                                    >  ${complpath}/kubie${complext}
