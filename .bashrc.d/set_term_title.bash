function set_win_title() {
  echo -ne "\033]2;[$(tty | cut -b 6-) ${PWD}] $(history 1 | sed "s/^[ ]*[0-9]*[ ]*//g") \007"
}
starship_precmd_user_func="set_win_title"
# set_win_title
#trap set_win_title DEBUG
