if [[ -t 0 ]]
then
    eval "$(/home/serge/bin2/mise activate bash)"
else
     eval "$(mise activate --shims)"
fi
FZF_COMPLETION_TRIGGER="~~"
