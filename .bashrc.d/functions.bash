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

function aswitch() {
	# switch ansible versions 1-2
	pushd ~/ansible
	currentrev=$(git describe --tags)
	if [[ $currentrev =~ .*v1.* ]]
	then
		git co v2.1.0.0-1
		git submodule update
		rm -rf v2/
		# shellcheck disable=SC2046
		rm $(git ls-files --others)
	elif [[ $currentrev =~ .*v2.* ]]
	then
		git co v1.9.6-1
		git submodule update
		# shellcheck disable=SC2046
		rm $(git ls-files --others)
	fi
	# shellcheck disable=SC1091
	source hacking/env-setup >/dev/null 2>&1
	popd
}

function dl() {
	# quick package search
	# shellcheck disable=SC2046
	dpkg -l | grep $(for n in ${*:-^}; do echo -n " -e $n"; done)
}

function ka() {
	kubectl $* --all-namespaces
}

function manswitch() {
  # This will take you to the relevant part of the man page,
  # so you can see the description of the switch underneath.
  man $1 | less -p "^ +$2";
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

# https://gist.github.com/premek/6e70446cfc913d3c929d7cdbfe896fef
# Usage: mv oldfilename
# If you call mv without the second parameter it will prompt you to edit the filename on command line.
# Original mv is called when it's called with more than one argument.
# It's useful when you want to change just a few letters in a long name.
#
# Also see:
# - imv from renameutils
# - Ctrl-W Ctrl-Y Ctrl-Y (cut last word, paste, paste)
function mv() {
  if [ "$#" -ne 1 ] || [ ! -e "$1" ]; then
    command mv "$@"
    return
  fi

  read -ei "$1" newfilename
  command mv -v -- "$1" "$newfilename"
}

function mkcd() {
	if [ "$#" -eq 1 ]; then
		mkdir -pv $1
		cd $1
	else
		echo missing target dir to create
	fi
}

function kc() {
	kubie ctx $*
}
