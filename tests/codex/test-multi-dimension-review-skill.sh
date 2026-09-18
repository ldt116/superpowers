#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

SKILL_DIR="skills/multi-dimension-review"

python3 - "$SKILL_DIR" <<'EOF'
import re, sys
from pathlib import Path

skill = Path(sys.argv[1])
errors = []

required = [
    skill / "SKILL.md",
    skill / "references" / "code-smells.md",
    skill / "dimension-reviewer.md",
    skill / "merge-verifier.md",
]
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
    if "multi-dimension-review" not in text:
        errors.append("SKILL.md: never references its own name")

for f in skill.rglob("*.md"):
    for i, line in enumerate(f.read_text().splitlines(), 1):
        if re.match(r"^\s*model:\s*\S", line):
            errors.append(f"{f}:{i}: dispatch template contains a model: field")

if errors:
    print("\n".join(errors))
    raise AssertionError("multi-dimension-review skill structure test failed")
print("multi-dimension-review skill structure OK")
EOF
