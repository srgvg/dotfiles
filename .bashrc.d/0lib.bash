
# prevent duplicate directories in you PATH variable
# pathmunge /path/to/dir is equivalent to PATH=/path/to/dir:$PATH
# pathmunge /path/to/dir after is equivalent to PATH=$PATH:/path/to/dir
if ! type pathmunge > /dev/null 2>&1
then
  function pathmunge () {

    if ! [[ $PATH =~ (^|:)$1($|:) ]] ; then
      if [ "$2" = "after" ] ; then
        export PATH=$PATH:$1
      else
        export PATH=$1:$PATH
      fi
    fi
  }
fi

function _printline() {
	local _char=$1
	printf "%`tput cols`s" | tr " " "$_char"
}

function k8s_completions() {
	hash kubectl >&/dev/null && source <(kubectl completion bash)
	hash helm >&/dev/null && source <(helm completion bash)
	hash oc >&/dev/null && source <(oc completion bash)
}
