# The search path for the cd command. This is a colon-separated list of directories in which the
# shell looks for destination directories specified by the cd command.
CDPATH=".:~/src:~/Documents:~"

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignorespace

# HISTIGNORE is a colon-separated list of patterns used to decide which
# command lines should be saved in the history file.
# Don’t save ls, ps and history commands:
#HISTIGNORE="ls:ps:history"
HISTIGNORE="history"

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
# The number of commands to remember in the command history (see HISTORY below).  If the value  is
# 0,  commands  are  not saved in the history list.  Numeric values less than zero result in every
# command being saved on the history list (there is no limit).  The shell sets the  default  value
# to 500 after reading any startup files.
HISTSIZE=-1
# The maximum number of lines contained in the history file.  When this  variable  is  assigned  a
# value, the history file is truncated, if necessary, to contain no more than that number of lines
# by removing the oldest entries.  The history file is also truncated to this size  after  writing
# it  when a shell exits.  If the value is 0, the history file is truncated to zero size.  Non-nu‐
# meric values and numeric values less than zero inhibit truncation.  The shell sets  the  default
# value to the value of HISTSIZE after reading any startup files.
HISTFILESIZE=500000

#HISTTIMEFORMAT="%h %d %H:%M:%S "
HISTTIMEFORMAT="%F %T "

# append to the history file, don't overwrite it
shopt -s histappend

# Store multi-line commands in one history entry:
shopt -s cmdhist

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

