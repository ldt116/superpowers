#!/usr/bin/env bash
# Tests for tests/claude-code/test-helpers.sh: the exported helpers work in
# a child shell, and cleanup_test_project says so when it can't resolve the
# scratch dir instead of silently leaving it behind.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

echo "=== Test: test-helpers.sh ==="
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
export SUPERPOWERS_LEGACY_SCRATCH_ROOT="$TEST_ROOT/legacy"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/test-helpers.sh"

# The exported helpers resolve the repo from a child shell too.
export SUPERPOWERS_SCRATCH_ROOT="$TEST_ROOT/root"
project=$(create_test_project)
create_test_plan "$project" child-plan >/dev/null
scratch=$(bash "$SUPERPOWERS_REPO_ROOT/skills/using-superpowers/scripts/scratch-dir" -C "$project")
bash -c 'cleanup_test_project "$1"' _ "$project" 2>"$TEST_ROOT/child.err" || true
if [[ ! -e "$project" && ! -e "$scratch" ]]; then
    pass "cleanup_test_project removes the project and its scratch dir from a child shell"
else
    fail "cleanup_test_project removes the project and its scratch dir from a child shell"
    echo "    project exists: $([[ -e "$project" ]] && echo yes || echo no)"
    echo "    scratch exists: $([[ -e "$scratch" ]] && echo yes || echo no)"
    echo "    stderr: $(cat "$TEST_ROOT/child.err")"
fi

# A refused root leaves scratch behind: cleanup says so on stderr.
mkdir "$TEST_ROOT/unsafe" && chmod 755 "$TEST_ROOT/unsafe"
project=$(create_test_project)
case "$(uname -s)" in
    MSYS*|MINGW*|CYGWIN*) echo "  [SKIP] refused-root warning (mode bits are fake here)" ;;
    *)
        SUPERPOWERS_SCRATCH_ROOT="$TEST_ROOT/unsafe" cleanup_test_project "$project" 2>"$TEST_ROOT/unsafe.err"
        if [[ ! -e "$project" ]] && grep -q "must be mode 700" "$TEST_ROOT/unsafe.err" \
            && grep -q "cleanup_test_project" "$TEST_ROOT/unsafe.err"; then
            pass "cleanup_test_project reports a refused scratch root on stderr"
        else
            fail "cleanup_test_project reports a refused scratch root on stderr"
            echo "    stderr: $(cat "$TEST_ROOT/unsafe.err")"
        fi
        ;;
esac

echo
if ((FAILURES)); then
    echo "FAILED: $FAILURES case(s)"
    exit 1
fi
echo "All test-helpers tests passed"
