#!/bin/sh

# source: https://gist.github.com/subnut/f897726d3e4a3b307162fdde2fe88cc5

# Copyright 2022 Subhaditya Nath
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

command -v jq >/dev/null || {
	echo >&2 jq not found
	echo >&2 Please install jq before using this utility
	exit 1
}

TREE="$(swaymsg -t get_tree)"
COORDINATES="$(printf '%s\n' "$TREE" |
	jq -r '.. | select(.pid? and .visible?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' |
	slurp -B 000000 -f '%x,%y')"

EXITCODE=$?
[ $EXITCODE -eq 0 ] ||
	exit $EXITCODE

X=${COORDINATES%,*}
Y=${COORDINATES#*,}
printf '%s\n' "$TREE" | jq ".. | select(.pid? and .visible?) | select(.rect.x == $X and .rect.y == $Y)"
