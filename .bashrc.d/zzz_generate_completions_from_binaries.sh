#!/bin/bash
hash civo >&/dev/null &&        civo completion bash        >  $HOME/.bashrc.d/completions-civo.bash
hash doctl >&/dev/null &&       doctl completion bash       >  $HOME/.bashrc.d/completions-digitalocean.bash
hash hcloud >&/dev/null &&      hcloud completion bash      >  $HOME/.bashrc.d/completions-hetzner.bash
hash kubectl >&/dev/null &&     kubectl completion bash     >  $HOME/.bashrc.d/completions-k8s.bash
hash helm >&/dev/null &&        helm completion bash        >> $HOME/.bashrc.d/completions-k8s.bash
hash oc >&/dev/null &&          oc completion bash          >> $HOME/.bashrc.d/completions-k8s.bash
hash fluxctl >&/dev/null &&     fluxctl completion bash     >> $HOME/.bashrc.d/completions-k8s.bash
hash velero >&/dev/null &&      velero completion bash      > $HOME/.bashrc.d/completions-velero.bash
