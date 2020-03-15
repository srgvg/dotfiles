#
## PATH #
#

# add sbin paths (not default in Debian)
pathmunge /usr/local/sbin:/usr/sbin:/sbin

## GOPATH
GOPATH=$HOME/go
GOBINPATH="${GOPATH//://bin:}/bin"
gobinpath="${GOBINPATH/$HOME\/}"
export PYENV_ROOT="$HOME/.pyenv"'

## set PATH so it includes various user's private bin dirs
_binpaths="${GOBINPATH} bin bins bin2"

_bin2paths="$(cd $HOME; find bin2/ -mindepth 1 -maxdepth 1  -type d 2>/dev/null | sort -r | xargs)"
if [ -n "${_bin2paths}" ]
then
    _binpaths="${_binpaths} ${_bin2paths}"
fi
unset _bin2paths

_binpaths="$_binpaths .local/bin"

for _p in ${_binpaths}
do
  _p="$HOME/${_p/$HOME\/}"
  if [ -d "${_p}" ]
  then
    pathmunge "${_p}"
  fi
done

unset _binpaths
unset _p

pathmunge $HOME/.screenlayout after
