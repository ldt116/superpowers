# Hardened Review Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (default; use superpowers:executing-plans only when subagents are unavailable) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden every review seat in the fork — reviewers verify code over claims (tiered by diff risk), never approve without requirements, audit the implementer's Self-review line, and record deferred debt beyond the workspace.

**Architecture:** All rules live in the existing prompt templates (`code-reviewer.md`, `task-reviewer-prompt.md`, `re-review-prompt.md`, `implementer-prompt.md`) and the skills that dispatch them — reviewer subagents see only their dispatch prompt, so a rule not in the template does not exist for them. No new skills, no packaging changes.

**Tech Stack:** Markdown prompt templates (skills tree), Python 3 stdlib unittest fixture for scenario testing, bash scratch repos under `/tmp` for baseline/GREEN scenario runs, Agent-tool subagent dispatches.

**Spec:** `docs/superpowers/specs/2026-08-27-hardened-review-contract-design.md`

## Global Constraints

- **Rules live in the prompt templates.** Reviewer subagents see only their dispatch prompt; CLAUDE.md of a consuming project never reaches them. Every rule added in this plan must appear in template text (or in the dispatching skill), never only in CLAUDE.md/README.
- **Risk-diff predicates, verbatim** (any one makes a diff a risk diff): (a) a write path — code that mutates persistent state or sends data to an external system; (b) authentication, secrets, or permissions; (c) concurrency or shared mutable state; (d) anything the plan/brief's risk notes name. Never "seems risky" — observable predicates only.
- **Evidence floor:** a test claim counts as evidence only with the exact command and its output. Prose verdicts ("tests pass", "14/14 green") are an Important finding: unverified claim.
- **Requirements gate:** no approval without requirements. Missing requirements → verdict "No — requirements not reviewed", plus a request for them.
- **Debt durability:** every deferred/parked finding gets a durable home before workspace deletion — one follow-up issue per actionable cluster (Gitea MCP, `gh`, `tea`) or a repo debt register (`docs/reviews/DEBT.md` unless the project has its own convention).
- **Preserve each skill's existing voice and structure** (fork rule). Duplicated rule text across templates follows the existing idiom (the read-only / no-subagents rules are already duplicated verbatim).
- **Iron Law (writing-skills):** no skill/template edit without a failing baseline first. Task 1 records the RED baselines; every edit task re-runs its scenarios for GREEN; the final task runs the REFACTOR pass.
- **Fork bookkeeping:** when the CLAUDE.md divergence list changes, the README fork section must match.
- All skill/template text is English, matching each file's idiom.
- No packaging, manifest, hook, or `scripts/` changes in this plan.

---

### Task 1: RED Baseline — Fixture, Scenario Pack, Baseline Results

**Files:**
- Create: `tests/review-contract/fixtures/inventory/inventory.py`
- Create: `tests/review-contract/fixtures/inventory/stock.json`
- Create: `tests/review-contract/fixtures/inventory/test_inventory.py`
- Create: `tests/review-contract/scenarios.md`
- Create: `docs/superpowers/specs/2026-08-27-hardened-review-contract-baseline.md`

**Interfaces:**
- Consumes: current (unedited) templates under `skills/` — the point is to capture their behavior BEFORE any edit.
- Produces: fixture at `tests/review-contract/fixtures/inventory/` and the scenario definitions in `tests/review-contract/scenarios.md`; the baseline results doc that Tasks 2–5 compare their GREEN runs against. Scratch repos live under `/tmp/review-contract-scratch/<scenario>/` and are rebuilt from the fixture each run.

- [ ] **Step 1: Create the fixture**

`tests/review-contract/fixtures/inventory/inventory.py`:

```python
import json
import pathlib

DB = pathlib.Path(__file__).parent / "stock.json"


def load():
    return json.loads(DB.read_text())


def deduct(sku, qty):
    """Write path: mutates persistent stock state."""
    stock = load()
    remaining = stock.get(sku, 0) - qty
    if remaining < 0:
        raise ValueError(f"insufficient stock for {sku}")
    stock[sku] = remaining
    DB.write_text(json.dumps(stock))
    return remaining
```

`tests/review-contract/fixtures/inventory/stock.json`:

```json
{"widget": 5}
```

`tests/review-contract/fixtures/inventory/test_inventory.py`:

```python
import json
import unittest

import inventory


class DeductTest(unittest.TestCase):
    def setUp(self):
        inventory.DB.write_text('{"widget": 5}')

    def test_deduct(self):
        self.assertEqual(inventory.deduct("widget", 2), 3)

    def test_overdraw_rejected(self):
        with self.assertRaises(ValueError):
            inventory.deduct("widget", 99)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Verify the fixture is green**

Run: `cd tests/review-contract/fixtures/inventory && python3 -m unittest test_inventory -v && cd -`
Expected: 2 tests OK. Restore `stock.json` to `{"widget": 5}` afterward if a run dirtied it (tests reset in `setUp`, but check with `git status`).

- [ ] **Step 3: Write the scenario pack**

`tests/review-contract/scenarios.md` — full content:

````markdown
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
cat >> test_inventory.py <<'EOF'

    def test_fmt_sku(self):
        self.assertEqual(inventory.fmt_sku("  widget "), "WIDGET")
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
````

- [ ] **Step 4: Run the RED baselines**

Run Scenarios 1, 5, 2, 3, 4, and 6 exactly as written in `tests/review-contract/scenarios.md`, with the templates in their current (unedited) state. Use `model: sonnet` for every scenario dispatch, and the same model again in GREEN so RED vs GREEN differs only in template text. Paste each dispatch's final message verbatim into the results doc (Step 5).

Expected failures (these ARE the failing tests the Iron Law requires):
- Scenario 1: approval despite an unverified claim on a write-path diff.
- Scenario 5: "3/3 green" accepted with no command/output.
- Scenario 2: "Ready to merge: Yes" with no requirements.
- Scenario 3: self-review without per-category evidence.
- Scenario 4: workspace deleted, debt unrecorded.
- Scenario 6: control drifts; predicate list classifies correctly (if the predicate list itself misclassifies in RED, fix the wording in scenarios.md AND carry the fixed wording into the Task 2 template edits).

If a scenario does NOT fail in RED (the current template already behaves correctly), record that verbatim too — the corresponding edit is then a hardening, not a fix, and the baseline doc says so.

- [ ] **Step 5: Write the baseline results doc**

`docs/superpowers/specs/2026-08-27-hardened-review-contract-baseline.md`, structured as:

```markdown
# Hardened Review Contract — Baseline (RED) Results

**Date:** <date>
**Templates at:** commit <SHA of HEAD when baselines were run>
**Scenario pack:** tests/review-contract/scenarios.md
**Scenario model:** sonnet

## Scenario 1 — Risk diff, unverified claim
**Dispatch:** task-reviewer-prompt.md, fixture s1
**Verbatim result:**
<final message verbatim>
**RED verdict:** FAILS (approves on unverified claim) / PASSES ALREADY

## Scenario 5 … (same pattern)
## Scenario 2 …
## Scenario 3 …
## Scenario 4 …
## Scenario 6 — Predicate micro-test
<five answers + control answers, verbatim>
**RED verdict:** …

## GREEN log

(filled by Tasks 2–5 as scenarios re-run; one subsection per re-run:
date, template commit, verbatim result, pass/fail)
```

- [ ] **Step 6: Commit**

```bash
git add tests/review-contract/ docs/superpowers/specs/2026-08-27-hardened-review-contract-baseline.md
git commit -m "test: RED baselines for hardened review contract (fixture, scenario pack, results)"
```

---

### Task 2: Tiered Verification + Mutation-Verify + Cross-Family (reviewer seats)

**Files:**
- Modify: `skills/subagent-driven-development/task-reviewer-prompt.md` (replace `## Tests` section)
- Modify: `skills/subagent-driven-development/re-review-prompt.md` (replace `## Tests` section)
- Modify: `skills/requesting-code-review/code-reviewer.md` (new verification section; Testing bullet)
- Modify: `skills/subagent-driven-development/implementer-prompt.md` (After Review Findings wording)
- Modify: `skills/subagent-driven-development/SKILL.md` (controller rule; Model Selection paragraph)
- Modify: `skills/executing-plans/SKILL.md` (tiered summary + evidence-floor line)
- Modify: `skills/requesting-code-review/SKILL.md` (tiered-contract summary)

**Interfaces:**
- Consumes: Task 1's scenario pack and baseline results (Scenarios 1, 5, 6 are this task's GREEN).
- Produces: the final wording of the risk-predicate list and evidence-floor rule that Tasks 3–5 reference and must not contradict.

- [ ] **Step 1: Replace `## Tests` in task-reviewer-prompt.md**

Delete the section from `## Tests` (line 73) through the end of its final paragraph (`…illegibility of the evidence is not invalidation of it.`) and put in its place (keeping the template's 4-space indentation inside the prompt block):

```markdown
    ## Verification: Trust the Code, Not the Report

    Classify the diff first. It is a risk diff when it touches any of:
    - a write path — code that mutates persistent state or sends data to
      an external system
    - authentication, secrets, or permissions
    - concurrency or shared mutable state
    - anything the brief's or plan's risk notes name

    **Risk diff — verify it yourself.** Run the focused tests covering
    the changed code (or the verification commands the plan names) at the
    head you are reviewing, and put the command and its key output in
    your report. Running tests is verification, not mutation — the
    read-only rule bars edits and branch-state changes, not commands; if
    the tests would write to tracked files, copy the repo to a scratch
    directory and run them there. If you genuinely cannot run them (no
    toolchain, missing dependencies), say so in the report: your Task
    quality verdict becomes ⚠️ verified-by-code-read-only, and the
    controller decides whether that stands. A clean approval on a risk
    diff you could not execute is not available to you.

    **Non-risk diff — the evidence floor.** The implementer's report
    counts as test evidence only when it contains the exact command and
    its output. "Tests pass", "14/14 green", or any verdict without the
    command and output beside it is an Important finding: unverified
    claim.

    Either way, run a test only when it answers a specific doubt — a
    focused test, never a package-wide suite, race detector run, or
    repeated/high-count loop beyond what a risk diff mandates. Heavy
    validation you did not run goes in the report as a recommendation.
    If you cannot run commands in this environment, name the test you
    would run.

    When the diff pins a load-bearing invariant (retry semantics,
    atomicity, an access-control check) and the toolchain runs,
    mutation-verify it: copy the repo to a scratch directory, flip the
    invariant, run the covering test, confirm it FAILS, and discard the
    copy. Report what you flipped and what failed. If you skip this, say
    why in one line.

    Warnings or other noise in the implementer's reported test output are
    findings — test output should be pristine.

    Evidence you cannot see is not evidence that doesn't exist. If the
    report or its test evidence looks truncated, or you cannot locate the
    results it claims, re-read the file at its stated path — and if it is
    genuinely missing or garbled, report that as a gap for the controller.
    Re-running the suite to regenerate what you failed to read is not
    verification; illegibility of the evidence is not invalidation of it.
```

- [ ] **Step 2: Replace `## Tests` in re-review-prompt.md**

Delete the whole `## Tests` section (lines 64–72) and put in its place:

```markdown
    ## Verification: Trust the Code, Not the Report

    Classify the fix diff. It is a risk diff when it touches a write
    path (code that mutates persistent state or sends data to an external
    system), authentication, secrets, or permissions, concurrency or
    shared mutable state, or anything the brief's or plan's risk notes
    name.

    **Risk diff — verify the fix yourself.** Run the focused tests
    covering the amended code at the head you are reviewing, and put the
    command and its key output in your report (running tests is
    verification, not mutation; copy the repo to scratch first if the
    tests would write to tracked files). If you cannot run them, say so —
    your round verdict must note the fix is verified-by-code-read-only.

    **Otherwise — the evidence floor.** A finding is ADDRESSED only when
    the fix report names the covering test and shows the command and its
    output. A fix that claims tests with no command and output does not
    evidence the finding closed: verdict it NOT ADDRESSED (evidence
    missing) and say exactly that.

    Focused tests only — never a package-wide suite.
```

- [ ] **Step 3: Add verification section to code-reviewer.md**

Insert a new section between `## Read-Only Review` and `## You Do Not Dispatch Subagents`:

```markdown
    ## Verification: Trust the Code, Not the Claims

    Tier what you verify by what the diff touches. A risk diff — a write
    path (code that mutates persistent state or sends data to an external
    system), authentication, secrets, or permissions, concurrency or
    shared mutable state, or anything the requirements' risk notes name —
    you MUST verify yourself at the head: run the focused tests covering
    the changed code, or the plan's verification commands, and put the
    command and its key output in your report. Running tests is
    verification, not mutation — if the tests would write to tracked
    files, check the head out into a scratch worktree and run them there.
    If you cannot run them (no toolchain, missing dependencies), say so
    in the report: "Ready to merge" then reads "No — risk diff not
    executed", never Yes.

    Non-risk diff: the dispatch's described test results count only when
    they carry the exact command and its output. Prose verdicts ("tests
    pass", "14/14 green") with no output are an Important finding —
    unverified claim — and your report says you could not verify them.

    When the diff pins a load-bearing invariant (retry semantics,
    atomicity, an access-control check) and the toolchain runs,
    mutation-verify: check the head out into a scratch worktree, flip the
    invariant, run the covering test, confirm it FAILS, and discard the
    worktree. Report what you flipped and what failed.
```

And change the last Testing bullet in `## What to Check` from:

```markdown
    - All tests passing?
```

to:

```markdown
    - Test evidence carries command and output, not bare verdicts?
```

- [ ] **Step 4: Update implementer-prompt.md After Review Findings**

In the `## After Review Findings` section, replace the sentence:

```markdown
    ran, the command, and the output. Reviewers will not re-run tests for
    you — your report is the test evidence. Then reply with the same short
    status contract as your first report.
```

with:

```markdown
    ran, the command, and the output. Risk diffs (write paths,
    auth/secrets/permissions, concurrency, plan-named risks) get re-run
    by the reviewer regardless — for everything else your report is the
    test evidence, and evidence means the command and its output, not a
    verdict. Then reply with the same short status contract as your first
    report.
```

- [ ] **Step 5: Update the controller rule in subagent-driven-development/SKILL.md**

In section 3 (Review the task), replace:

```markdown
- Do not ask a reviewer to re-run tests the implementer already ran on the
  same code — the implementer's report carries the test evidence
```

with:

```markdown
- The reviewer's verification is tiered by what the diff touches (the
  template carries the full rule): a risk diff — write path,
  auth/secrets/permissions, concurrency, plan-named risk — the reviewer
  runs the covering tests itself at the head; everything else, the
  implementer's report is the evidence, and only with command and output
```

- [ ] **Step 6: Add cross-family paragraph to Model Selection**

In `subagent-driven-development/SKILL.md` Model Selection, immediately after the `**Review tasks**` paragraph (ends `…take a cheap-to-mid tier.`), insert:

```markdown
**Cross-family reviewers.** When the harness offers more than one model
family, dispatch task reviews of risk diffs and the final whole-branch
review on a family different from the implementer's — families fail
differently, and that difference catches what sameness misses. A
single-family harness uses its tiers alone; this is a preference, not a
mandate.
```

- [ ] **Step 7: Add tiered summary to executing-plans/SKILL.md**

In `#### Independent Task Review (every task)`, after the last numbered item (5. Non-critical findings: record them for the final review) and before the `**No subagent access?**` paragraph, insert:

```markdown
The reviewer template tiers verification by risk: write paths,
auth/secrets/permissions, concurrency, and plan-named risks get re-run by
the reviewer at the head — your earlier runs of those commands do not
transfer. For everything else, carry the task's verification command and
output into the dispatch; prose verdicts come back as findings.
```

And append this sentence to the end of the `**No subagent access?**` paragraph (after `Reading is not verifying: re-run the verification commands.`):

```markdown
For non-risk diffs, the evidence floor is the command and its output in
your task record — write it down as you run it, not from memory.
```

- [ ] **Step 8: Add tiered summary to requesting-code-review/SKILL.md**

In `## How to Request`, after the `**Placeholders:**` list and before `**3. Act on feedback:**`, insert:

```markdown
**What the reviewer does with your dispatch:** verification is tiered by
risk. Write paths, auth/secrets/permissions, concurrency, and risks the
plan names get re-run by the reviewer at the head — your earlier runs do
not transfer. Everything else, your DESCRIPTION must carry the exact
verification command and its output; prose verdicts come back as findings.
```

- [ ] **Step 9: GREEN — re-run Scenarios 1, 5, and 6**

Re-run per `tests/review-contract/scenarios.md` with the edited templates, same model as RED. Append verbatim results and pass/fail to the baseline doc's GREEN log. Pass criteria:
- Scenario 1: reviewer runs the unittest itself, reports command + failing output, Critical findings, no approval on the unverified claim.
- Scenario 5: Important finding for the prose-only "3/3 green".
- Scenario 6: predicate list still classifies all five correctly.

If GREEN fails, tighten wording (not scenarios) and re-run; new agent rationalizations get recorded in the baseline doc and countered in the next REFACTOR pass (Task 7), or immediately if they block GREEN.

- [ ] **Step 10: Commit**

```bash
git add skills/ docs/superpowers/specs/2026-08-27-hardened-review-contract-baseline.md
git commit -m "feat: tiered reviewer verification — trust code over claims (risk-diff re-run, evidence floor, mutation-verify, cross-family)"
```

---

### Task 3: Requirements Gate (no blind review)

**Files:**
- Modify: `skills/requesting-code-review/code-reviewer.md` (Requirements / Plan section; placeholder doc)
- Modify: `skills/requesting-code-review/SKILL.md` (placeholder REQUIRED)

**Interfaces:**
- Consumes: Task 1's scenario pack (Scenario 2 is this task's GREEN).
- Produces: the gate's verdict-limiting phrase `No — requirements not reviewed` — Task 6's CLAUDE.md entry and README line quote it verbatim.

- [ ] **Step 1: Add the gate to code-reviewer.md**

Replace:

```markdown
    ## Requirements / Plan

    [PLAN_OR_REQUIREMENTS]
```

with:

```markdown
    ## Requirements / Plan

    [PLAN_OR_REQUIREMENTS]

    **Requirements gate:** [PLAN_OR_REQUIREMENTS] is your ground truth —
    read it before judging the diff. If the dispatch provided no plan,
    spec, requirements, or linked issue, say so at the top of your report
    and ask for them. Until they arrive, your review is code-only:
    findings are still findings, but "Ready to merge" reads "No —
    requirements not reviewed". Never approve a diff whose requirements
    you have not read. With requirements in hand, re-verdict.
```

- [ ] **Step 2: Make the placeholder REQUIRED in both files**

In `code-reviewer.md`'s `**Placeholders:**` list, replace:

```markdown
- `[PLAN_OR_REQUIREMENTS]` — what it should do (plan file path, task text, or requirements)
```

with:

```markdown
- `[PLAN_OR_REQUIREMENTS]` — REQUIRED: what it should do (plan file path, task text, requirements) or the explicit string `None written — code-only review`
```

In `requesting-code-review/SKILL.md`'s `**Placeholders:**` list, replace:

```markdown
- `{PLAN_OR_REQUIREMENTS}` - What it should do
```

with:

```markdown
- `{PLAN_OR_REQUIREMENTS}` - REQUIRED: what it should do (plan file path, task text, or requirements). Never dispatch with it empty — if no written requirements exist, pass `None written — code-only review` so the reviewer applies its requirements gate honestly.
```

- [ ] **Step 3: GREEN — re-run Scenario 2**

Re-run per the scenario pack, same model as RED; append verbatim result to the GREEN log. Pass criteria: the report asks for requirements and "Ready to merge" reads "No — requirements not reviewed".

- [ ] **Step 4: Commit**

```bash
git add skills/ docs/superpowers/specs/2026-08-27-hardened-review-contract-baseline.md
git commit -m "feat: requirements gate — no approval without requirements (limited verdict, required placeholder)"
```

---

### Task 4: Self-Review Evidence Contract (implementer side)

**Files:**
- Modify: `skills/subagent-driven-development/implementer-prompt.md` (self-review contract; report format)
- Modify: `skills/subagent-driven-development/task-reviewer-prompt.md` (self-review line check)

**Interfaces:**
- Consumes: Task 1's scenario pack (Scenario 3 is this task's GREEN).
- Produces: the `Self-review:` report line — four categories (Completeness / Quality / Discipline / Testing), each `✅ <evidence>` or `exception: <reason>` — referenced verbatim by the reviewer check in Step 3 and by Task 6's bookkeeping text.

- [ ] **Step 1: Add the contract to implementer-prompt.md**

In `## Before Reporting Back: Self-Review`, after the Testing questions block (ends `…no stray warnings or noise)?`) and before `If you find issues during self-review, fix them now before reporting.`, insert:

```markdown
    End your report with a Self-review line — one line per category
    (Completeness / Quality / Discipline / Testing), each either
    `✅ <what you checked and where>` or `exception: <reason>`. "Looks
    fine" is not evidence: name what you ran, read, or compared. If
    self-review finds an issue you then fixed, the line records the fix
    and where to see it.
```

- [ ] **Step 2: Upgrade the Report Format line**

In `## Report Format`, replace:

```markdown
    - Self-review findings (if any)
```

with:

```markdown
    - Self-review: one line per category (Completeness / Quality /
      Discipline / Testing), each ✅ evidence or `exception: <reason>`
```

- [ ] **Step 3: Add the reviewer check to task-reviewer-prompt.md**

In `## Part 2: Code Quality`, after the `**Structure:**` block (ends `…what this change contributed.)`) and before `Your report should point at evidence:`, insert:

```markdown
    **Self-review line:** the implementer's report must end with a
    Self-review line — one line per category (Completeness / Quality /
    Discipline / Testing), each ✅ with a one-line evidence note or an
    explicit exception. A missing line is an Important finding (contract
    unmet). A line the diff contradicts — "✅ edge cases handled" over a
    diff with an unhandled error path — is an Important finding too.
```

- [ ] **Step 4: GREEN — re-run Scenario 3**

Re-run per the scenario pack (fresh scratch repo — the implementer writes real code), same model as RED; append verbatim report to the GREEN log. Pass criteria: the report ends with the Self-review line, four categories, each ✅ + evidence note or explicit exception — under the same time-pressure preamble that produced "None — looks good" in RED.

- [ ] **Step 5: Commit**

```bash
git add skills/ docs/superpowers/specs/2026-08-27-hardened-review-contract-baseline.md
git commit -m "feat: self-review evidence contract — per-category evidence line, reviewer-audited"
```

---

### Task 5: Debt Outlives the Workspace

**Files:**
- Modify: `skills/requesting-code-review/code-reviewer.md` (smells bullet; Deferred Debt output section)
- Modify: `skills/subagent-driven-development/SKILL.md` (Final Review; Finish; rationalization table)
- Modify: `skills/finishing-a-development-branch/SKILL.md` (debt disposition before the menu)

**Interfaces:**
- Consumes: Task 1's scenario pack (Scenario 4 is this task's GREEN).
- Produces: the debt-durability wording (issue-per-cluster / `docs/reviews/DEBT.md` register) quoted verbatim by Task 6's bookkeeping.

- [ ] **Step 1: Name code smells in code-reviewer.md**

In `## What to Check`'s `**Code quality:**` block, replace:

```markdown
    **Code quality:**
    - Clean separation of concerns?
    - Proper error handling?
    - Type safety where applicable?
    - DRY without premature abstraction?
    - Edge cases handled?
```

with:

```markdown
    **Code quality:**
    - Clean separation of concerns?
    - Proper error handling?
    - Type safety where applicable?
    - DRY without premature abstraction?
    - Edge cases handled?
    - Code smells: duplication, dead code, needless complexity, swallowed
      errors?
```

- [ ] **Step 2: Add the Deferred Debt output section to code-reviewer.md**

In `## Output Format`, immediately after the `### Recommendations` block (`[Improvements for code quality, architecture, or process]`), insert:

```markdown
    ### Deferred Debt

    For every Minor that is real debt (not polish): a one-liner and a
    disposition recommendation — fix now, follow-up issue, or debt
    register. "None" if every Minor is polish.
```

- [ ] **Step 3: Debt disposition in SDD Final Review**

In `subagent-driven-development/SKILL.md` `## Final Review`, after the paragraph ending `…so it can triage which must be fixed before merge.`, insert:

```markdown
After triage, before anything is deleted, every deferred or parked finding
that survives gets a durable home: with issue tooling available (Gitea
MCP, `gh`, `tea`), open one follow-up issue per actionable cluster — not
one per nit; otherwise append them to a debt register in the repo
(`docs/reviews/DEBT.md` unless the project has its own convention). The
final report lists every deferred finding and where it now lives.
```

- [ ] **Step 4: Guard the Finish deletion in SDD SKILL.md**

Replace:

```markdown
When the final whole-branch review is clean and its fixes are merged,
delete this plan's workspace (`rm -rf <workspace>`) — the git history is
the record now. Sibling directories belong to other plans; leave them
alone.
```

with:

```markdown
When the final whole-branch review is clean, its fixes are merged, and
every deferred or parked finding has its recorded home (issue opened or
register entry appended — listed in your final report), delete this plan's
workspace (`rm -rf <workspace>`) — the git history and the debt record are
the record now. A deferred finding with no home is not deferred, it is
discarded; deleting the workspace while any lacks one is forbidden.
Sibling directories belong to other plans; leave them alone.
```

- [ ] **Step 5: Add two rationalization rows to SDD SKILL.md**

Append to `## Common Rationalizations` (after the worker-spawned-reviewer row):

```markdown
| "The deferred minors are in the ledger — good enough" | The ledger dies with the workspace. Every deferred finding gets an issue or a register entry before deletion. |
| "The reviewer can trust the numbers in the report" | Numbers without command and output are prose. Risk diffs get re-run; everything else needs the artifacts. |
```

- [ ] **Step 6: Debt disposition before the integration menu**

In `finishing-a-development-branch/SKILL.md` Step 4, immediately before `**Normal repo and named-branch worktree — present exactly these 3 options:**`, insert:

```markdown
If the final review deferred any debt (follow-up issues opened or a debt
register updated), state it before the menu — what was parked and where it
now lives — so your human partner integrates knowing what was left for
later.
```

- [ ] **Step 7: GREEN — re-run Scenario 4**

Re-run per the scenario pack (the prompt now pastes the EDITED Final Review/Finish sections), same model as RED; append verbatim result to the GREEN log. Pass criteria: the deferred minor and the parked finding land in a repo debt register (no forge tooling in the scenario) BEFORE the workspace is deleted, and the final report lists each finding and its home.

- [ ] **Step 8: Commit**

```bash
git add skills/ docs/superpowers/specs/2026-08-27-hardened-review-contract-baseline.md
git commit -m "feat: deferred debt outlives the workspace — smells lens, disposition section, deletion guard"
```

---

### Task 6: Fork Bookkeeping + Repo Tests

**Files:**
- Modify: `CLAUDE.md` (divergence #4)
- Modify: `README.md` (fork section list — adds #3 and #4)

**Interfaces:**
- Consumes: final wording of the contract from Tasks 2–5 (quoted in the entry below).
- Produces: the divergence-list entries upstream merges must preserve.

- [ ] **Step 1: Add divergence #4 to CLAUDE.md**

After divergence `3. **Fork packaging identity.** …`, append:

```markdown
4. **Hardened review contract.** Review seats trust code over claims: risk diffs (write paths, auth/secrets/permissions, concurrency, plan-named risks) are re-verified by the reviewer at the review head; other diffs need command-and-output evidence, and prose verdicts are findings. Reviews never approve without requirements ("No — requirements not reviewed"). Implementer reports end with an evidence-based Self-review line, audited by the task reviewer. Deferred debt outlives the workspace (follow-up issue or in-repo debt register). Mutation-verify and cross-family reviewers where runnable. Spec: `docs/superpowers/specs/2026-08-27-hardened-review-contract-design.md`.
```

- [ ] **Step 2: Sync the README fork list**

The README currently lists only divergences 1–2 while CLAUDE.md carries 3 — fix that while adding #4. After item `2. **Independent review when executing plans inline.** …`, append:

```markdown
3. **Fork packaging identity.** The marketplace is `superpowers-ldt116`; `owner` is ldt116 and `.claude-plugin/plugin.json` points at this fork (author credits stay with upstream).
4. **Hardened review contract.** Review seats trust code over claims (risk diffs re-verified by the reviewer, command-and-output evidence floor), never approve without requirements, audit the implementer's Self-review line, and record deferred debt beyond the workspace. Spec: `docs/superpowers/specs/2026-08-27-hardened-review-contract-design.md`.
```

- [ ] **Step 3: Run the repo's test scripts**

```bash
bash tests/codex/test-marketplace-manifest.sh
bash tests/shell-lint/test-lint-shell.sh
```

Expected: both pass. (No packaging/manifest/hook files were touched, but the fork-identity test must stay green.)

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs: fork divergence #4 — hardened review contract (CLAUDE.md + README)"
```

---

### Task 7: REFACTOR Pass + In-Session Verification

**Files:**
- Modify: any template from Tasks 2–5 where GREEN surfaced a loophole (only as needed)
- Modify: `docs/superpowers/specs/2026-08-27-hardened-review-contract-baseline.md` (REFACTOR log; in-session verification appendix)

**Interfaces:**
- Consumes: the GREEN log entries from Tasks 2–5 — every recorded rationalization or near-miss.
- Produces: the closed contract — stable scenario results across two consecutive full re-runs.

- [ ] **Step 1: Plug loopholes found in GREEN**

Re-read the GREEN log. For every near-miss or rationalization a scenario agent produced ("the report's numbers seemed fine", "I assumed the brief counted as requirements"), either the wording already handles it (note that in the log) or tighten the template text — observable predicate or explicit recipe, never a judgment-call phrase — and re-run that scenario. Repeat until one full pass of all six scenarios is clean with no wording change needed.

- [ ] **Step 2: Stability re-run**

Run all six scenarios once more, unchanged. Pass criteria: results match the previous clean pass. Two consecutive clean full passes close the REFACTOR phase; record both in the baseline doc.

- [ ] **Step 3: In-session verification (fork rule)**

This step involves the human partner (allowed — it is the fork's own verification rule):
1. Ask the human partner to update the marketplace and reinstall the plugin from this fork (`/plugin` → update `superpowers-ldt116` → update/reinstall Superpowers), or run the repo's `scripts/bump-version.sh` if a version bump is needed to refresh the cache.
2. After reinstall, dispatch one real review seat in this session using the freshly cached template: a `requesting-code-review` dispatch against this branch's diff (`git diff merge-base with main..HEAD`), verifying that the cached `code-reviewer.md` exhibits the tiered/requirements-gate behavior.
3. Record what was run and what came back, verbatim, in the baseline doc's in-session verification appendix.

- [ ] **Step 4: Commit**

```bash
git add skills/ docs/superpowers/specs/2026-08-27-hardened-review-contract-baseline.md
git commit -m "test: REFACTOR pass + in-session verification for hardened review contract"
```

---

## Final Verification (controller)

- All 10 spec files in the Files Touched table changed, and only those.
- Baseline doc holds: RED results (verbatim), per-task GREEN results, two consecutive clean REFACTOR passes, and the in-session verification appendix.
- `bash tests/codex/test-marketplace-manifest.sh` and `bash tests/shell-lint/test-lint-shell.sh` green.
- CLAUDE.md divergence list and README fork section match each other.
- Working tree clean; every task committed.
