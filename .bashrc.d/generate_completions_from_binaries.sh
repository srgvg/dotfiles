#!/bin/bash -x

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: nil
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=true:

hash civo >&/dev/null &&        civo completion bash        >  $HOME/.bashrc.d/completions-generated-civo.bash
hash doctl >&/dev/null &&       doctl completion bash       >  $HOME/.bashrc.d/completions-generated-digitalocean.bash
hash flux >&/dev/null &&        flux completion bash        >  $HOME/.bashrc.d/completions-generated-flux.bash
hash helm >&/dev/null &&        helm completion bash        >  $HOME/.bashrc.d/completions-generated-helm.bash
hash hcloud >&/dev/null &&      hcloud completion bash      >  $HOME/.bashrc.d/completions-generated-hetzner.bash
hash kind >&/dev/null &&        kind completion bash        >  $HOME/.bashrc.d/completions-generated-kind.bash
hash kubectl >&/dev/null &&     kubectl completion bash     >  $HOME/.bashrc.d/completions-generated-kubectl.bash
hash oc >&/dev/null &&          oc completion bash          >  $HOME/.bashrc.d/completions-generated-oc.bash
hash scw >&/dev/null && scw autocomplete script shell=bash  >  $HOME/.bashrc.d/completions-generated-scw.bash
hash starship >&/dev/null &&    starship completions        >  $HOME/.bashrc.d/completions-generated-starship.bash
hash velero >&/dev/null &&      velero completion bash      >  $HOME/.bashrc.d/completions-generated-velero.bash
hash havener >&/dev/null &&     havener completion bash     >  $HOME/.bashrc.d/completions-generated-havener.bash
hash kubescape >&/dev/null &&   kubescape completion bash   >  $HOME/.bashrc.d/completions-generated-kubescape.bash
hash kubecm >&/dev/null &&      kubecm completion bash      >  $HOME/.bashrc.d/completions-generated-kubecm.bash

hash /home/serge/.arkade/bin/kustomize >&/dev/null && /home/serge/.arkade/bin/kustomize completion bash >> $HOME/.bashrc.d/completions-kustomize.bash

echo "# autocomplete for kubecolor
complete -o default -F __start_kubectl kubecolor"           >> $HOME/.bashrc.d/completions-generated-kubectl.bash

KUBIE_VERSION=$(kubie --version | sed 's/kubie /v/')
curl --no-progress-meter https://raw.githubusercontent.com/sbstp/kubie/${KUBIE_VERSION}/completion/kubie.bash \
                                                            >  $HOME/.bashrc.d/completions-generated-kubie.bash
