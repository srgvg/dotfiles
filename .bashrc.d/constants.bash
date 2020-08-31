# editor
export VISUAL=vim
export EDITOR=vim

# Debian packaging
export DEBFULLNAME="Serge van Ginderachter"
export DEBEMAIL="serge@vanginderachter.be"

export GIT_COMMITTER_NAME=$(git config --get user.name)
export GIT_COMMITTER_EMAIL=$(git config --get user.email)

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Avoid "Double quote to prevent globbing and word splitting."
export SHELLCHECK_OPTS='--shell=bash --exclude=SC2086'

# my defaults for mtr
export MTR_OPTIONS="--show-ips --ipinfo 2 --order LDRSNBAWVGJMXI"

export LANGUAGE="en_US:en"
export LC_MESSAGES="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export LC_COLLATE="en_US.UTF-8"
