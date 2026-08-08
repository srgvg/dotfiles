#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT="${GIT_CHANGE_WORKTREE_BIN:-$HOME/bin/git-change-worktree}"
FUNCTIONS_FILE="${GWT_FUNCTIONS_FILE:-$HOME/.bashrc.d/z86_functions.bash}"
TEST_ROOT=$(mktemp -d -t git-change-worktree-test.XXXXXX)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_eq() {
	local expected=$1 actual=$2 message=$3
	[[ "$actual" == "$expected" ]] ||
		fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
	local haystack=$1 needle=$2 message=$3
	[[ "$haystack" == *"$needle"* ]] ||
		fail "$message (missing '$needle')"
}

assert_fails() {
	local message=$1
	shift
	if "$@" >/dev/null 2>&1; then
		fail "$message"
	fi
}

[[ -x "$SCRIPT" ]] || fail "helper is not executable: $SCRIPT"

repo="$TEST_ROOT/repo space"
git init -q -b trunk "$repo"
git -C "$repo" config user.name Test
git -C "$repo" config user.email test@example.invalid
printf 'base\n' >"$repo/file.txt"
git -C "$repo" add file.txt
git -C "$repo" commit -qm base

prompt=$(git -C "$repo" change-worktree prompt)
assert_eq "" "$prompt" "main checkout without linked worktrees has no prompt marker"

feature_path=$(git -C "$repo" change-worktree new feat/foo)
assert_eq "$TEST_ROOT/repo space-feat+foo" "$feature_path" "slash branch uses sibling plus slug"
assert_eq "feat/foo" "$(git -C "$feature_path" branch --show-current)" "new branch is checked out"
assert_eq "$(git -C "$repo" rev-parse HEAD)" "$(git -C "$feature_path" rev-parse HEAD)" "new branch starts at current HEAD"

assert_eq "$feature_path" "$(git -C "$repo" change-worktree feat/foo)" "branch shorthand prints its path"
assert_eq "$feature_path" "$(git -C "$repo" change-worktree path feat/foo)" "path resolves an exact branch"
assert_eq "$feature_path" "$(git -C "$repo" change-worktree new feat/foo)" "new enters an existing worktree"
assert_eq "$repo" "$(git -C "$feature_path" change-worktree head)" "head prints the original checkout"
assert_eq " | wt:1" "$(git -C "$repo" change-worktree prompt)" "main checkout reports linked count"
assert_eq " | wt" "$(git -C "$feature_path" change-worktree prompt)" "linked checkout reports its kind"

listing=$(git -C "$repo" change-worktree)
assert_contains "$listing" $'trunk\t' "bare command lists the main branch"
assert_contains "$listing" $'feat/foo\t' "bare command lists linked branches"
assert_eq "$listing" "$(git -C "$repo" change-worktree list)" "list subcommand matches bare command"

git -C "$repo" branch spare
spare_path=$(git -C "$repo" change-worktree new spare)
assert_eq "$TEST_ROOT/repo space-spare" "$spare_path" "existing unattached branch gets a sibling checkout"
assert_eq "spare" "$(git -C "$spare_path" branch --show-current)" "existing branch is attached"

main_path=$(git -C "$repo" change-worktree new main)
assert_eq "$main_path" "$(git -C "$repo" change-worktree main)" "main is treated as a branch name"
head_branch_path=$(git -C "$repo" change-worktree new head)
assert_eq "$head_branch_path" "$(git -C "$repo" change-worktree path head)" "path disambiguates branch head"
assert_eq "$repo" "$(git -C "$head_branch_path" change-worktree head)" "head command still returns the original checkout"

alias_listing=$(git -C "$repo" wt)
assert_contains "$alias_listing" $'feat/foo\t' "git wt resolves to the helper"
assert_fails "removed git wtl alias must not resolve" git -C "$repo" wtl

assert_fails "unknown branch must fail instead of creating" git -C "$repo" change-worktree missing
assert_fails "slug collision must fail" git -C "$repo" change-worktree new feat+foo

fake_bin="$TEST_ROOT/fake-bin"
mkdir "$fake_bin"
cat >"$fake_bin/fzf" <<'EOF'
#!/usr/bin/env bash
head -n 1
EOF
chmod +x "$fake_bin/fzf"
selected=$(PATH="$fake_bin:$PATH" git -C "$repo" change-worktree path)
assert_eq "$repo" "$selected" "fzf selection returns the selected record path"

cat >"$fake_bin/fzf" <<'EOF'
#!/usr/bin/env bash
exit 130
EOF
chmod +x "$fake_bin/fzf"
assert_fails "fzf cancellation must return non-zero" env PATH="$fake_bin:$PATH" git -C "$repo" change-worktree path

remove_path=$(git -C "$repo" change-worktree new remove/me)
printf 'dirty\n' >"$remove_path/dirty.txt"
assert_fails "dirty worktree removal must fail" bash -c "printf 'y\\n' | git -C \"$repo\" change-worktree remove remove/me"
[[ -d "$remove_path" ]] || fail "dirty worktree was removed"
rm "$remove_path/dirty.txt"

printf 'n\n' | git -C "$repo" change-worktree remove remove/me >/dev/null
[[ -d "$remove_path" ]] || fail "declined removal removed the worktree"
printf 'y\n' | git -C "$repo" change-worktree remove remove/me >/dev/null
[[ ! -e "$remove_path" ]] || fail "confirmed clean worktree still exists"
git -C "$repo" show-ref --verify --quiet refs/heads/remove/me || fail "removal deleted the branch"

locked_path=$(git -C "$repo" change-worktree new locked)
git -C "$repo" worktree lock --reason test "$locked_path"
assert_fails "locked worktree removal must fail" bash -c "printf 'y\\n' | git -C \"$repo\" change-worktree remove locked"
git -C "$repo" worktree unlock "$locked_path"

plain_locked_path=$(git -C "$repo" change-worktree new plain-locked)
git -C "$repo" worktree lock "$plain_locked_path"
plain_locked_error=$(bash -c "printf 'y\\n' | git -C \"$repo\" change-worktree remove plain-locked" 2>&1 || true)
assert_contains "$plain_locked_error" "refusing locked worktree" "lock without a reason is detected before removal"
git -C "$repo" worktree unlock "$plain_locked_path"

arbitrary_path="$TEST_ROOT/arbitrary"
git -C "$repo" branch arbitrary
git -C "$repo" worktree add -q "$arbitrary_path" arbitrary
assert_fails "non-sibling worktree removal must fail" bash -c "printf 'y\\n' | git -C \"$repo\" change-worktree remove arbitrary"

assert_fails "current worktree removal must fail" bash -c "printf 'y\\n' | git -C \"$spare_path\" change-worktree remove spare"
assert_fails "original checkout removal must fail" bash -c "printf 'y\\n' | git -C \"$repo\" change-worktree remove trunk"

bare_repo="$TEST_ROOT/bare.git"
bare_link="$TEST_ROOT/bare-link"
git clone -q --bare "$repo" "$bare_repo"
git -C "$bare_repo" worktree add -q "$bare_link" trunk
assert_fails "bare repository has no original checkout" git -C "$bare_link" change-worktree head
assert_fails "bare repository cannot create sibling worktrees" git -C "$bare_link" change-worktree new bare-new

shell_pwd=$(PATH="$HOME/bin:$PATH" FUNCTIONS_FILE="$FUNCTIONS_FILE" REPO="$repo" bash --noprofile --norc -c '
	set -e
	source "$FUNCTIONS_FILE"
	cd "$REPO"
	gwt feat/foo
	pwd
')
assert_eq "$feature_path" "$shell_pwd" "gwt changes the calling shell directory"

completion=$(REPO="$repo" FUNCTIONS_FILE="$FUNCTIONS_FILE" bash --noprofile --norc -c '
	set -e
	source "$FUNCTIONS_FILE"
	cd "$REPO"
	COMP_WORDS=(gwt fe)
	COMP_CWORD=1
	_gwt_completion
	printf "%s\n" "${COMPREPLY[@]}"
')
assert_contains "$completion" "feat/foo" "gwt completes registered branches"

git_completion=$(REPO="$repo" FUNCTIONS_FILE="$FUNCTIONS_FILE" bash --noprofile --norc -c '
	set -e
	source "$HOME/.bashrc.d/completions-git.bash"
	source "$FUNCTIONS_FILE"
	cd "$REPO"
	words=(git change-worktree p)
	cword=2
	cur=p
	prev=change-worktree
	COMPREPLY=()
	_git_change_worktree
	printf "%s\n" "${COMPREPLY[@]}"
')
assert_contains "$git_completion" "path" "git wt completes helper subcommands"

printf 'PASS: git-change-worktree integration\n'
