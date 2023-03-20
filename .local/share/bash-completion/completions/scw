_scw() {
	_get_comp_words_by_ref -n = cword words

	output=$(scw autocomplete complete bash -- "$COMP_LINE" "$cword" "${words[@]}")
	COMPREPLY=($output)
	# apply compopt option and ignore failure for older bash versions
	[[ $COMPREPLY == *= ]] && compopt -o nospace 2> /dev/null || true
	return
}
complete -F _scw scw
