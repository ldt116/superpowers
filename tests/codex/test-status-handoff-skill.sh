#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

SKILL_DIR="skills/status-handoff"

python3 - "$SKILL_DIR" <<'EOF'
import re, sys
from pathlib import Path

skill = Path(sys.argv[1])
errors = []

required = [skill / "SKILL.md"]
for f in required:
    if not f.is_file():
        errors.append(f"missing file: {f}")

if (skill / "SKILL.md").is_file():
    text = (skill / "SKILL.md").read_text()
    fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not fm:
        errors.append("SKILL.md: no frontmatter block")
    else:
        for field in ("name:", "description:"):
            if field not in fm.group(1):
                errors.append(f"SKILL.md frontmatter missing {field}")
        if not re.search(r"description:\s*Use when", fm.group(1)):
            errors.append("SKILL.md description does not start with 'Use when'")
    # The status contract is the skill's backbone — guard its pieces
    for needle, why in [
        ("refs/heads/status/", "status ref namespace"),
        ("git ls-remote", "ref-based detection"),
        ("status/<key>-dev", "dev state ref"),
        ("status/<key>-ready-review", "ready-review state ref"),
        ("status/<key>-changes", "changes state ref"),
        ("status/<key>-merged", "merged state ref"),
        ("status/<key>-closed", "closed state ref"),
        ("pushes the new ref first, then deletes the old one", "transition self-cleanup rule"),
        ("finishing-a-development-branch", "post-merge cleanup cross-reference"),
        ("Common Rationalizations", "rationalization table"),
        ("work branch name", "key is the branch, not issue/PR number"),
        ("never a subagent", "monitor is a shell loop, not a subagent poll"),
    ]:
        if needle not in text:
            errors.append(f"SKILL.md: missing {why} ({needle!r})")

# Routing into the skill must survive at the two places agents actually pass through
for f, needles in {
    Path("skills/requesting-code-review/SKILL.md"): [
        ("Who Reviews", "reviewer-lane decision tree"),
        ("status-handoff", "remote-reviewer lane routes to the skill"),
        ("Self-review does not substitute", "self-review never replaces the remote reviewer"),
    ],
    Path("skills/using-superpowers/SKILL.md"): [
        ("status-handoff", "session-start routing line"),
    ],
}.items():
    text = f.read_text()
    for needle, why in needles:
        if needle not in text:
            errors.append(f"{f}: missing {why} ({needle!r})")

for f in skill.rglob("*.md"):
    for i, line in enumerate(f.read_text().splitlines(), 1):
        if re.match(r"^\s*model:\s*\S", line):
            errors.append(f"{f}:{i}: dispatch template contains a model: field")

if errors:
    print("\n".join(errors))
    raise AssertionError("status-handoff skill structure test failed")
print("status-handoff skill structure OK")
EOF
