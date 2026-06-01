#!/usr/bin/env bats

load test_helper

# Mock backend that records it ran (marker file), then emits a minimal result.
setup_backend_mock() {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/claude" <<MOCK
#!/usr/bin/env bash
touch "$TEST_DIR/backend_ran"
echo '{"type":"result","result":"done"}'
MOCK
    chmod +x "$TEST_DIR/bin/claude"
}

# Minimal build workspace: init artifacts plus one incomplete task.
setup_build_workspace() {
    "$RALPH" init
    echo "- [ ] **Task**" >> IMPLEMENTATION_PLAN.md
}

# Writes a python pty harness that runs a command with a pseudo-terminal as
# stdin/stdout/stderr (so ralph's `[[ -t 0 ]]` check passes), feeds it a reply
# from $PTY_REPLY, relays the combined output, and exits with the child's code.
write_pty_runner() {
    cat > "$TEST_DIR/pty_runner.py" <<'PY'
import os, sys, subprocess
reply = os.environ.get("PTY_REPLY", "")
cmd = sys.argv[1:]
master, slave = os.openpty()
p = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave, close_fds=True)
os.close(slave)
os.write(master, (reply + "\n").encode())
out = bytearray()
try:
    while True:
        chunk = os.read(master, 1024)
        if not chunk:
            break
        out += chunk
except OSError:
    pass
rc = p.wait()
os.close(master)
sys.stdout.buffer.write(bytes(out))
sys.exit(rc)
PY
}

# ─── flag acceptance ────────────────────────────────────────────────────────

@test "build accepts --yes" {
    setup_build_workspace
    run "$RALPH" build --dry-run -n 1 --yes
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"Aborted."* ]]
}

@test "build accepts -y shorthand" {
    setup_build_workspace
    run "$RALPH" build --dry-run -n 1 -y
    [[ "$status" -eq 0 ]]
}

@test "plan accepts --yes" {
    "$RALPH" init
    run "$RALPH" plan --dry-run -n 1 --yes
    [[ "$status" -eq 0 ]]
}

@test "usage documents --yes" {
    run "$RALPH" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"--yes"* ]]
}

# ─── warning visibility ─────────────────────────────────────────────────────

@test "warning is shown when running outside a container" {
    setup_build_workspace
    run "$RALPH" build --dry-run -n 1
    [[ "$output" == *"WARNING: Running with"* ]]
}

@test "warning is suppressed inside a container" {
    setup_build_workspace
    DEVCONTAINER=true run "$RALPH" build --dry-run -n 1
    [[ "$output" != *"WARNING: Running with"* ]]
}

# ─── non-interactive: must proceed without prompting (backward compat) ───────

@test "build proceeds without prompting when stdin is not a tty" {
    setup_build_workspace
    setup_backend_mock
    PATH="$TEST_DIR/bin:$PATH" run "$RALPH" build -n 1 --skip-push
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"Continue anyway?"* ]]
    [[ -f "$TEST_DIR/backend_ran" ]]
}

@test "dry-run does not prompt even on a non-container host" {
    setup_build_workspace
    run "$RALPH" build --dry-run -n 1
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"Continue anyway?"* ]]
}

# ─── interactive (pty): prompt gates execution ──────────────────────────────

@test "interactive: pressing Enter (empty reply) aborts before the backend runs" {
    command -v python3 >/dev/null 2>&1 || skip "python3 needed to allocate a pty"
    setup_build_workspace
    setup_backend_mock
    write_pty_runner
    PTY_REPLY="" PATH="$TEST_DIR/bin:$PATH" \
        run python3 "$TEST_DIR/pty_runner.py" "$RALPH" build -n 1 --skip-push
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Continue anyway?"* ]]
    [[ "$output" == *"Aborted."* ]]
    [[ ! -f "$TEST_DIR/backend_ran" ]]
}

@test "interactive: answering y proceeds to run the backend" {
    command -v python3 >/dev/null 2>&1 || skip "python3 needed to allocate a pty"
    setup_build_workspace
    setup_backend_mock
    write_pty_runner
    PTY_REPLY="y" PATH="$TEST_DIR/bin:$PATH" \
        run python3 "$TEST_DIR/pty_runner.py" "$RALPH" build -n 1 --skip-push
    [[ "$output" == *"Continue anyway?"* ]]
    [[ "$output" != *"Aborted."* ]]
    [[ -f "$TEST_DIR/backend_ran" ]]
}
