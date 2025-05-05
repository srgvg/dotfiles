if [[ -t 0 ]]
then
    eval "$(/home/serge/bin2/mise activate bash)"
    eval "$(mise hook-env)"
else
    eval "$(mise activate --shims)"
fi
FZF_COMPLETION_TRIGGER="~~"
