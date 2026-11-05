#!/usr/bin/env bash
# Tests for skills/using-superpowers/scripts/scratch-dir: per-user scratch
# root creation, ownership/mode checks, project-id derivation, and migration
# of the legacy shared /tmp/superpowers/<id> directory.
#
# Every case points SUPERPOWERS_SCRATCH_ROOT / SUPERPOWERS_LEGACY_SCRATCH_ROOT
# into a temp dir. Only the default-root case touches the real
# /tmp/superpowers-<uid>, and it removes the <id> dir it created.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/skills/using-superpowers/scripts/scratch-dir"

FAILURES=0
TEST_ROOT=""
DEFAULT_CLEANUP=""
DEFAULT_ROOT_CLEANUP=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    if [[ -n "$DEFAULT_CLEANUP" ]]; then
        rm -rf "$DEFAULT_CLEANUP"
    fi
    if [[ -n "$DEFAULT_ROOT_CLEANUP" ]]; then
        rmdir "$DEFAULT_ROOT_CLEANUP" 2>/dev/null || true
    fi
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

# Same spelling the helper prints: cygpath -m on Windows, plain path elsewhere.
spell() {
    if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

path_id() {
    local resolved
    resolved="$(cd "$1" && pwd -P)"
    printf '%s-%s\n' "$(basename "$resolved")" \
        "$(printf %s "$resolved" | md5sum | cut -c1-6)"
}

# Run the helper with a per-case root/legacy pair. Captures stdout in $OUT,
# stderr in $ERR, exit status in $RC.
run_helper() {
    local case_name="$1"
    shift
    ROOT="$TEST_ROOT/root-$case_name"
    LEGACY="$TEST_ROOT/legacy-$case_name"
    local errfile="$TEST_ROOT/err-$case_name"
    RC=0
    OUT=$(SUPERPOWERS_SCRATCH_ROOT="$ROOT" SUPERPOWERS_LEGACY_SCRATCH_ROOT="$LEGACY" \
        bash "$HELPER" "$@" 2>"$errfile") || RC=$?
    ERR=$(cat "$errfile")
}

expect() {
    local description="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        pass "$description"
    else
        fail "$description"
        echo "    expected: $expected"
        echo "    actual:   $actual"
    fi
}

expect_refusal() {
    local description="$1" before="$2" after="$3" reason="$4"
    if [[ "$RC" == 2 && -z "$OUT" && "$ERR" == *"$reason"* && "$before" == "$after" ]]; then
        pass "$description"
    else
        fail "$description"
        echo "    rc=$RC out='$OUT' err='$ERR'"
        echo "    before: $before"
        echo "    after:  $after"
    fi
}

main() {
    echo "=== Test: scratch-dir helper ==="

    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    git init -q -b main "$TEST_ROOT/my repo"
    local repo
    repo="$(cd "$TEST_ROOT/my repo" && git rev-parse --show-toplevel)"
    mkdir "$repo/sub"
    local id
    id="$(path_id "$repo")"

    # fresh root is created mode 700
    run_helper fresh -C "$repo"
    if [[ "$RC" == 0 && -n "$(find "$ROOT" -maxdepth 0 -perm 0700)" ]]; then
        pass "fresh root is created mode 700"
    else
        fail "fresh root is created mode 700 (rc=$RC err=$ERR)"
    fi

    # prints <root>/<basename>-<md5_6>, from a subdirectory too
    local out_sub
    out_sub=$(cd "$repo/sub" && SUPERPOWERS_SCRATCH_ROOT="$TEST_ROOT/root-id" \
        SUPERPOWERS_LEGACY_SCRATCH_ROOT="$TEST_ROOT/legacy-id" bash "$HELPER")
    expect "prints <root>/<basename>-<md5_6> from a subdirectory" \
        "$(spell "$TEST_ROOT/root-id/$id")" "$out_sub"
    if [[ -d "$TEST_ROOT/root-id/$id" ]]; then
        pass "the project directory exists after the call"
    else
        fail "the project directory exists after the call"
    fi

    # -C DIR matches running from DIR
    local from_dir via_c
    from_dir=$(cd "$repo/sub" && SUPERPOWERS_SCRATCH_ROOT="$TEST_ROOT/root-c" \
        SUPERPOWERS_LEGACY_SCRATCH_ROOT="$TEST_ROOT/legacy-c" bash "$HELPER")
    via_c=$(SUPERPOWERS_SCRATCH_ROOT="$TEST_ROOT/root-c" \
        SUPERPOWERS_LEGACY_SCRATCH_ROOT="$TEST_ROOT/legacy-c" bash "$HELPER" -C "$repo/sub")
    expect "-C DIR matches running from DIR" "$from_dir" "$via_c"

    # bad -C directory
    run_helper badc -C "$TEST_ROOT/does-not-exist"
    if [[ "$RC" == 2 && -z "$OUT" && "$ERR" == "bad -C directory: $TEST_ROOT/does-not-exist" ]]; then
        pass "missing -C directory exits 2 with the message"
    else
        fail "missing -C directory exits 2 with the message (rc=$RC err=$ERR)"
    fi

    # non-repo directory uses the directory itself
    mkdir "$TEST_ROOT/plain dir"
    local plain_id
    plain_id="$(path_id "$TEST_ROOT/plain dir")"
    run_helper plain -C "$TEST_ROOT/plain dir"
    expect "non-repo directory uses the directory itself" \
        "$(spell "$ROOT/$plain_id")" "$OUT"

    # --root prints only the root
    run_helper rootflag --root -C "$repo"
    expect "--root prints only the root" "$(spell "$ROOT")" "$OUT"

    # own pre-created 700 root is accepted
    ROOT="$TEST_ROOT/root-own"
    mkdir -m 700 "$ROOT"
    run_helper own -C "$repo"
    expect "own pre-created 700 root is accepted" "$(spell "$ROOT/$id")" "$OUT"

    # refuses a symlinked root; nothing is written through the link
    mkdir -m 700 "$TEST_ROOT/link-target"
    ln -s "$TEST_ROOT/link-target" "$TEST_ROOT/root-symlink"
    local before after
    before=$(find "$TEST_ROOT/link-target" | sort)
    run_helper symlink -C "$repo"
    after=$(find "$TEST_ROOT/link-target" | sort)
    expect_refusal "refuses a symlinked root" "$before" "$after" "is a symlink"

    # refuses a regular file as root
    : > "$TEST_ROOT/root-file"
    before=$(ls -la "$TEST_ROOT/root-file")
    run_helper file -C "$repo"
    after=$(ls -la "$TEST_ROOT/root-file")
    expect_refusal "refuses a regular file as root" "$before" "$after" "is not a directory"

    # refuses a root with mode 755; no entries, mode untouched
    mkdir "$TEST_ROOT/root-mode"
    chmod 755 "$TEST_ROOT/root-mode"
    before=$(find "$TEST_ROOT/root-mode" -printf '%p %m\n' | sort)
    run_helper mode -C "$repo"
    after=$(find "$TEST_ROOT/root-mode" -printf '%p %m\n' | sort)
    expect_refusal "refuses a root with mode 755" "$before" "$after" "must be mode 700"

    # migrates own legacy dir
    mkdir -p "$TEST_ROOT/legacy-migrate/$id/plans"
    echo plan > "$TEST_ROOT/legacy-migrate/$id/plans/p.md"
    run_helper migrate -C "$repo"
    if [[ "$RC" == 0 && -f "$ROOT/$id/plans/p.md" && -L "$LEGACY/$id" \
        && "$(readlink "$LEGACY/$id")" == "$ROOT/$id" ]]; then
        pass "migrates own legacy dir and leaves a symlink to the new dir"
    else
        fail "migrates own legacy dir and leaves a symlink to the new dir (rc=$RC err=$ERR)"
    fi

    # second call after migration is a no-op
    local first_link second_out
    first_link=$(readlink "$LEGACY/$id")
    second_out=$(SUPERPOWERS_SCRATCH_ROOT="$ROOT" SUPERPOWERS_LEGACY_SCRATCH_ROOT="$LEGACY" \
        bash "$HELPER" -C "$repo")
    if [[ "$second_out" == "$OUT" && "$(readlink "$LEGACY/$id")" == "$first_link" \
        && -f "$ROOT/$id/plans/p.md" ]]; then
        pass "second call after migration is a no-op"
    else
        fail "second call after migration is a no-op (out=$second_out)"
    fi

    # does not migrate a symlinked legacy dir
    mkdir -p "$TEST_ROOT/legacy-lnk" "$TEST_ROOT/elsewhere/data"
    echo keep > "$TEST_ROOT/elsewhere/data/k"
    ln -s "$TEST_ROOT/elsewhere" "$TEST_ROOT/legacy-lnk/$id"
    run_helper lnk -C "$repo"
    if [[ "$RC" == 0 && -d "$ROOT/$id" && -z "$(ls -A "$ROOT/$id")" \
        && -L "$LEGACY/$id" && "$(readlink "$LEGACY/$id")" == "$TEST_ROOT/elsewhere" \
        && -f "$TEST_ROOT/elsewhere/data/k" ]]; then
        pass "does not migrate a symlinked legacy dir"
    else
        fail "does not migrate a symlinked legacy dir (rc=$RC err=$ERR)"
    fi

    # default root is /tmp/superpowers-$(id -u)
    local default_root default_out
    default_root="/tmp/superpowers-$(id -u)"
    if [[ ! -e "$default_root" ]]; then
        DEFAULT_ROOT_CLEANUP="$default_root"
    fi
    if [[ ! -e "$default_root/$id" ]]; then
        DEFAULT_CLEANUP="$default_root/$id"
    fi
    default_out=$(env -u SUPERPOWERS_SCRATCH_ROOT -u SUPERPOWERS_LEGACY_SCRATCH_ROOT \
        bash "$HELPER" -C "$repo") || true
    expect "default root is /tmp/superpowers-\$(id -u)" \
        "$(spell "$default_root/$id")" "$default_out"
    [[ -z "$DEFAULT_CLEANUP" ]] || { rm -rf "$DEFAULT_CLEANUP"; DEFAULT_CLEANUP=""; }
    [[ -z "$DEFAULT_ROOT_CLEANUP" ]] || { rmdir "$DEFAULT_ROOT_CLEANUP" 2>/dev/null || true; DEFAULT_ROOT_CLEANUP=""; }

    echo
    if ((FAILURES)); then
        echo "FAILED: $FAILURES case(s)"
        exit 1
    fi
    echo "All scratch-dir tests passed"
}

main "$@"
