#!/bin/bash
# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

function _printline() {
	local _char=$1
	printf "%`tput cols`s" | tr " " "$_char"
}


function apk() {
	local notfirst=""
	for package in $*
	do
		if [ -n "$notfirst" ]; then
			echo
			_printline "="
			echo
		else
			notfirst=yes
		fi
		# show extended package information
		echo
		# shellcheck disable=SC2048
		apt-cache show $package
		_printline "-"
		# shellcheck disable=SC2048
		apt-cache policy $package
		_printline "-"
		# shellcheck disable=SC2048
		apt-cache showpkg $package
	done | less --quit-if-one-screen --no-init
}


function asdf-installatest() {
	plugin=${1:-}
	[ -z "${plugin}" ] && echo "No plugin given" && return 1

	echo asdf plugin add $plugin
	asdf plugin add $plugin
    echo asdf install $plugin latest
    asdf install $plugin latest
	echo asdf global $plugin latest
	asdf global $plugin latest
}

function b64() {
	echo -n $* | base64 -w 0
}
alias b=b64

function b64d() {
	echo -n $* | base64 -d
}
alias bd=b64d

function dl() {
	# quick package search
	# shellcheck disable=SC2046
	dpkg -l | grep -i $(for n in ${*:-^}; do echo -n " -e $n"; done)
}

function gcloud-project() {
	if [ -n "${1:-}" ]; then
		gcloud config set project ${1}
	else
		gcloud projects list
	fi
}
function cohdi() {
	chmod -v -x "$(realpath $(git rev-parse --show-cdup))/.git/hooks/pre-commit"
}
function cohen() {
	chmod -v +x "$(realpath $(git rev-parse --show-cdup))/.git/hooks/pre-commit"
}

function hl() {
	local pattern
	local parameters
	parameters=()
	for pattern in "$@"
	do
		parameters+=(--regexp "${pattern}|^")
	done
	grep --color --ignore-case --extended-regexp "${parameters[@]}"
}
function ka() {
	#kubectl $* --all-namespaces
	k $* --all-namespaces
}

function kustomize-build-flux-apply-dry() {
	kustomize-flux-build ${1:-./} | kubectl apply --server-side --dry-run=server -f-
}

function mkcd() {
	if [ "$#" -eq 1 ]; then
		mkdir -pv $1
		cd $1
	else
		echo missing target dir to create
	fi
}

function manswitch() {
  # This will take you to the relevant part of the man page,
  # so you can see the description of the switch underneath.
  man $1 | less -p "^ +$2";
}

function mv() {
# https://gist.github.com/premek/6e70446cfc913d3c929d7cdbfe896fef
# Usage: mv oldfilename
# If you call mv without the second parameter it will prompt you to edit the filename on command line.
# Original mv is called when it's called with more than one argument.
# It's useful when you want to change just a few letters in a long name.
#
# Also see:
# - imv from renameutils
# - Ctrl-W Ctrl-Y Ctrl-Y (cut last word, paste, paste)
  if [ "$#" -ne 1 ] || [ ! -e "$1" ]; then
    command mv "$@"
    return
  fi

  read -ei "$1" newfilename
  command mv -v -- "$1" "$newfilename"
}

function up() {
	# Quickly CD Out Of n Directories
	local x=''
	# shellcheck disable=SC2034
	for i in $(seq ${1:-1})
	do	x="$x../"
		done
	# shellcheck disable=SC2164
	cd $x
}

function vim-debuglog() {
	# shellcheck disable=SC2048
	vi -V9$HOME/logs/scripts/VIMDEBUG.LOG $*
}

function wcc() {
  # quick character count
  local string="${*}"
  echo "${#string}"
}


