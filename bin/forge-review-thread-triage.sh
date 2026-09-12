#!/usr/bin/env bash
# forge-review-thread-triage.sh -- gate A6 PR/MR comment and review-thread
# triage, for one GitHub PR or GitLab MR.
#
# GitHub: uses `gh api graphql` against GitHub's PullRequestReviewThread
# schema (three connections: comments, reviews, reviewThreads).
# GitLab: uses `glab api graphql` against GitLab's Discussion/Note schema
# (one connection: discussions, folding comments/reviews/threads together).
# The two halves are deliberately not unified behind a shared abstraction --
# GitLab's one-connection model and missing totalCount are different enough
# from GitHub's three-connection model that forcing a common code path would
# obscure both.
#
# Usage:
#   forge-review-thread-triage.sh --self-test
#   forge-review-thread-triage.sh <owner> <repo> <pr-number>
#   forge-review-thread-triage.sh --resolve <thread-id>
#   forge-review-thread-triage.sh --gitlab <group/project> <mr-iid>
#   forge-review-thread-triage.sh --gitlab --resolve <discussion-id>
#
# Exit codes (triage/gl_triage): 0 = clean, 1 = unresolved thread(s)/
# discussion(s) present (expected triage work -- callers should NOT retry
# this as a forge-unreachable condition), 2 = internal failure (bad
# repo/number/project, GraphQL error, a raw gh/glab invocation failure, or
# a truncated-despite-exhaustion bug -- callers SHOULD treat this like any
# other failed forge call).
# Exit codes (resolve_thread/gl_resolve_discussion): 0 = resolve confirmed,
# 1 = the mutation did not confirm resolved -- a real failure, retry or
# report, never silently accepted.
set -euo pipefail

die_missing() {
    local tool="$1" mode="$2"
    echo "ERROR: '$tool' not found on PATH -- required for $mode" >&2
    exit 127
}

require_jq() {
    command -v jq >/dev/null 2>&1 || die_missing jq "every mode, including --self-test"
}

require_gh() {
    command -v gh >/dev/null 2>&1 || die_missing gh "GitHub-mode invocation"
}

require_glab() {
    command -v glab >/dev/null 2>&1 || die_missing glab "--gitlab-mode invocation"
}

# check_connection_truncation NAME JSON
# Pure function: given one GraphQL connection object ({pageInfo, nodes} and
# optionally totalCount), prints "TRUNCATED <name> total=<n> fetched=<m>
# endCursor=<c>" and returns 1 if the page did not cover every result, else
# prints "COMPLETE <name> total=<n>" and returns 0. Never touches the
# network -- this is what makes it self-testable against fixture JSON.
#
# A connection with no totalCount field (GitLab's DiscussionConnection has
# none -- confirmed live, querying `count` errors "Field 'count' doesn't
# exist on type 'DiscussionConnection'") reads total as the string "null"
# via jq -r; the fetched-vs-total comparison is then skipped and only
# hasNextPage is checked, which is the only signal that connection shape
# can ever offer.
check_connection_truncation() {
    local name="$1" json="$2"
    local total has_next end_cursor fetched
    total=$(jq -r '.totalCount' <<<"$json")
    has_next=$(jq -r '.pageInfo.hasNextPage' <<<"$json")
    end_cursor=$(jq -r '.pageInfo.endCursor' <<<"$json")
    fetched=$(jq -r '.nodes | length' <<<"$json")
    if [[ "$has_next" == "true" ]]; then
        printf 'TRUNCATED %s total=%s fetched=%s endCursor=%s\n' "$name" "$total" "$fetched" "$end_cursor"
        return 1
    fi
    if [[ "$total" != "null" && "$total" != "$fetched" ]]; then
        printf 'TRUNCATED %s total=%s fetched=%s endCursor=%s (hasNextPage=false but counts disagree)\n' \
            "$name" "$total" "$fetched" "$end_cursor"
        return 1
    fi
    printf 'COMPLETE %s total=%s\n' "$name" "$total"
    return 0
}

self_test() {
    local pass=0 fail=0 out rc

    # Case 1: hasNextPage=true must be flagged TRUNCATED, even though nodes
    # were returned -- this is the defect class that produced a false
    # "nothing unresolved" read on a 106-thread PR with 6 genuinely
    # unresolved past a smaller page.
    out=$(check_connection_truncation reviewThreads \
        '{"totalCount":106,"pageInfo":{"hasNextPage":true,"endCursor":"abc123"},"nodes":[{"id":"1"},{"id":"2"}]}') \
        || true
    if [[ "$out" == "TRUNCATED reviewThreads total=106 fetched=2 endCursor=abc123" ]]; then
        echo "PASS: truncated connection detected"; pass=$((pass + 1))
    else
        echo "FAIL: truncated connection not detected, got: $out"; fail=$((fail + 1))
    fi

    # Case 2: hasNextPage=false with totalCount == fetched count is COMPLETE.
    out=$(check_connection_truncation reviewThreads \
        '{"totalCount":2,"pageInfo":{"hasNextPage":false,"endCursor":"xyz"},"nodes":[{"id":"1"},{"id":"2"}]}') \
        || true
    if [[ "$out" == "COMPLETE reviewThreads total=2" ]]; then
        echo "PASS: complete connection reported clean"; pass=$((pass + 1))
    else
        echo "FAIL: complete connection misreported, got: $out"; fail=$((fail + 1))
    fi

    # Case 3: an empty connection (a draft PR seconds old) is COMPLETE, not
    # skipped -- a fresh PR with zero comments must still be reported, not
    # assumed clean without checking.
    out=$(check_connection_truncation comments \
        '{"totalCount":0,"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[]}') \
        || true
    if [[ "$out" == "COMPLETE comments total=0" ]]; then
        echo "PASS: empty connection reported clean, not skipped"; pass=$((pass + 1))
    else
        echo "FAIL: empty connection mishandled, got: $out"; fail=$((fail + 1))
    fi

    # Case 4: the file/process-substitution merge used by fetch_all_nodes
    # and gl_fetch_all_discussions (never --argjson on argv -- a single
    # large comment body first hits Linux's per-argument MAX_ARG_STRLEN) --
    # two pages of 2 nodes each must merge into 4.
    local merged
    merged=$(jq -c -s '.[0] + .[1]' <(printf '%s' '[{"id":"1"},{"id":"2"}]') <(printf '%s' '[{"id":"3"},{"id":"4"}]'))
    if [[ "$(jq 'length' <<<"$merged")" == "4" ]]; then
        echo "PASS: page merge produces the full node count"; pass=$((pass + 1))
    else
        echo "FAIL: page merge did not produce 4 nodes, got: $merged"; fail=$((fail + 1))
    fi

    # Case 5: hasNextPage=false but totalCount != fetched count must still
    # be TRUNCATED -- the fetched==total comparison this fixes proves it
    # fires even when hasNextPage alone would pass a page silently dropped
    # or duplicated by a bug in the merge loop.
    out=$(check_connection_truncation reviewThreads \
        '{"totalCount":5,"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[{"id":"1"},{"id":"2"}]}') \
        || true
    if [[ "$out" == TRUNCATED* ]]; then
        echo "PASS: hasNextPage=false but total/fetched mismatch detected"; pass=$((pass + 1))
    else
        echo "FAIL: total/fetched mismatch not detected, got: $out"; fail=$((fail + 1))
    fi

    # Case 6: a connection with no totalCount field at all (GitLab's
    # DiscussionConnection) must not false-positive TRUNCATED just because
    # there is nothing to compare fetched against.
    out=$(check_connection_truncation discussions \
        '{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[{"id":"1"},{"id":"2"}]}') \
        || true
    if [[ "$out" == "COMPLETE discussions total=null" ]]; then
        echo "PASS: connection with no totalCount field (GitLab) reported clean on hasNextPage=false"; pass=$((pass + 1))
    else
        echo "FAIL: no-totalCount connection mishandled, got: $out"; fail=$((fail + 1))
    fi

    # Case 7: a top-level .errors response must abort fetch_all_nodes with
    # exit 2, not be silently merged as an empty page. Run in a subshell so
    # its exit 2 doesn't kill self-test.
    rc=0
    (
        gh() { echo '{"errors":[{"message":"field does not exist"}]}'; }
        fetch_all_nodes comments testowner testrepo 1 >/dev/null 2>&1
    ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        echo "PASS: .errors response in fetch_all_nodes triggers exit 2"; pass=$((pass + 1))
    else
        echo "FAIL: .errors response in fetch_all_nodes gave rc=$rc, expected 2"; fail=$((fail + 1))
    fi

    # Case 8: a null pullRequest (wrong number, deleted PR) must abort with
    # exit 2 rather than being walked as an empty "complete" connection.
    rc=0
    (
        gh() { echo '{"data":{"repository":{"pullRequest":null}}}'; }
        fetch_all_nodes comments testowner testrepo 999999 >/dev/null 2>&1
    ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        echo "PASS: null pullRequest in fetch_all_nodes triggers exit 2"; pass=$((pass + 1))
    else
        echo "FAIL: null pullRequest in fetch_all_nodes gave rc=$rc, expected 2"; fail=$((fail + 1))
    fi

    # Case 9: a null response from the page2 fetch (fetch_thread_comments_
    # page2) must abort with exit 2 instead of silently ending the
    # pagination loop one page short.
    rc=0
    (
        fetch_thread_comments_page2() { echo null; }
        fetch_full_thread_comments t1 \
            '{"totalCount":21,"pageInfo":{"hasNextPage":true,"endCursor":"c1"},"nodes":[{"id":"1"}]}' >/dev/null 2>&1
    ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        echo "PASS: null page2 response (GitHub) triggers exit 2"; pass=$((pass + 1))
    else
        echo "FAIL: null page2 response (GitHub) gave rc=$rc, expected 2"; fail=$((fail + 1))
    fi

    # Case 9b: fetch_full_thread_comments's own internal
    # check_connection_truncation call (a COMPLETE, non-failing result) must
    # not leak its diagnostic print into the returned JSON -- found live
    # 2026-08-26 against go-kure/kure#708: the print landed on stdout inside
    # a captured function, corrupting the caller's jq parse one level up.
    out=$(fetch_full_thread_comments t1 \
        '{"totalCount":1,"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[{"id":"1"}]}' 2>/dev/null)
    if jq -e '.nodes | length == 1' <<<"$out" >/dev/null 2>&1; then
        echo "PASS: fetch_full_thread_comments returns clean JSON on the happy path"; pass=$((pass + 1))
    else
        echo "FAIL: fetch_full_thread_comments's return value is not clean JSON: $out"; fail=$((fail + 1))
    fi

    # Case 10: same as case 9, GitLab side -- the REST fallback, not a GraphQL page2.
    rc=0
    (
        gl_fetch_discussion_notes_rest() { echo null; }
        gl_fetch_full_discussion_notes testproject 1 d1 \
            '{"pageInfo":{"hasNextPage":true,"endCursor":"c1"},"nodes":[{"id":"1"}]}' >/dev/null 2>&1
    ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        echo "PASS: null REST fallback response (GitLab) triggers exit 2"; pass=$((pass + 1))
    else
        echo "FAIL: null REST fallback response (GitLab) gave rc=$rc, expected 2"; fail=$((fail + 1))
    fi

    # Case 11: a null .data.project/.data.project.mergeRequest response
    # must abort gl_fetch_all_discussions with exit 2, mirroring case 8.
    rc=0
    (
        glab() { echo '{"data":{"project":null}}'; }
        gl_fetch_all_discussions testproject 1 >/dev/null 2>&1
    ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        echo "PASS: null project in gl_fetch_all_discussions triggers exit 2"; pass=$((pass + 1))
    else
        echo "FAIL: null project in gl_fetch_all_discussions gave rc=$rc, expected 2"; fail=$((fail + 1))
    fi

    # Case 12: the raw gh/glab invocation itself failing (nonzero exit, no
    # output -- not a successful call that merely returned .errors or null
    # data) must normalize to exit 2 at every guarded call site. gh/glab
    # already exit nonzero on any .errors-bearing response (confirmed live
    # against real endpoints); under `set -euo pipefail` an unguarded
    # assignment from such a call would otherwise abort the whole script
    # with the raw exit code, indistinguishable from "unresolved threads
    # present" (exit 1) in the very contract this script defines above.
    rc=0
    (
        gh() { return 1; }
        fetch_all_nodes comments testowner testrepo 1 >/dev/null 2>&1
    ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        echo "PASS: raw gh failure in fetch_all_nodes normalizes to exit 2"; pass=$((pass + 1))
    else
        echo "FAIL: raw gh failure in fetch_all_nodes gave rc=$rc, expected 2"; fail=$((fail + 1))
    fi

    rc=0
    (
        gh() { return 1; }
        fetch_full_thread_comments t1 \
            '{"totalCount":21,"pageInfo":{"hasNextPage":true,"endCursor":"c1"},"nodes":[{"id":"1"}]}' >/dev/null 2>&1
    ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        echo "PASS: raw gh failure in fetch_full_thread_comments (page2) normalizes to exit 2"; pass=$((pass + 1))
    else
        echo "FAIL: raw gh failure in fetch_full_thread_comments gave rc=$rc, expected 2"; fail=$((fail + 1))
    fi

    rc=0
    (
        glab() { return 1; }
        gl_fetch_all_discussions testproject 1 >/dev/null 2>&1
    ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        echo "PASS: raw glab failure in gl_fetch_all_discussions normalizes to exit 2"; pass=$((pass + 1))
    else
        echo "FAIL: raw glab failure in gl_fetch_all_discussions gave rc=$rc, expected 2"; fail=$((fail + 1))
    fi

    rc=0
    (
        glab() { return 1; }
        gl_fetch_full_discussion_notes testproject 1 d1 \
            '{"pageInfo":{"hasNextPage":true,"endCursor":"c1"},"nodes":[{"id":"1"}]}' >/dev/null 2>&1
    ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        echo "PASS: raw glab failure in gl_fetch_full_discussion_notes (REST fallback) normalizes to exit 2"; pass=$((pass + 1))
    else
        echo "FAIL: raw glab failure in gl_fetch_full_discussion_notes gave rc=$rc, expected 2"; fail=$((fail + 1))
    fi

    echo "self-test: $pass passed, $fail failed"
    [[ "$fail" -eq 0 ]]
}

# ---------------------------------------------------------------- GitHub --

# run_query OWNER REPO NUMBER [C_AFTER] [R_AFTER] [T_AFTER]
# One GraphQL round trip. Cursor args are omitted (not passed as the string
# "null") when empty, so the server sees the nullable variable as unset --
# passing the literal string "null" would be a Go/GraphQL string, not a null.
run_query() {
    local owner="$1" repo="$2" number="$3"
    local c_after="${4:-}" r_after="${5:-}" t_after="${6:-}"
    local args=(-F owner="$owner" -F repo="$repo" -F number="$number")
    [[ -n "$c_after" ]] && args+=(-f cAfter="$c_after")
    [[ -n "$r_after" ]] && args+=(-f rAfter="$r_after")
    [[ -n "$t_after" ]] && args+=(-f tAfter="$t_after")
    # $owner/$repo/etc below are GraphQL variables, not bash -- the query must
    # stay single-quoted so bash never touches them.
    # shellcheck disable=SC2016
    gh api graphql -f query='
      query($owner: String!, $repo: String!, $number: Int!, $cAfter: String, $rAfter: String, $tAfter: String) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $number) {
            comments(first: 100, after: $cAfter) {
              totalCount
              pageInfo { hasNextPage endCursor }
              nodes { id author { login } body createdAt }
            }
            reviews(first: 100, after: $rAfter) {
              totalCount
              pageInfo { hasNextPage endCursor }
              nodes { id author { login } state submittedAt body }
            }
            reviewThreads(first: 100, after: $tAfter) {
              totalCount
              pageInfo { hasNextPage endCursor }
              nodes {
                id
                isResolved
                isOutdated
                comments(first: 20) {
                  totalCount
                  pageInfo { hasNextPage endCursor }
                  nodes { id author { login } path line body createdAt }
                }
              }
            }
          }
        }
      }' "${args[@]}"
}

# fetch_all_nodes CONNECTION OWNER REPO NUMBER
# Pages through one top-level connection (comments|reviews|reviewThreads)
# until pageInfo.hasNextPage is false, merging every page's nodes. Prints the
# merged connection as one JSON object with hasNextPage forced to false --
# by construction this can never itself be TRUNCATED; check_connection_
# truncation is still run on the result as an assertion, not a probe.
#
# Every gh api graphql call this makes is guarded two ways: a raw nonzero
# exit (the invocation itself failed) normalizes to exit 2 immediately; a
# successful call whose response carries .errors, or whose repository/
# pullRequest is null, also exits 2 rather than being walked as an empty
# "complete" connection.
fetch_all_nodes() {
    local conn="$1" owner="$2" repo="$3" number="$4"
    local cursor="" merged='[]' total=0 page block has_next
    while :; do
        case "$conn" in
            comments)      page=$(run_query "$owner" "$repo" "$number" "$cursor" "" "") \
                               || { echo "BUG: gh api graphql call failed ($conn)" >&2; exit 2; } ;;
            reviews)       page=$(run_query "$owner" "$repo" "$number" "" "$cursor" "") \
                               || { echo "BUG: gh api graphql call failed ($conn)" >&2; exit 2; } ;;
            reviewThreads) page=$(run_query "$owner" "$repo" "$number" "" "" "$cursor") \
                               || { echo "BUG: gh api graphql call failed ($conn)" >&2; exit 2; } ;;
            *) echo "fetch_all_nodes: unknown connection $conn" >&2; return 64 ;;
        esac
        if jq -e '.errors' <<<"$page" >/dev/null 2>&1; then
            echo "BUG: GraphQL query returned .errors: $(jq -c '.errors' <<<"$page")" >&2
            exit 2
        fi
        if [[ "$(jq -r '.data.repository' <<<"$page")" == "null" ]]; then
            echo "BUG: repository not found (owner=$owner repo=$repo)" >&2
            exit 2
        fi
        if [[ "$(jq -r '.data.repository.pullRequest' <<<"$page")" == "null" ]]; then
            echo "BUG: pull request not found (owner=$owner repo=$repo number=$number)" >&2
            exit 2
        fi
        block=$(jq -c ".data.repository.pullRequest.${conn}" <<<"$page")
        total=$(jq -r '.totalCount' <<<"$block")
        merged=$(jq -c -s '.[0] + .[1]' <(printf '%s' "$merged") <(jq -c '.nodes' <<<"$block"))
        has_next=$(jq -r '.pageInfo.hasNextPage' <<<"$block")
        [[ "$has_next" == "true" ]] || break
        if [[ -n "${PILOT_RUN:-}" ]]; then
            next_cursor=$(jq -r '.pageInfo.endCursor' <<<"$block")
            [[ -n "$next_cursor" && "$next_cursor" != null && "$next_cursor" != "$cursor" ]] || { echo 'PAGINATION_CURSOR_STALLED' >&2; return 2; }
        fi
        cursor=$(jq -r '.pageInfo.endCursor' <<<"$block")
    done
    jq -n --argjson total "$total" --slurpfile nodes <(printf '%s' "$merged") \
        '{totalCount: $total, pageInfo: {hasNextPage: false, endCursor: null}, nodes: $nodes[0]}'
}

# fetch_thread_comments_page2 THREAD_ID CURSOR
# Re-queries one review thread's own nested comments connection past its
# first 20, via the global node(id:) lookup -- GraphQL has no way to page a
# nested connection without addressing the thread node directly.
fetch_thread_comments_page2() {
    local thread_id="$1" cursor="$2"
    # $id/$after below are GraphQL variables, not bash -- keep single-quoted.
    # shellcheck disable=SC2016
    gh api graphql -f query='
      query($id: ID!, $after: String) {
        node(id: $id) {
          ... on PullRequestReviewThread {
            comments(first: 20, after: $after) {
              totalCount
              pageInfo { hasNextPage endCursor }
              nodes { id author { login } path line body createdAt }
            }
          }
        }
      }' -F id="$thread_id" -f after="$cursor" --jq '.data.node.comments'
}

# fetch_full_thread_comments THREAD_ID THREAD_COMMENTS_JSON
# Given a review thread's already-fetched (first-page) comments connection,
# pages through fetch_thread_comments_page2 until pageInfo.hasNextPage is
# false, merging every page. Extracted from triage()'s per-thread loop so
# self-test can exercise its guards directly, without a live PR.
fetch_full_thread_comments() {
    local tid="$1" thread_comments="$2"
    local t_has_next t_cursor page2
    t_has_next=$(jq -r '.pageInfo.hasNextPage' <<<"$thread_comments")
    while [[ "$t_has_next" == "true" ]]; do
        t_cursor=$(jq -r '.pageInfo.endCursor' <<<"$thread_comments")
        page2=$(fetch_thread_comments_page2 "$tid" "$t_cursor") \
            || { echo "BUG: gh api graphql call failed (page2, thread $tid)" >&2; exit 2; }
        jq -e '. != null' <<<"$page2" >/dev/null \
            || { echo "BUG: page2 fetch returned null/errors, thread $tid truncated" >&2; exit 2; }
        thread_comments=$(jq -c -s '.[0].nodes += .[1].nodes | .[0].pageInfo = .[1].pageInfo | .[0]' \
            <(printf '%s' "$thread_comments") <(printf '%s' "$page2"))
        t_has_next=$(jq -r '.pageInfo.hasNextPage' <<<"$thread_comments")
    done
    # >&2 here, not the diagnostic's default stdout: this function's own stdout
    # is captured as JSON data by triage()'s callers (found live, 2026-08-26 --
    # a COMPLETE print leaking into $thread_comments broke the caller's jq parse).
    check_connection_truncation "thread $tid comments" "$thread_comments" >&2 \
        || { echo "BUG: thread $tid comments claims exhaustion but is truncated" >&2; exit 2; }
    printf '%s' "$thread_comments"
}

# triage OWNER REPO NUMBER
# Full gate-A6 pass: fetch every comment/review/thread exhaustively, print
# everything a human or agent must act on (unresolved threads first, then
# resolved threads informationally -- a resolved thread can still get a new
# reply without auto-unresolving, so it must stay visible to a caller's
# last_comment diff), and return 1 if any thread is still unresolved (0
# only when every connection is exhausted and every thread is resolved).
triage() {
    local owner="$1" repo="$2" number="$3"
    local comments reviews threads

    comments=$(fetch_all_nodes comments "$owner" "$repo" "$number")
    reviews=$(fetch_all_nodes reviews "$owner" "$repo" "$number")
    threads=$(fetch_all_nodes reviewThreads "$owner" "$repo" "$number")

    # Assertions, not probes: fetch_all_nodes already exhausted each
    # connection, so a TRUNCATED print here means fetch_all_nodes has a bug,
    # not that the PR has more data -- fail loudly rather than proceed.
    check_connection_truncation comments "$comments" \
        || { echo "BUG: comments claims exhaustion but is truncated" >&2; exit 2; }
    check_connection_truncation reviews "$reviews" \
        || { echo "BUG: reviews claims exhaustion but is truncated" >&2; exit 2; }
    check_connection_truncation reviewThreads "$threads" \
        || { echo "BUG: reviewThreads claims exhaustion but is truncated" >&2; exit 2; }

    echo "--- unresolved review threads ---"
    local unresolved_ids
    unresolved_ids=$(jq -r '.nodes[] | select(.isResolved == false) | .id' <<<"$threads")
    if [[ -n "$unresolved_ids" ]]; then
        while IFS= read -r tid; do
            echo "UNRESOLVED $tid"
            local thread_comments
            thread_comments=$(jq -c --arg id "$tid" '.nodes[] | select(.id == $id) | .comments' <<<"$threads")
            thread_comments=$(fetch_full_thread_comments "$tid" "$thread_comments")
            jq -r '.nodes[] | "  \(.id) \(.createdAt) [\(.author.login)] \(.path):\(.line) \(.body)"' <<<"$thread_comments"
        done <<<"$unresolved_ids"
    else
        echo "(none)"
    fi

    echo "--- resolved review threads (informational) ---"
    local resolved_ids
    resolved_ids=$(jq -r '.nodes[] | select(.isResolved == true) | .id' <<<"$threads")
    if [[ -n "$resolved_ids" ]]; then
        while IFS= read -r tid; do
            echo "RESOLVED $tid"
            local thread_comments
            thread_comments=$(jq -c --arg id "$tid" '.nodes[] | select(.id == $id) | .comments' <<<"$threads")
            thread_comments=$(fetch_full_thread_comments "$tid" "$thread_comments")
            jq -r '.nodes[] | "  \(.id) \(.createdAt) [\(.author.login)] \(.path):\(.line) \(.body)"' <<<"$thread_comments"
        done <<<"$resolved_ids"
    else
        echo "(none)"
    fi

    # Every review body is read unconditionally, regardless of whether that
    # review also produced inline thread comments -- the query has no field
    # linking a review to the threads it may have produced, so "no inline
    # thread" is not a condition this data can compute, and a review's
    # summary can carry content distinct from its own inline comments.
    echo "--- review bodies (read every one) ---"
    jq -r '.nodes[] | select(.body != "") | "REVIEW \(.id) \(.submittedAt) [\(.author.login)] \(.state): \(.body)"' <<<"$reviews"

    echo "--- top-level PR comments ---"
    jq -r '.nodes[] | "COMMENT \(.id) \(.createdAt) [\(.author.login)] \(.body)"' <<<"$comments"

    local unresolved_count
    unresolved_count=$(jq '[.nodes[] | select(.isResolved == false)] | length' <<<"$threads")
    if [[ "$unresolved_count" -gt 0 ]]; then
        echo "ACTION REQUIRED: $unresolved_count unresolved thread(s) above -- push a fix commit and rerun the caller's own verify/re-read gates, or state why not, then resolve with --resolve <thread-id>."
        return 1
    fi
    echo "clean: 0 unresolved threads. Reply to every comment/review body listed above, or state why not -- silence is not a response."
    return 0
}

# resolve_thread THREAD_ID
# Wraps the resolveReviewThread mutation and verifies it actually reported
# isResolved=true. Only call after the fix commit for that thread is pushed
# and verified -- never resolve an unpushed or unverified fix.
resolve_thread() {
    local thread_id="$1" result resolved
    # $id below is a GraphQL variable, not bash -- keep single-quoted.
    # shellcheck disable=SC2016
    result=$(gh api graphql -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { id isResolved } } }' -F id="$thread_id")
    if [[ "${PILOT_RESOLVER:-0}" == 1 ]]; then
        printf '%s' "$result" | "$PILOT_HELPER" validate-response >/dev/null || return 2
    fi
    echo "$result"
    resolved=$(jq -r '.data.resolveReviewThread.thread.isResolved' <<<"$result")
    [[ "$resolved" == "true" ]] || { echo "ERROR: mutation did not report isResolved=true (got: $resolved)" >&2; return 1; }
    if [[ "${PILOT_RESOLVER:-0}" == 1 ]]; then
        [[ $(jq -r '.data.resolveReviewThread.thread.id' <<<"$result") == "$thread_id" ]] || return 2
        # GraphQL variables must reach gh literally.
        # shellcheck disable=SC2016
        result=$(gh api graphql -f 'query=query($id: ID!) { node(id: $id) { ... on PullRequestReviewThread { id isResolved } } }' -F id="$thread_id") || return 2
        printf '%s' "$result" | "$PILOT_HELPER" validate-response >/dev/null || return 2
        jq -e --arg id "$thread_id" '.data.node.id == $id and .data.node.isResolved == true' <<<"$result" >/dev/null || return 2
    fi
}

# ---------------------------------------------------------------- GitLab --

# gl_run_query PROJECT_PATH IID [D_AFTER]
gl_run_query() {
    local project="$1" iid="$2" d_after="${3:-}"
    local args=(-f project="$project" -f iid="$iid")
    [[ -n "$d_after" ]] && args+=(-f after="$d_after")
    # $project/$iid/$after below are GraphQL variables, not bash -- keep
    # single-quoted.
    # shellcheck disable=SC2016
    glab api graphql -f query='
      query($project: ID!, $iid: String!, $after: String) {
        project(fullPath: $project) {
          mergeRequest(iid: $iid) {
            discussions(first: 100, after: $after) {
              pageInfo { hasNextPage endCursor }
              nodes {
                id resolvable resolved
                notes(first: 20) {
                  pageInfo { hasNextPage endCursor }
                  nodes { id createdAt body author { username } }
                }
              }
            }
          }
        }
      }' "${args[@]}"
}

# gl_fetch_all_discussions PROJECT IID
# Same while-loop/merge shape as fetch_all_nodes. The truncation check after
# the loop is hasNextPage-only -- DiscussionConnection has no totalCount
# field at all (confirmed live), so there is nothing to cross-check fetched
# against.
gl_fetch_all_discussions() {
    local project="$1" iid="$2"
    local cursor="" merged='[]' page block has_next
    while :; do
        page=$(gl_run_query "$project" "$iid" "$cursor") \
            || { echo "BUG: glab api graphql call failed (discussions)" >&2; exit 2; }
        if jq -e '.errors' <<<"$page" >/dev/null 2>&1; then
            echo "BUG: GraphQL query returned .errors: $(jq -c '.errors' <<<"$page")" >&2
            exit 2
        fi
        if [[ "$(jq -r '.data.project' <<<"$page")" == "null" ]]; then
            echo "BUG: project not found ($project)" >&2
            exit 2
        fi
        if [[ "$(jq -r '.data.project.mergeRequest' <<<"$page")" == "null" ]]; then
            echo "BUG: merge request not found (project=$project iid=$iid)" >&2
            exit 2
        fi
        block=$(jq -c '.data.project.mergeRequest.discussions' <<<"$page")
        merged=$(jq -c -s '.[0] + .[1]' <(printf '%s' "$merged") <(jq -c '.nodes' <<<"$block"))
        has_next=$(jq -r '.pageInfo.hasNextPage' <<<"$block")
        [[ "$has_next" == "true" ]] || break
        if [[ -n "${PILOT_RUN:-}" ]]; then
            next_cursor=$(jq -r '.pageInfo.endCursor' <<<"$block")
            [[ -n "$next_cursor" && "$next_cursor" != null && "$next_cursor" != "$cursor" ]] || { echo 'PAGINATION_CURSOR_STALLED' >&2; return 2; }
        fi
        cursor=$(jq -r '.pageInfo.endCursor' <<<"$block")
    done
    jq -n --slurpfile nodes <(printf '%s' "$merged") \
        '{pageInfo: {hasNextPage: false, endCursor: null}, nodes: $nodes[0]}'
}

# gl_fetch_discussion_notes_rest PROJECT IID DISCUSSION_ID
# NOT a GraphQL page2 -- GitLab's GraphQL schema has no way to fetch a single
# Discussion by ID (confirmed live: root Query has no `node(id:)` field, no
# `discussion(id:)` field either, and MergeRequest.discussions() takes only
# after/before/first/last -- no per-discussion filter), so a discussion whose
# notes exceed one GraphQL page can't be topped up via GraphQL at all. Falls
# back to the REST discussions-by-id endpoint instead, which returns every
# note in the discussion unpaginated in one call -- there is no "page2" to
# loop over once this succeeds, only a one-shot replacement of the truncated
# GraphQL result.
gl_fetch_discussion_notes_rest() {
    local project="$1" iid="$2" discussion_id="$3" encoded_project raw_id
    encoded_project=$(jq -rn --arg p "$project" '$p | @uri')
    raw_id="${discussion_id##*/}"
    # glab api's REST mode (unlike its graphql subcommand) has no --jq flag --
    # filter the response by piping to jq instead. `set -o pipefail` (top of
    # this file) makes a glab failure here still propagate as this pipeline's
    # exit code, not silently swallowed by jq succeeding on empty input.
    glab api "projects/$encoded_project/merge_requests/$iid/discussions/$raw_id" \
        | jq '{pageInfo: {hasNextPage: false, endCursor: null},
               nodes: [.notes[] | {id: ("gid://gitlab/Note/" + (.id | tostring)),
                                   createdAt: .created_at, body: .body,
                                   author: {username: .author.username}}]}'
}

# gl_fetch_full_discussion_notes PROJECT IID DISCUSSION_ID NOTES_JSON
# GitLab twin of fetch_full_thread_comments -- but see the REST fallback
# above: this only ever makes at most one extra call, never a cursor loop.
gl_fetch_full_discussion_notes() {
    local project="$1" iid="$2" did="$3" notes="$4"
    local n_has_next
    n_has_next=$(jq -r '.pageInfo.hasNextPage' <<<"$notes")
    if [[ "$n_has_next" == "true" ]]; then
        notes=$(gl_fetch_discussion_notes_rest "$project" "$iid" "$did") \
            || { echo "BUG: glab api call failed (discussion $did notes, REST fallback)" >&2; exit 2; }
        jq -e '. != null' <<<"$notes" >/dev/null \
            || { echo "BUG: REST discussion fetch returned null/errors, discussion $did truncated" >&2; exit 2; }
    fi
    printf '%s' "$notes"
}

# gl_triage PROJECT IID
# Same report shape as triage(): every resolvable-and-unresolved discussion's
# notes print as UNRESOLVED; every other discussion (an ordinary comment, or
# an already-resolved thread) prints informationally -- GitLab has no
# separate "review body" concept, a review here just is a discussion.
gl_triage() {
    local project="$1" iid="$2"
    local discussions

    discussions=$(gl_fetch_all_discussions "$project" "$iid")

    check_connection_truncation discussions "$discussions" \
        || { echo "BUG: discussions claims exhaustion but is truncated" >&2; exit 2; }

    echo "--- unresolved review threads ---"
    local unresolved_ids
    unresolved_ids=$(jq -r '.nodes[] | select(.resolvable == true and .resolved == false) | .id' <<<"$discussions")
    if [[ -n "$unresolved_ids" ]]; then
        while IFS= read -r did; do
            echo "UNRESOLVED $did"
            local notes
            notes=$(jq -c --arg id "$did" '.nodes[] | select(.id == $id) | .notes' <<<"$discussions")
            notes=$(gl_fetch_full_discussion_notes "$project" "$iid" "$did" "$notes")
            jq -r '.nodes[] | "  \(.id) \(.createdAt) [\(.author.username)] \(.body)"' <<<"$notes"
        done <<<"$unresolved_ids"
    else
        echo "(none)"
    fi

    echo "--- resolved threads / other discussions (informational) ---"
    local other_ids
    other_ids=$(jq -r '.nodes[] | select(.resolvable != true or .resolved == true) | .id' <<<"$discussions")
    if [[ -n "$other_ids" ]]; then
        while IFS= read -r did; do
            echo "RESOLVED $did"
            local notes
            notes=$(jq -c --arg id "$did" '.nodes[] | select(.id == $id) | .notes' <<<"$discussions")
            notes=$(gl_fetch_full_discussion_notes "$project" "$iid" "$did" "$notes")
            jq -r '.nodes[] | "  \(.id) \(.createdAt) [\(.author.username)] \(.body)"' <<<"$notes"
        done <<<"$other_ids"
    else
        echo "(none)"
    fi

    local unresolved_count
    unresolved_count=$(jq '[.nodes[] | select(.resolvable == true and .resolved == false)] | length' <<<"$discussions")
    if [[ "$unresolved_count" -gt 0 ]]; then
        echo "ACTION REQUIRED: $unresolved_count unresolved discussion(s) above -- push a fix commit and rerun the caller's own verify/re-read gates, or state why not, then resolve with --gitlab --resolve <discussion-id>."
        return 1
    fi
    echo "clean: 0 unresolved discussions. Reply to every note above, or state why not -- silence is not a response."
    return 0
}

# gl_resolve_discussion DISCUSSION_ID
gl_resolve_discussion() {
    local discussion_id="$1" result resolved
    # $id below is a GraphQL variable, not bash -- keep single-quoted.
    # shellcheck disable=SC2016
    result=$(glab api graphql -f query='mutation($id: DiscussionID!) { discussionToggleResolve(input: {id: $id, resolve: true}) { errors discussion { id resolved } } }' -f id="$discussion_id")
    if [[ "${PILOT_RESOLVER:-0}" == 1 ]]; then
        printf '%s' "$result" | "$PILOT_HELPER" validate-response >/dev/null || return 2
    fi
    echo "$result"
    resolved=$(jq -r '.data.discussionToggleResolve.discussion.resolved' <<<"$result")
    [[ "$resolved" == "true" ]] || { echo "ERROR: mutation did not report resolved=true (got: $resolved)" >&2; return 1; }
    if [[ "${PILOT_RESOLVER:-0}" == 1 ]]; then
        jq -e --arg id "$discussion_id" '(.data.discussionToggleResolve.errors | type == "array") and (.data.discussionToggleResolve.errors | length == 0) and .data.discussionToggleResolve.discussion.id == $id' <<<"$result" >/dev/null || return 2
        # GitLab has no root discussion/node lookup; the fixture receives the
        # complete discussion reread through the existing discussions query shape.
        result=$(gl_run_query fixture/project 1) || return 2
        printf '%s' "$result" | "$PILOT_HELPER" validate-response >/dev/null || return 2
        jq -e --arg id "$discussion_id" '.data.project.mergeRequest.discussions | .pageInfo.hasNextPage == false and any(.nodes[]; .id == $id and .resolved == true)' <<<"$result" >/dev/null || return 2
    fi
}

# --------------------------------------------------------------- dispatch --

require_jq

# Pilot lane: dormant for live executions; existing dispatch remains below.
# The helper validates sticky adoption even when a caller forgets a pilot flag.
PILOT_HELPER=/home/serge/bin/agent-review-state
if [[ "${1:-}" == --pilot-json ]]; then
    [[ $# -ge 4 ]] || { echo 'usage: --pilot-json <audit-run> github <owner> <repo> <number> | gitlab <project> <iid>' >&2; exit 64; }
    PILOT_RUN=$2
    PILOT_CONTEXT=$("$PILOT_HELPER" route --run "$PILOT_RUN") || exit 2
    PILOT_OWNER=$(jq -r .owner <<<"$PILOT_CONTEXT")
    PILOT_GENERATION=$(jq -r .generation <<<"$PILOT_CONTEXT")
    shift 2
    # These wrappers charge and validate each actual page, including nested fetches.
    gh() { "$PILOT_HELPER" api --run "$PILOT_RUN" --owner "$PILOT_OWNER" --generation "$PILOT_GENERATION" -- gh "$@"; }
    glab() { "$PILOT_HELPER" api --run "$PILOT_RUN" --owner "$PILOT_OWNER" --generation "$PILOT_GENERATION" -- glab "$@"; }
    case "$1" in
      github)
        [[ $# -eq 4 ]] || exit 64
        pc=$(fetch_all_nodes comments "$2" "$3" "$4") || exit 2
        pr=$(fetch_all_nodes reviews "$2" "$3" "$4") || exit 2
        pt=$(fetch_all_nodes reviewThreads "$2" "$3" "$4") || exit 2
        for inventory_connection in "$pc" "$pr" "$pt"; do
            printf '%s' "$inventory_connection" | "$PILOT_HELPER" validate-response >/dev/null || exit 2
            check_connection_truncation inventory "$inventory_connection" >&2 || exit 2
        done
        updated='[]'
        while IFS= read -r thread; do
            tid=$(jq -r .id <<<"$thread")
            notes=$(fetch_full_thread_comments "$tid" "$(jq -c .comments <<<"$thread")") || exit 2
            thread=$(jq --slurpfile notes <(printf '%s' "$notes") '.comments=$notes[0]' <<<"$thread")
            updated=$(jq -sc '.[0]+[.[1]]' <(printf '%s' "$updated") <(printf '%s' "$thread"))
        done < <(jq -c '.nodes[]' <<<"$pt")
        jq -n --slurpfile c <(printf '%s' "$pc") --slurpfile r <(printf '%s' "$pr") --slurpfile t <(printf '%s' "$updated") \
          '{forge:"github",comments:$c[0],reviews:$r[0],threads:$t[0],readiness:"not evaluated: inventory only"}'
        ;;
      gitlab)
        [[ $# -eq 3 ]] || exit 64
        pd=$(gl_fetch_all_discussions "$2" "$3") || exit 2
        printf '%s' "$pd" | "$PILOT_HELPER" validate-response >/dev/null || exit 2
        updated='[]'
        while IFS= read -r thread; do
            tid=$(jq -r .id <<<"$thread")
            notes=$(gl_fetch_full_discussion_notes "$2" "$3" "$tid" "$(jq -c .notes <<<"$thread")") || exit 2
            printf '%s' "$notes" | "$PILOT_HELPER" validate-response >/dev/null || exit 2
            thread=$(jq --slurpfile notes <(printf '%s' "$notes") '.notes=$notes[0] | .nativeState=(if .resolvable then (if .resolved then "resolved" else "unresolved" end) else "not-applicable" end)' <<<"$thread")
            updated=$(jq -sc '.[0]+[.[1]]' <(printf '%s' "$updated") <(printf '%s' "$thread"))
        done < <(jq -c '.nodes[]' <<<"$pd")
        jq -n --slurpfile d <(printf '%s' "$updated") '{forge:"gitlab",discussions:$d[0],readiness:"not evaluated: inventory only"}'
        ;;
      *) exit 64 ;;
    esac
    exit
fi
if [[ "${1:-}" == --pilot-resolver-fixture ]]; then
    # Test the EXISTING native resolver functions, with executable paths confined
    # to disposable fixtures. This lane cannot select the installed forge CLIs.
    [[ $# -eq 5 ]] || exit 64
    "$PILOT_HELPER" route --run "$2" >/dev/null || exit 2
    [[ $(jq -r .mode "$2/execution.json") == fixture ]] || exit 2
    fixture_bin=$(realpath "$3") || exit 2
    case "$fixture_bin" in /home/serge/tmp/agent-workflow-audit/*) ;; *) exit 2 ;; esac
    [[ -x "$fixture_bin/gh" && -x "$fixture_bin/glab" ]] || exit 2
    for fixture_cli in gh glab; do
        case "$(realpath "$fixture_bin/$fixture_cli")" in /home/serge/tmp/agent-workflow-audit/*) ;; *) exit 2 ;; esac
    done
    gh() { "$fixture_bin/gh" "$@"; }
    glab() { "$fixture_bin/glab" "$@"; }
    PILOT_RESOLVER=1
    case "$4" in github) resolve_thread "$5" ;; gitlab) gl_resolve_discussion "$5" ;; *) exit 64 ;; esac
    exit
fi
if [[ "${1:-}" != --self-test ]]; then
    PILOT_CONTEXT=$("$PILOT_HELPER" route) || exit 2
    if [[ $(jq -r .mode <<<"$PILOT_CONTEXT") != legacy ]]; then
        # Adopted unflagged calls may only read the shared status, never legacy resolve.
        if [[ " $* " == *' --resolve '* ]]; then
            echo 'LIVE_FORGE_MUTATIONS_DISABLED: adopted resolution requires the verified pilot path' >&2
            exit 2
        fi
        exec "$PILOT_HELPER" entrypoint --entrypoint triage
    fi
fi

case "${1:-}" in
    --self-test)
        self_test
        ;;
    --gitlab)
        shift
        require_glab
        case "${1:-}" in
            --resolve)
                [[ $# -eq 2 ]] || { echo "usage: $0 --gitlab --resolve <discussion-id>" >&2; exit 64; }
                gl_resolve_discussion "$2"
                ;;
            *)
                [[ $# -eq 2 ]] || { echo "usage: $0 --gitlab <group/project> <mr-iid> | --gitlab --resolve <discussion-id>" >&2; exit 64; }
                gl_triage "$1" "$2"
                ;;
        esac
        ;;
    --resolve)
        require_gh
        [[ $# -eq 2 ]] || { echo "usage: $0 --resolve <thread-id>" >&2; exit 64; }
        resolve_thread "$2"
        ;;
    *)
        require_gh
        [[ $# -eq 3 ]] || { echo "usage: $0 <owner> <repo> <pr-number> | --gitlab <group/project> <mr-iid> | --resolve <thread-id> | --gitlab --resolve <discussion-id> | --self-test" >&2; exit 64; }
        triage "$1" "$2" "$3"
        ;;
esac
