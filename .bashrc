# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

#if [ -f ~/.bash_aliases ]; then
#    . ~/.bash_aliases
#fi

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    eval "`dircolors -b`"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias l='ls -AhCF'
alias ll='ls -lh'
alias lla='ls -lhA'

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
# set PATH so it includes user's private sbin if it exists
if [ -d "$HOME/sbin" ] ; then
    PATH="$HOME/sbin:$PATH"
fi
# set PATH so it includes user's extra bin2 if it exists
if [ -d "$HOME/bin2" ] ; then
    PATH="$HOME/bin2:$PATH"
fi

#####################
## my custom stuff ##
#####################

export VISUAL=vim
export EDITOR=vim

export DEBFULLNAME="Serge van Ginderachter"
export DEBEMAIL="serge@vanginderachter.be"

alias poweroff='sudo /sbin/poweroff'

alias diff='diff -u'
alias v="vcsh"
alias vs="vcsh status"
alias poweroff="sudo poweroff"

alias as='apt-cache search'
alias ash='apt-cache show'
alias ai='sudo aptitude install'
alias aud='sudo aptitude update'
alias aug='sudo aptitude full-upgrade'
alias auu='aud ; aug'
alias dL='dpkg -L'

alias swappy="/sbin/sysctl vm.swappiness"
alias sysl="tail -f /var/log/syslog"
alias ping1="ping -c 1 "
alias ping3="ping -c 3 "
alias imginfo="identify -format '-- %f -- \nType: %m\nSize: %b bytes\nResolution: %wpx x %hpx\nColors: %k'"
alias imgres="identify -format '%f: %wpx x %hpx\n'"
alias sshnc="ssh -S none"
alias sshpw="ssh -o ControlPath=none -o PreferredAuthentications=password"

alias copy='xclip -in -selection c'
alias paste='xclip -out -selection c'
alias shredit='shred --verbose --iterations 5 --zero --remove'

# git shortcuts
alias g='git'
alias ga='git add'
alias gA='git add --all'
alias gap='git add --patch'
alias gd='git diff'
alias gdc='git diff --cached'
alias gdpaste="git diff | grep -v -e diff -e ^index -e '---' -e @@"
alias gds='git dfs'
alias gi='git myinfo'
alias gls='git lol'
alias gl='git lola'
alias gu='git up'
alias gps='git svn rebase && git svn dcommit'
gurp() {
    git up && git co ${1:-devel} && git rebase && git push svg ${1:-devel}
}

# svn shortcuts
alias svn-addall='svn add `svn status | grep ?`'

# ansible
alias a='ansible'
alias ab='ansible-playbook'
alias ansible-hostvars='ansible -m debug -a var=hostvars[inventory_hostname]'
alias ahack='ps1extra ; . ~/ansible/hacking/env-setup'
alias upansible='cd /home/serge/src/ansible/ansible && git co devel && git up && git rebase  && git submodule update --init --recursive && git push svg devel'

# milieuinfo
alias acdplay="cd ~/acd; bin/acdplay"
alias acdplay2="cd ~/acd; bin/acdplay2"
alias acdplaybook="cd ~/acd; ansible-playbook -i ~/src/acd/ansible-data/inventory ~/src/acd/ansible-data/main.yml $*"
alias deploy="acdplay -t deploy"


# quick package search
dl() {
    dpkg -l | grep `for n in ${*:-^}; do echo -n " -e $n"; done`
    }

# make a dir and change to it
mkcd () {
	mkdir -v $1 && cd $1
	}

# quick character count
wcc() { echo "$*" | wc -c; }

# This will take you to the relevant part of the man page,
# so you can see the description of the switch underneath.
manswitch () {
	man $1 | less -p "^ +$2";
 	}

# Quickly CD Out Of n Directories
up() {
	local x=''
	for i in $(seq ${1:-1})
	do 	x="$x../"
	done
	cd $x
	}


# git bash & svn prompt
# http://www.opinionatedprogrammer.com/2011/01/colorful-bash-prompt-reflecting-git-status/
# https://gist.github.com/brettstimmerman/382508

PS1BAK="$PS1"

function _git_prompt() {
    local git_status="`git status -unormal 2>&1`"
    if ! [[ "$git_status" =~ Not\ a\ git\ repo ]]; then
        if [[ "$git_status" =~ nothing\ to\ commit ]]; then
            local ansi=42
        elif [[ "$git_status" =~ nothing\ added\ to\ commit\ but\ untracked\ files\ present ]]; then
            local ansi=43
        else
            local ansi=45
        fi
        if [[ "$git_status" =~ On\ branch\ ([^[:space:]]+) ]]; then
            branch=${BASH_REMATCH[1]}
        else
            # Detached HEAD.  (branch=HEAD is a faster alternative.)
            branch="(`git describe --all --contains --abbrev=4 HEAD 2> /dev/null ||
                echo HEAD`)"
        fi
        echo -n '\[\e[0;37;'"$ansi"';1m\]'"[${branch//[aeiou]}]"'\[\e[0m\] '
    fi
}


function _prompt_command() {
    local GP=$(_git_prompt)
    PS1="${GP}${PS1BAK}"
}

PROMPT_COMMAND=_prompt_command

# EXTRA PS stuff
PS1BAK2="$PS1BAK"
ps1extra() {
    PS1EXTRA="\[\e[0;37;88;1m\][A]\[\e[0m\]"
    PS1BAK="${PS1EXTRA} ${PS1BAK2}"
    }


### git hub support
#
#eval $(which hub >>/dev/null && hub alias -s bash)
#
## hub tab-completion script for bash.
## This script complements the completion script that ships with git.
#
## Check that git tab completion is available
#if declare -F _git > /dev/null; then
#  # Duplicate and rename the 'list_all_commands' function
#  eval "$(declare -f __git_list_all_commands | \
#        sed 's/__git_list_all_commands/__git_list_all_commands_without_hub/')"
#
#  # Wrap the 'list_all_commands' function with extra hub commands
#  __git_list_all_commands() {
#    cat <<-EOF
#alias
#pull-request
#fork
#create
#browse
#compare
#EOF
#    __git_list_all_commands_without_hub
#  }
#
#  # Ensure cached commands are cleared
#  __git_all_commands=""
#fi
#

## SSH Agent
#export SSH_ASKPASS=`which ssh-askpass`
if [   X$HOSTNAME = Xgoldorak \
    -o X$HOSTNAME = Xcyberlab ]
then
    [ -x `which keychain` ]  && \
        eval `keychain --lockwait 300 --quiet \
        --inherit any --agents ssh,gpg \
        --eval ~/.ssh/id_rsa ~/.ssh/id_rsa2`
fi
