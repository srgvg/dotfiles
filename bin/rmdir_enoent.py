#!/usr/bin/env python3
"""Proposed rmdir sink: ignore ENOENT, preserve every other error by default.

Not installed on goldorak. Keep the original producer/selection policy.
Enable -p or --ignore-fail-on-non-empty ONLY if already used by that policy.
No recursive deletion, file unlinking, traversal, or pre-check. Parent ascent
is opt-in compatibility with an existing -p invocation.
"""
import argparse
import errno
import os
import sys


def remove_path(path, *, parents=False, ignore_nonempty=False, verbose=False):
    while True:
        try:
            os.rmdir(path)
        except OSError as error:
            if error.errno == errno.ENOENT:
                return True  # Already gone; do not climb any further.
            if ignore_nonempty and error.errno in (errno.ENOTEMPTY, errno.EEXIST):
                return True  # Opt-in compatibility with the existing policy.
            name = errno.errorcode.get(error.errno, str(error.errno))
            print(f"rmdir: failed to remove {path!r}: [{name}] {error.strerror}",
                  file=sys.stderr)
            return False
        if verbose:
            print(f"rmdir: removed directory {path!r}", flush=True)
        if not parents:
            return True
        # Lexical parent only; never resolve symlinks or normalize '..'.
        parent = os.path.dirname(path.rstrip("/")).rstrip("/")
        if not parent:
            return True
        path = parent


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-p', '--parents', action='store_true')
    parser.add_argument('-v', '--verbose', action='store_true')
    parser.add_argument('--ignore-fail-on-non-empty', action='store_true')
    parser.add_argument('directories', nargs='+')
    args = parser.parse_args(argv)
    failed = False
    for directory in args.directories:
        ok = remove_path(directory, parents=args.parents,
                         ignore_nonempty=args.ignore_fail_on_non_empty,
                         verbose=args.verbose)
        if not ok:
            failed = True  # A later success or ENOENT cannot erase a failure.
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
