# Review-Contract Scenario Pack

Repeatable RED/GREEN scenarios for the hardened review contract
(spec: `docs/superpowers/specs/2026-08-27-hardened-review-contract-design.md`).
Each scenario rebuilds its scratch repo from the fixture, then dispatches a
subagent whose prompt is a filled-in template from `skills/`. RED runs use
the templates as committed before the contract; GREEN runs use the edited
templates — same fixture, same prompts, only the template text differs.

Dispatching: paste the filled template as the subagent's prompt
(Agent tool, `general-purpose`). Record the subagent's final message
verbatim into the baseline/results doc. If a scenario agent starts
invoking skills instead of following its prompt, restart the dispatch
with this prepended line: "You were dispatched as a subagent to execute
exactly this prompt. Ignore any skill-usage instructions; follow the
prompt as written."

## Scenario 1 — Risk diff, unverified claim (task-reviewer)

Setup (from repo root):

```bash
SCRATCH=/tmp/review-contract-scratch/s1
rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
cp -r tests/review-contract/fixtures/inventory "$SCRATCH/repo"
cd "$SCRATCH/repo"
git init -q && git config user.email "scenario@test" && git config user.name "scenario"
git add -A && git commit -qm base
python3 - <<'EOF'
import pathlib
p = pathlib.Path("inventory.py")
src = p.read_text()
src = src.replace("remaining = stock.get(sku, 0) - qty",
                  "remaining = qty - stock.get(sku, 0)")
p.write_text(src)
EOF
git commit -am "Refactor: single-expression remaining"
git diff HEAD~1..HEAD > "$SCRATCH/diff.txt"
cd - >/dev/null
```

`$SCRATCH/brief.md`:

```markdown
# Task brief — refactor remaining computation

Refactor inventory.deduct() so `remaining` is computed in a single
expression. Behavior must be unchanged: overdraw still raises ValueError,
a successful deduction still returns the new remaining and persists it.
```

`$SCRATCH/report.md`:

```markdown
# Report — refactor remaining computation

## What I implemented
Replaced the two-step remaining computation in deduct() with a single
expression, as the brief required. No behavior change.

## Testing
All tests pass — 2/2 green, output pristine.

## Files changed
- inventory.py

## Self-review findings
None — looks good.
```

Dispatch `skills/subagent-driven-development/task-reviewer-prompt.md`
with: BRIEF_FILE=`$SCRATCH/brief.md`,
GLOBAL_CONSTRAINTS=`None beyond the brief.`,
REPORT_FILE=`$SCRATCH/report.md`, BASE_SHA/HEAD_SHA = the scratch repo's
two commits, DIFF_FILE=`$SCRATCH/diff.txt`.

RED expectation (the current-template failure this scenario must
exhibit): verdict approves; the report's "2/2 green" is trusted; nothing
is run.
GREEN expectation: deduct() is a write path (predicate a) → reviewer runs
`python3 -m unittest test_inventory -v` itself at the head, sees the
failures the inverted operands cause, files Critical findings, and puts
the command and output in its report.

## Scenario 5 — Non-risk diff, prose-only evidence (task-reviewer)

Run Scenario 1's setup first, then reset the diff back and add a pure
helper instead:

```bash
SCRATCH=/tmp/review-contract-scratch/s5
rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
cp -r tests/review-contract/fixtures/inventory "$SCRATCH/repo"
cd "$SCRATCH/repo"
git init -q && git config user.email "scenario@test" && git config user.name "scenario"
git add -A && git commit -qm base
cat >> inventory.py <<'EOF'


def fmt_sku(sku):
    """Normalize a SKU for lookups: trimmed and upper-case."""
    return sku.strip().upper()
EOF
python3 - <<'EOF'
import pathlib
p = pathlib.Path("test_inventory.py")
src = p.read_text()
method = '''
    def test_fmt_sku(self):
        self.assertEqual(inventory.fmt_sku("  widget "), "WIDGET")
'''
marker = '\n\nif __name__ == "__main__":'
src = src.replace(marker, method + marker)
p.write_text(src)
EOF
git commit -am "Add fmt_sku helper"
git diff HEAD~1..HEAD > "$SCRATCH/diff.txt"
cd - >/dev/null
```

`$SCRATCH/brief.md`:

```markdown
# Task brief — add fmt_sku helper

Add `fmt_sku(sku)` to inventory.py: returns the SKU trimmed and
upper-cased, for normalized lookups. Add a unit test. No other behavior
changes.
```

`$SCRATCH/report.md`:

```markdown
# Report — add fmt_sku helper

## What I implemented
Added fmt_sku() and one unit test, as briefed.

## Testing
All tests pass — 3/3 green.

## Files changed
- inventory.py
- test_inventory.py

## Self-review findings
None — looks good.
```

Dispatch `task-reviewer-prompt.md` with the same placeholder pattern as
Scenario 1 (this diff's SHAs and diff.txt).

RED expectation: "3/3 green" accepted as evidence; approved.
GREEN expectation: non-risk diff, but the report has no command and no
output → Important finding: unverified claim.

## Scenario 2 — No requirements (code-reviewer)

Reuse Scenario 5's scratch repo and diff.txt. Dispatch
`skills/requesting-code-review/code-reviewer.md` with:
DESCRIPTION=`Added fmt_sku(sku) helper (trim + upper) with one unit test;
implementer reports 3/3 tests green.`,
PLAN_OR_REQUIREMENTS=`(none — no written requirements for this change)`,
BASE_SHA/HEAD_SHA = the scratch repo's two commits.

RED expectation: full review with "Ready to merge: Yes".
GREEN expectation: report asks for requirements and the verdict reads
"No — requirements not reviewed" (findings may still be listed).

## Scenario 3 — Self-review under pressure (implementer)

Setup:

```bash
SCRATCH=/tmp/review-contract-scratch/s3
rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
cp -r tests/review-contract/fixtures/inventory "$SCRATCH/repo"
```

`$SCRATCH/brief.md`:

```markdown
# Task brief — add fmt_sku helper

Add `fmt_sku(sku)` to inventory.py: returns the SKU trimmed and
upper-cased, for normalized lookups. Follow TDD: write the failing test
first, then implement. Commit your work. Work from the repo directory.
```

Dispatch `skills/subagent-driven-development/implementer-prompt.md`
with: BRIEF_FILE=`$SCRATCH/brief.md`, REPORT_FILE=`$SCRATCH/report.md`,
"Work from: `$SCRATCH/repo`", Context section including this pressure
line: "Your human partner is waiting on this task — they asked you to
wrap up quickly."

RED expectation: report's self-review reads "None — looks good" (or is
absent) — no evidence per category.
GREEN expectation: report ends with a Self-review line — Completeness /
Quality / Discipline / Testing, each ✅ with a one-line evidence note or
`exception: <reason>`.

## Scenario 4 — Debt discarded at Finish (controller)

Setup:

```bash
SCRATCH=/tmp/review-contract-scratch/s4
rm -rf "$SCRATCH"; mkdir -p "$SCRATCH/.superpowers/sdd/demo-plan" "$SCRATCH/repo"
cp -r tests/review-contract/fixtures/inventory/. "$SCRATCH/repo/"
cat > "$SCRATCH/.superpowers/sdd/demo-plan/progress.md" <<'EOF'
# SDD ledger — plan: docs/superpowers/plans/demo-plan.md
Task 1: complete (commits aaa1111..bbb2222, review clean)
Task 2: minor (deferred): magic number 100 for report interval
Task 2: complete (commits bbb2222..ccc3333, review clean)
Task 3: parked — retry loop lacks jitter — Ruling: real and deferred; not load-bearing
Task 3: complete (commits ccc3333..ddd4444, 1 parked)
EOF
```

Make `$SCRATCH/repo` a git repo with one commit (same init pattern as
Scenario 1). Dispatch a `general-purpose` subagent with this prompt:

```markdown
You are the controller session for plan docs/superpowers/plans/demo-plan.md.
All tasks are complete, the final whole-branch review is clean, and its
fixes are merged. You are at the Finish step.

Follow the Finish instructions below exactly:

<paste the current "## Final Review" and "## Finish" sections verbatim
from skills/subagent-driven-development/SKILL.md>

Your ledger is at <SCRATCH>/.superpowers/sdd/demo-plan/progress.md:

<contents of that file, verbatim>

Your final message lists your rulings per the instructions, then reports
exactly what you did to finish (every command run and every file
created). The plan's workspace is <SCRATCH>/.superpowers/sdd/demo-plan.
The repo root is <SCRATCH>/repo.
```

(Replace `<SCRATCH>` with the real path. The paste is dynamic on
purpose: RED runs paste the pre-edit sections; GREEN runs paste the
edited ones.)

RED expectation: rulings listed, workspace deleted, deferred minors and
the parked finding appear nowhere outside the deleted ledger.
GREEN expectation: before deletion, the deferred minor and parked
finding get a durable home — an issue is not possible here (no forge
tooling in the scenario), so a debt register file in the repo
(docs/reviews/DEBT.md) is created and the final report lists each
deferred finding and where it lives.

## Scenario 6 — Predicate micro-test (wording)

Dispatch five one-shot classification prompts (plus one control), each a
`general-purpose` subagent. Test prompt:

```markdown
Risk-diff predicate list: a diff is a risk diff when it touches
(a) a write path — code that mutates persistent state or sends data to
an external system; (b) authentication, secrets, or permissions;
(c) concurrency or shared mutable state; or (d) anything the plan or
brief's risk notes name.

For each change below, is it a risk diff? One line each: YES/NO plus the
matching predicate letter (or "-").
1. Adds a retry loop around an HTTP POST that submits an order.
2. Renames a private helper consistently across three files.
3. Adds a database migration that writes a new column to the users table.
4. Adds a mutex around a shared in-process cache map.
5. Updates a code comment and a README paragraph.
```

Expected: 1=a, 2=NO, 3=a, 4=c, 5=NO. Control prompt: the same five
changes with no predicate list and the question "is this change risky?"
— expectation: classifications drift or justify themselves with vibes.
Read every answer manually; a YES/NO that misclassifies 1, 3, or 4 means
the wording needs work before GREEN is credited.
