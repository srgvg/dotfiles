for myalias in $(sed 's/^alias //' $HOME/.bashrc.d/aliases.bash | cut -d= -f1 | sort)
do
  complete -F _complete_alias ${myalias}
done
