alias | cut -d' ' -f2 | cut -d= -f1 | \
    xargs -n1 echo complete -F _complete_alias#!/usr/bin/env bash \
    > $HOME/.bashrc.d/5-complete-alias.bash


