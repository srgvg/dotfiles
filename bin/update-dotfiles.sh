#!/bin/bash

dotfiles=~/dotfiles/
cd ${dotfiles}

grepify() {
	echo -n " -e updatelinks "
	for pattern in $*
	do
		echo -n " -e $pattern "
	done
}

listfiles() {
	local base=${1}

	( cd ${dotfiles}${base}; ls -A | ${grep} )
}

updatelink() {
	local base=${1}
	local file=${2}

	[ -d ~/${base} ] || mkdir -vp ~/${base}
	ln -nvfs $( readlink -en ${dotfiles}${base}${file} ) $(readlink -en ~/${base} )
}

updatefiles() {
	local base=${1}
	shift
	grep=" grep -v $(grepify $*)"
	local files=$( listfiles ${base} )

	for file in ${files}
	do
		updatelink ${base} ${file}
	done
}



updatefiles ./ .config .local src var
updatefiles .local/share/
updatefiles .config/
for p in src/*/.git/
do
	updatefiles $p
done
