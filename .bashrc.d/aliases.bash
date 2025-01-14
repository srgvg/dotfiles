# a
alias ai='sudo apt install'
alias ansible-hostvars='ansible -m debug -a var=hostvars[inventory_hostname]'
alias as='apt-cache search'
alias ash='apt-cache show'
alias ap='apt-cache policy'
alias aud='sudo apt update && apt list --upgradable -a'
alias audf='sudo apt update && apt list --upgradable -a && sudo apt -y full-upgrade && sudo apt -y autoremove'
alias aug='sudo apt -y upgrade'
alias auf='sudo apt -y full-upgrade && sudo apt -y autoremove'
# b
alias bi="bash-it"
# https://benaaron.dev/blog/bitwarden-cli/
alias bwu='export BW_SESSION="$(bw unlock --raw)"'
alias bwl='export BW_SESSION='
# c
if [ "${MY_WM}" = "sway" ]
then
    alias copy='wl-copy'
else
    alias copy='xclip -in -selection clipboard'
fi
# d
alias diff='diff --unified --color'
alias dL='dpkg -L'
alias dS='dpkg -S'
alias dmesg="dmesg --ctime --time-format iso --decode --nopager"

# g
#
# gcloud
alias gconfig='export CLOUDSDK_ACTIVE_CONFIG_NAME="$(gcloud config configurations list | grep -v NAME | cut -d\  -f1 | fzf)" && rm -f {$(dirname $KUBECONFIG 2>/dev/null || echo -n /tmp),$HOME/.kube}/gke_gcloud_auth_plugin_cache'
alias gproject='gcloud config set project $(gcloud projects list | grep -v PROJECT_ID | cut -d\  -f1 | fzf)'

# git
alias ga='git add'
alias gA='git add --all'
alias gap='git add --patch'
alias gdc='git diff --cached'
alias gd='git diff'
alias gdpaste="git diff | grep -v -e diff -e ^index -e '+++' -e @@ | sed -e 's@--- a/\(.*\)@--- \1@'"
alias gds='git dfs'
alias gi='git myinfo'
alias gl='git lola'
alias gls='git lol'
alias gld='git lold'
alias glt='git lolt'
#alias gpg='gpg2'
alias grep='grep --color=auto'
alias grepr='grep --line-number --initial-tab --recursive'
hash gron >&/dev/null && alias ngron="gron --ungron" ||:
alias gsmu='git submodule update'
alias gt='git tree'
alias gtt='git treet'
alias gst='git st'
alias gu='git up'
# i
alias imginfo="identify -format '-- %f -- \nType: %m\nSize: %b bytes\nResolution: %wpx x %hpx\nColors: %k'"
alias imgres="identify -format '%f: %wpx x %hpx\n'"
# j
alias jobs="jobs -l"
alias jqc="jq -C . | less -r"
# k
alias kb="kustomize build"
alias kbf="kustomize-build-flux"
alias kbfad="kustomize-build-flux-apply-dry"
if command -v /home/serge/.asdf/shims/kubecolor >/dev/null 2>&1
then
    alias k="kubecolor"
    complete -o default -F __start_kubectl k
    alias kubectl="kubecolor"
    complete -o default -F __start_kubectl kubecolor
else
    alias k="kubectl"
fi
#if hash kubecolor >&/dev/null; then
#    alias k="kubecolor"
#    alias kubectl="kubecolor"
#fi
complete -F _complete_alias k
alias k9s="k9s --logoless --all-namespaces"
alias kneat="kubectl-neat"
alias kc='kubie ctx'
alias kga="kubectl-get_all --namespace \$(kubie info ns)"
alias kgaa="kubectl-get_all"
alias kn='kubie ns'
alias konfig="kubectl konfig"
# https://fluxcd.io/flux/faq/#what-is-the-behavior-of-kustomize-used-by-flux
alias kustomize-build-flux="kustomize build --load-restrictor=LoadRestrictionsNone"
# l
alias li3='launch-screen i3jobs'
alias l='ls -lh'
alias ls='ls --color=auto'
alias locate="locate --existing --ignore-case"
# o
alias o='xdg-open'
# p
if [ "${MY_WM}" = "sway" ]
then
    alias paste='wl-paste --no-newline'
else
    alias paste='xclip -out -selection clipboard'
fi
alias pbin='pbincli send'
alias ping1="ping -c 1 "
alias ping3="ping -c 3 "
alias poweroff='sudo /sbin/poweroff'
alias psless="ps auxwwf | less"
# r
alias r="ranger"
alias rp="realpath"
# s
alias shredit='shred --verbose --iterations 5 --zero --remove'
alias showpath="readlink -f"
alias ssh-nc="ssh -S none"
alias ssh-nokey="ssh -o PubkeyAuthentication=no"
alias ssh-pw="ssh -o ControlPath=none -o PreferredAuthentications=password"
alias sysl="tail -n 200 -f /var/log/syslog"
# t
if command -v /home/serge/.asdf/shims/talosctl >/dev/null 2>&1
then
    alias t="talosctl"
fi
alias ts="ts '%Y/%m/%d-%H:%M:%.S'"
# u
# https://superuser.com/a/189068
alias unwrap="printf '\033[?7l'"
alias wrap="printf '\033[?7h'"
# v
alias v="vcsh"
alias vs="vcsh status --terse"
alias vsd="vcsh foreach diff-index --patch HEAD --color=always | less --raw-control-chars --quit-if-one-screen"
alias vsi="vcsh foreach myinfo"
#alias vsl="/usr/bin/paste -d '|' <(vcsh dot lola -n 30 | cut -d\( -f1 )  <(vcsh sdot lola -n 30 | cut -d\( -f1 ) | column -t -s \|"
alias vsl="vcsh foreach lola -n 10"
# w
alias wheredoc="locate --all --existing --follow --ignore-case /home/serge/Documents"
# y
hash yazi &>/dev/null && alias y="yazi"
hash jless &>/dev/null && alias yless="jless --mode line --yaml"

