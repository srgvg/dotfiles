# a
alias ahack='source ~/ansible/hacking/env-setup >/dev/null 2>&1'
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
#g
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
alias grep='grep --color=auto'
alias grepr='grep --line-number --initial-tab --recursive'
hash gron >&/dev/null && alias ngron="gron --ungron"
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
alias k="kubectl"
#if hash kubecolor >&/dev/null; then
#    alias k="kubecolor"
#    alias kubectl="kubecolor"
#fi
complete -F _complete_alias k
alias kailns="kail --current-ns"
alias kneat="kubectl-neat"
alias kc='kubie ctx'
alias kga="kubectl-get_all --namespace \$(kubie info ns)"
alias kgaa="kubectl-get_all"
alias kn='kubie ns'
alias krew='kubectl-krew'
alias ksw="switcher"
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
    alias paste='wl-paste --no-newline --primary'
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
# v
alias vs="vcsh status"
alias v="vcsh"
# w
alias wheredoc="locate --all --existing --follow --ignore-case /home/serge/Documents"
