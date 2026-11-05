#!/usr/bin/env bash
# Fast tests for start-server.sh shell-only platform decisions.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
START_SCRIPT="$REPO_ROOT/skills/brainstorming/scripts/start-server.sh"

TEST_DIR="${TMPDIR:-/tmp}/brainstorm-start-test-$$"
passed=0
failed=0

# Sessions land under the per-user scratch root; point it (and the legacy
# root) into the test dir so nothing is written under the real /tmp/superpowers*.
export SUPERPOWERS_SCRATCH_ROOT="$TEST_DIR/scratch"
export SUPERPOWERS_LEGACY_SCRATCH_ROOT="$TEST_DIR/legacy"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# <scratch-dir> for a project dir: root / basename-md5(physical path)[:6].
project_scratch() {
  local phys
  phys="$(cd "$1" && pwd -P)"
  echo "$SUPERPOWERS_SCRATCH_ROOT/$(basename "$phys")-$(printf %s "$phys" | md5sum | cut -c1-6)"
}

pass() {
  echo "  PASS: $1"
  passed=$((passed + 1))
}

fail() {
  echo "  FAIL: $1"
  echo "    $2"
  failed=$((failed + 1))
}

make_fake_uname() {
  local fake_bin="$1"
  cat > "$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-s" ]]; then
  echo "MINGW64_NT-10.0"
else
  /usr/bin/uname "$@"
fi
EOF
  chmod +x "$fake_bin/uname"
}

echo ""
echo "--- start-server.sh platform detection ---"

mkdir -p "$TEST_DIR/fake-bin" "$TEST_DIR/project"
make_fake_uname "$TEST_DIR/fake-bin"

cat > "$TEST_DIR/fake-bin/node" <<'EOF'
#!/usr/bin/env bash
echo "CAPTURED_OWNER_PID=${BRAINSTORM_OWNER_PID:-__UNSET__}"
printf 'CAPTURED_ARGV=%s\n' "$@"
exit 0
EOF
chmod +x "$TEST_DIR/fake-bin/node"

captured=$(
  PATH="$TEST_DIR/fake-bin:$PATH" \
    MSYSTEM="" \
    bash "$START_SCRIPT" --project-dir "$TEST_DIR/project" --foreground 2>/dev/null || true
)
owner_pid_value=$(echo "$captured" | grep "CAPTURED_OWNER_PID=" | head -1 | sed 's/CAPTURED_OWNER_PID=//')

if [[ "$owner_pid_value" == "" || "$owner_pid_value" == "__UNSET__" ]]; then
  pass "clears BRAINSTORM_OWNER_PID when uname reports a Windows-like shell"
else
  fail "clears BRAINSTORM_OWNER_PID when uname reports a Windows-like shell" \
       "expected empty or unset, got '$owner_pid_value'"
fi

if echo "$captured" | grep -Eq '^CAPTURED_ARGV=--brainstorm-server-id=[A-Za-z0-9_-]{32,64}$'; then
  pass "passes shell-safe server instance id argv"
else
  fail "passes shell-safe server instance id argv" \
       "expected exact --brainstorm-server-id=<safe id> argv line, got: $captured"
fi

server_id_file=$(find "$(project_scratch "$TEST_DIR/project")/brainstorm" -name server-instance-id -print 2>/dev/null | head -1)
server_id_value=""
if [[ -n "$server_id_file" ]]; then
  server_id_value="$(tr -d '\r\n' < "$server_id_file")"
fi
if [[ "$server_id_value" =~ ^[A-Za-z0-9_-]{32,64}$ ]]; then
  pass "writes shell-safe server-instance-id state file"
else
  fail "writes shell-safe server-instance-id state file" \
       "expected valid id in state, got '$server_id_value'"
fi

rm -rf "$(project_scratch "$TEST_DIR/project")"

cat > "$TEST_DIR/fake-bin/node" <<'EOF'
#!/usr/bin/env bash
echo "FOREGROUND_MODE=true"
exit 0
EOF
chmod +x "$TEST_DIR/fake-bin/node"

captured=$(
  PATH="$TEST_DIR/fake-bin:$PATH" \
    MSYSTEM="" \
    bash "$START_SCRIPT" --project-dir "$TEST_DIR/project" 2>/dev/null || true
)

if echo "$captured" | grep -q "FOREGROUND_MODE=true"; then
  pass "auto-foregrounds when uname reports a Windows-like shell"
else
  fail "auto-foregrounds when uname reports a Windows-like shell" \
       "expected foreground node path, got: $captured"
fi

echo ""
echo "--- start-server.sh relative --project-dir ---"

cat > "$TEST_DIR/fake-bin/node" <<'EOF'
#!/usr/bin/env bash
echo "CAPTURED_BRAINSTORM_DIR=${BRAINSTORM_DIR:-__UNSET__}"
exit 0
EOF
chmod +x "$TEST_DIR/fake-bin/node"

# The script cds into its own directory before starting the server, so a
# relative --project-dir must be resolved against the caller's cwd first.
# Covers an existing dir and a not-yet-created one, both with spaces.
for relative_dir in "." "new project dir"; do
  caller_dir="$TEST_DIR/caller with space"
  rm -rf "$caller_dir"
  mkdir -p "$caller_dir"
  expected_root="$(cd "$caller_dir" && pwd -P)"
  if [[ "$relative_dir" != "." ]]; then
    expected_root="$expected_root/$relative_dir"
  fi
  # Fork layout: session dirs live under <scratch-root>/<project-id>/,
  # keyed by the physical project dir, never inside the project.
  expected_scratch="$SUPERPOWERS_SCRATCH_ROOT/$(basename "$expected_root")-$(printf %s "$expected_root" | md5sum | cut -c1-6)"

  captured=$(
    cd "$caller_dir" &&
      PATH="$TEST_DIR/fake-bin:$PATH" \
        MSYSTEM="" \
        bash "$START_SCRIPT" --project-dir "$relative_dir" --foreground 2>&1 || true
  )
  brainstorm_dir=$(echo "$captured" | grep "CAPTURED_BRAINSTORM_DIR=" | head -1 | sed 's/CAPTURED_BRAINSTORM_DIR=//')

  case "$brainstorm_dir" in
    "$expected_scratch/brainstorm/"*)
      pass "--project-dir '$relative_dir' gives the server an absolute session dir keyed by the caller's cwd" ;;
    *)
      fail "--project-dir '$relative_dir' gives the server an absolute session dir keyed by the caller's cwd" \
           "expected prefix '$expected_scratch/brainstorm/', got: $captured" ;;
  esac
  if [[ ! -e "$expected_root/.superpowers" ]]; then
    pass "--project-dir '$relative_dir' writes nothing inside the project"
  else
    fail "--project-dir '$relative_dir' writes nothing inside the project" \
         "found $expected_root/.superpowers"
  fi

  if [[ -n "$brainstorm_dir" && -f "$brainstorm_dir/state/server.pid" ]]; then
    pass "--project-dir '$relative_dir' writes server.pid into the project session dir"
  else
    fail "--project-dir '$relative_dir' writes server.pid into the project session dir" \
         "no server.pid under '$brainstorm_dir/state', output: $captured"
  fi
  rm -rf "$expected_scratch"
done

echo ""
echo "--- start-server.sh scratch root ---"

# The fake MINGW uname would make the helper skip its mode-700 check.
rm -f "$TEST_DIR/fake-bin/uname"

# No --project-dir: the session is brainstorm-<id> directly under the root.
captured=$(
  cd "$TEST_DIR/project" &&
    PATH="$TEST_DIR/fake-bin:$PATH" MSYSTEM="" \
      bash "$START_SCRIPT" --foreground 2>&1 || true
)
brainstorm_dir=$(echo "$captured" | grep "CAPTURED_BRAINSTORM_DIR=" | head -1 | sed 's/CAPTURED_BRAINSTORM_DIR=//')
case "$brainstorm_dir" in
  "$SUPERPOWERS_SCRATCH_ROOT/brainstorm-"*)
    pass "no --project-dir puts the session at <root>/brainstorm-<id>" ;;
  *)
    fail "no --project-dir puts the session at <root>/brainstorm-<id>" \
         "expected prefix '$SUPERPOWERS_SCRATCH_ROOT/brainstorm-', got: $captured" ;;
esac

# An unsafe root (group/other-accessible) makes the helper fail: start-server
# reports it as JSON, exits 1, and starts nothing.
unsafe_root="$TEST_DIR/unsafe-root"
mkdir -p "$unsafe_root" && chmod 755 "$unsafe_root"
for args in "--project-dir $TEST_DIR/project" ""; do
  # shellcheck disable=SC2086
  out=$(
    PATH="$TEST_DIR/fake-bin:$PATH" MSYSTEM="" SUPERPOWERS_SCRATCH_ROOT="$unsafe_root" \
      bash "$START_SCRIPT" $args --foreground 2>/dev/null
  )
  status=$?
  if [[ $status -eq 1 && "$out" == '{"error": "'*'"}' && "$out" != *CAPTURED_* ]]; then
    pass "unsafe scratch root -> JSON error and exit 1 (${args:-no project dir})"
  else
    fail "unsafe scratch root -> JSON error and exit 1 (${args:-no project dir})" \
         "status=$status out=$out"
  fi
done

echo ""
echo "--- Results: $passed passed, $failed failed ---"
if [[ $failed -gt 0 ]]; then
  exit 1
fi
