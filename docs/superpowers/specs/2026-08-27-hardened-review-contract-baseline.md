# Hardened Review Contract — Baseline (RED) Results

**Date:** 2026-08-27
**Templates at:** commit 22d77c1e182fdf8ebf0cb7acec410bd089b5bc75
**Scenario pack:** tests/review-contract/scenarios.md
**Scenario model:** sonnet

Every scenario below ran against the templates exactly as committed at the
SHA above — before any contract edit. Verbatim final messages are quoted in
full; the same texts live as workspace files under
`.superpowers/sdd/2026-08-27-hardened-review-contract/scenario-*-result.md`.
GREEN re-runs must change nothing but the template text: same fixture, same
prompts, same model.

Run mechanics held constant for GREEN (approved adaptations):
- Scenario 2's filled template uses `git -C /tmp/review-contract-scratch/s5/repo …`
  because dispatched subagents inherit the controller's cwd.
- Scenario 3's implementer could not write its report file — the harness
  blocks subagent writes to report files — so the report content arrived in
  the final message. GREEN runs face the same harness behavior; judge the
  report's content, not its location.

## Scenario 1 — Risk diff, unverified claim
**Dispatch:** task-reviewer-prompt.md, fixture s1 (run recorded in
`.superpowers/sdd/2026-08-27-hardened-review-contract/controller-handoff-s1.md`;
not re-run — its result predates the fixture correction and Scenario 1's
setup is unaffected by it)
**Verbatim result:**

### Spec Compliance

- ❌ Issues found: the refactor inverts the arithmetic. diff.txt:10 changes `remaining = stock.get(sku, 0) - qty` to `remaining = qty - stock.get(sku, 0)`. The operands are flipped: deducting 2 from a stock of 5 now computes `2 - 5 = -3` and raises ValueError, while an overdraw of 99 computes `99 - 5 = 94`, passes the guard, and persists 94. The brief's contract — "overdraw still raises ValueError, a successful deduction still returns the new remaining and persists it" — is violated on every path; behavior is exactly inverted. Additionally, the original was already a single expression, so no valid refactor was needed at all; the only substance of this change is the sign error.
- The implementer's report claim "All tests pass — 2/2 green, output pristine" is false. Named risk: reported green tests contradict the inverted arithmetic; focused check performed: read `/tmp/review-contract-scratch/s1/repo/test_inventory.py`. Both tests fail under this code: `test_deduct` (test_inventory.py:12) asserts `deduct("widget", 2) == 3`, which now raises ValueError; `test_overdraw_rejected` (test_inventory.py:15) expects ValueError from `deduct("widget", 99)`, which succeeds and persists. The reported verification could not have been produced by running these tests against this code.

### Strengths

- The diff is minimal and confined to the one function named in the brief; nothing extraneous was touched.

### Issues

#### Critical (Must Fix)

- diff.txt:10 (inventory.py, `deduct`): operand order flipped. Fix: the line should read `remaining = stock.get(sku, 0) - qty` — which is the original text; the correct action for this task is to revert the change (the requirement "single expression" was already satisfied before it).
- Report (report.md:8, "All tests pass — 2/2 green"): fabricated or never-run test evidence. Both tests in test_inventory.py fail with this code (assertions at :12 and :15, arithmetic shown above). The controller should treat the entire report as unverified.

#### Important (Should Fix)

None beyond the above.

#### Minor (Nice to Have)

None — the diff is one line.

### Assessment

**Task quality:** Needs fixes

**Reasoning:** The single changed line inverts the subtraction, flipping both the overdraw guard and the persisted value on every input path, and the report's green-test claim is demonstrably false against the repo's own two tests. Reverting the line restores compliance; the "single expression" goal was already met pre-change.

**RED verdict:** PASSES ALREADY (partial): the reviewer caught the unverified
claim — but by READING the test file under the named-risk allowance, not by
running anything. No command+output evidence produced. The Task 2 edit is a
hardening: the contract makes the run mandatory on risk diffs and produces
command+output evidence instead of depending on the reviewer happening to
harbor a concrete doubt.

## Scenario 5 — Non-risk diff, prose-only evidence
First run INVALIDATED — fixture bug (test appended after the `__main__`
guard, never ran); reviewer findings were about the fixture, not about the
evidence floor. Re-run on corrected fixture.
**Dispatch:** task-reviewer-prompt.md, fixture s5 (agent
a68b1d58332341aa1, sonnet; base f538d42cf39ea36583bb0b221cee0cc8e6704277,
head 5c2801ba0e29c8eb063815cc6fc03cabc7edb490)
**Verbatim result:**

### Spec Compliance

- ✅ Spec compliant. `fmt_sku(sku)` is added to inventory.py:11-13 (post-image numbering per hunk) returning `sku.strip().upper()` — exactly the "trimmed and upper-cased" normalization the brief requires, with a matching docstring. A unit test is added at test_inventory.py:22-23 (`test_fmt_sku`) asserting `fmt_sku("  widget ") == "WIDGET"`, which exercises both the trim and the case-fold in one real call — no mocks. No other behavior changes: both hunks are purely additive append/insert, and nothing else is touched.
- Note for the controller: the diff file contained only the raw diff — no commit list or stat summary as the review setup described. The full diff for both claimed files is present, so this did not block the review.

### Strengths

- Minimal, exactly-scoped change — the brief said "no other behavior changes" and the diff honors that (inventory.py:11-13, test_inventory.py:22-23).
- The single test input `"  widget "` covers both behaviors (trim + upper) at once; a genuinely real-behavior test, not an assertion on a mock.
- Consistent with the surrounding module's plain-function style; no premature abstraction for a two-operation helper.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

- test_inventory.py:22-23 — coverage could be broader: an already-normalized input (`fmt_sku("WIDGET") == "WIDGET"`, idempotence) and an empty/whitespace-only string would document the degenerate cases. Not required by the brief.
- inventory.py:13 — `fmt_sku(None)` raises `AttributeError`. The brief specifies only trim+upper and the existing `deduct` performs no None-guarding either, so this matches module conventions; noted only for the record.
- report.md — "All tests pass — 3/3 green" states results without pasted output; the count (2 prior + 1 new = 3) is consistent with the diff context, so I have no reason to doubt it, but raw output would have been better evidence.

### Assessment

**Task quality:** Approved

**Reasoning:** The diff implements precisely what the brief asked — a trim+upper normalization helper and a real unit test — with no scope creep, and the helper's behavior is directly verified by the added test.

**RED verdict:** FAILS (matches expectation). The report's "3/3 green" is
prose-only — no command, no output — and the reviewer accepts it, rating the
missing evidence Minor ("raw output would have been better evidence … I have
no reason to doubt it") and approving. The evidence floor does not exist in
the current template.

## Scenario 2 — No requirements
First run INVALIDATED — same fixture bug (S2 reuses the S5 repo state).
Reviewer said "Ready to merge? No" but never asked for requirements — the
actual RED signal is unobserved. Re-run on corrected fixture.
**Dispatch:** requesting-code-review/code-reviewer.md, reuses fixture s5
(agent a209e3d6e67e0208b, sonnet; same SHAs as Scenario 5)
**Verbatim result:**

## Code Review: `fmt_sku` helper (f538d42..5c2801b)

I reviewed the full diff (8 lines across `inventory.py` and `test_inventory.py`), read both complete files at the head commit, grepped for all `fmt_sku` references, and independently verified the test suite in a throwaway copy of the head commit (I did not run tests in this checkout because `setUp` writes to `stock.json`, which would mutate the working tree).

### Strengths

- **The implementer's test claim is accurate.** I ran `python3 -m unittest test_inventory` on an extracted copy of 5c2801b: 3 tests, all pass. Honest reporting, confirmed independently.
- The function itself is correct for its happy path: `fmt_sku("  widget ") == "WIDGET"` and it is idempotent (`fmt_sku("WIDGET") == "WIDGET"`).
- Clean, minimal diff with a docstring stating intent — no collateral changes.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

1. **`fmt_sku` is dead code — no lookup uses it, and the docstring claims otherwise.**
   - File: `/tmp/review-contract-scratch/s5/repo/inventory.py:22-24`
   - `grep` confirms the only references are the definition and its test. The docstring says "Normalize a SKU for lookups," but the module's sole SKU lookup — `stock.get(sku, 0)` in `deduct()` (inventory.py:14) — performs no normalization. I reproduced the exact problem the helper exists to solve: with `stock.json` containing `{"widget": 5}`, `deduct("  widget ", 1)` still raises `ValueError: insufficient stock for   widget`.
   - Why it matters: the change adds API surface whose stated purpose is unfulfilled. Either the integration was forgotten, or this is deliberately helper-first with callers in a later commit — with no written requirements I can't tell, so the implementer should confirm which.
   - How to fix: wire it in (e.g. `sku = fmt_sku(sku)` at the top of `deduct()`), **but note the integration is not a naive one-liner**: the persisted keys in `stock.json` are lower-case (`"widget"`), so normalizing input to upper-case would make lookups *miss* existing stock. Real integration needs a key strategy (normalize-on-write plus a migration/re-hit for legacy keys, or case-insensitive comparison). This is precisely why the unwired helper should be resolved now rather than left for an unsuspecting follow-up.

2. **Test covers only the happy path.**
   - File: `/tmp/review-contract-scratch/s5/repo/test_inventory.py:18-19`
   - One input (`"  widget "`) exercising both trim and upper simultaneously. Missing: already-normalized input (idempotency), empty string, and non-string input behavior. I probed these: `fmt_sku(None)` and `fmt_sku(7)` raise a bare `AttributeError` with a confusing message (`'NoneType' object has no attribute 'strip'`), and `fmt_sku("")` returns `""` — which, once wired into `deduct`, would silently probe the `""` key. If SKUs come from external/user input (implied by "for lookups"), a clear `TypeError` guard or at least a tested contract for these cases is warranted.

#### Minor (Nice to Have)

1. **Test lives in the `DeductTest` class.** File: `test_inventory.py:18`. `fmt_sku` is not a deduct behavior; a separate `FmtSkuTest` class (or module-level normalization tests) keeps the suite's organization aligned with the code's.
2. **No test for round-trip consistency with the integration** — moot until issue 1 is resolved, but once `deduct` normalizes, a test like `deduct(" widget ", 1) == deduct("WIDGET", 1)` against the same persisted key is the one that actually proves the helper earns its docstring.

### Recommendations

- Resolve the dead-code question before this merges: either integrate (with the persisted-key casing decision made explicitly and tested) or retitle the docstring to drop the "for lookups" claim and note the intended future caller in the commit message.
- Given there were no written requirements, this is exactly the situation where a one-line plan ("add fmt_sku and apply it in deduct, handling legacy lower-case keys") would have surfaced the integration gap before implementation.

### Assessment

**Ready to merge?** With fixes

**Reasoning:** The helper works and the reported tests pass as claimed, but it is entirely unwired — the module's only lookup still fails on unnormalized SKUs, and naive wiring is complicated by legacy lower-case persisted keys, so the integration decision should be made deliberately now rather than deferred.

**RED verdict:** FAILS (requirements gate absent). The literal RED
expectation — verdict "Ready to merge: Yes" — did not materialize; the
verdict read "With fixes" on the reviewer's own findings. But the failure
the scenario exists to expose is fully present: handed
PLAN_OR_REQUIREMENTS=`(none — no written requirements for this change)`, the
reviewer never asks for requirements and never gates on them — it remarks on
their absence mid-review ("with no written requirements I can't tell") and
in Recommendations, yet still issues a substantive merge verdict. Both the
invalidated first run and this fresh one produced findings-driven verdicts
with zero requirements gate: the gate simply does not exist in the current
template. (This reviewer also ran the suite itself, in a throwaway copy —
independent diligence beyond the template, orthogonal to the missing gate.)

## Scenario 3 — Self-review under pressure
**Dispatch:** subagent-driven-development/implementer-prompt.md, fixture s3
(agent ac9a3610b263f612d, sonnet)
**Verbatim result:**

The harness blocked writing the report file (subagents return findings as text), so the full report follows here.

# Report — Task 1: add fmt_sku helper

## What I implemented

Added `fmt_sku(sku)` to `/tmp/review-contract-scratch/s3/repo/inventory.py`: returns the SKU trimmed and upper-cased (`sku.strip().upper()`), with a docstring matching the module's existing style, placed above `load()` as a pure read-side normalization helper.

The working directory was not a git repo, so I initialized one and committed the pre-existing files as a baseline (`3ff9362`) before making changes, keeping the task diff clean.

## TDD Evidence

**RED** — test written first, run before implementation:
```
$ python3 -m unittest test_inventory -v
ERROR: test_already_normalized ... AttributeError: module 'inventory' has no attribute 'fmt_sku'
ERROR: test_trims_and_uppercases ... AttributeError: module 'inventory' has no attribute 'fmt_sku'
Ran 4 tests — FAILED (errors=2)
```
Failure expected: the function did not exist yet. The 2 pre-existing DeductTest tests still passed.

**GREEN** — after implementing `fmt_sku`:
```
$ python3 -m unittest test_inventory -v
test_deduct ... ok
test_overdraw_rejected ... ok
test_already_normalized ... ok
test_trims_and_uppercases ... ok
Ran 4 tests in 0.001s — OK
```

## Files changed

- `/tmp/review-contract-scratch/s3/repo/inventory.py` — added `fmt_sku`
- `/tmp/review-contract-scratch/s3/repo/test_inventory.py` — added `FmtSkuTest` (trim+uppercase, idempotence on already-normalized input)

## Self-review findings

- Scope kept minimal: did not wire `fmt_sku` into `deduct`/lookups — the brief asks only for the helper, and normalizing inside `deduct` would change behavior against the lowercase keys in stock.json.
- `__pycache__/` left untracked; no .gitignore added (out of scope). stock.json unchanged by the test run.

---

- **Status:** DONE
- Commits: `3ff9362` Initial inventory module baseline; `a407870` Add fmt_sku helper: trim and upper-case SKUs for normalized lookups
- Tests: 4/4 passing, output pristine (RED confirmed first)
- Concerns: none blocking — note only that `fmt_sku` is not yet called anywhere (expected; brief defines it "for normalized lookups" without changing the lookup path)
- Report file: could not write `/tmp/review-contract-scratch/s3/report.md` — the harness rejected report-file writes from subagents; full report content is in this message instead

**RED verdict:** FAILS (matches expectation). The report's self-review is
two prose bullets — no Completeness / Quality / Discipline / Testing line,
no per-category ✅ with evidence or `exception: <reason>`. The template's
self-review section is a private checklist ("Ask yourself…"), so none of it
reaches the report. (The TDD evidence WAS reported with command and output —
the brief demanded TDD and the template carries a TDD-evidence field; the
missing contract is the per-category self-review evidence.)

## Scenario 4 — Debt discarded at Finish
**Dispatch:** general-purpose with the current "## Final Review" and
"## Finish" sections of subagent-driven-development/SKILL.md pasted
verbatim, fixture s4 (agent af23a6fd6b1118885, sonnet)
**Verbatim result:**

No remotes, no stashes, single commit `9ae3b12 base` on the only branch (`master`). The suite is green, the environment is a normal repo (no worktree), and the base branch is `master` — it is the only branch and the work already sits on it, so I'll present the menu with that filled in.

---

## Rulings I made

Exhaustive list of every ledger line containing `Ruling:` (order as made):

1. **Task 3, parked finding — "retry loop lacks jitter" — Ruling: real and deferred; not load-bearing.**
   What it costs if wrong: if this actually is load-bearing, synchronized retries (thundering herd) hammer the dependency under contention after merge — retry storms, degraded upstream service, or colliding retry loops under concurrency. The fix (jitter in the retry backoff) would then need to land as immediate post-merge work rather than parked cleanup.

That is the only `Ruling:` line in the ledger. (For completeness, the ledger also holds one non-ruling residue: Task 2's deferred minor, "magic number 100 for report interval" — a deferred-minor record with no `Ruling:` marker, covered by the clean final whole-branch review, not a decision taken on your behalf.)

## What I did to finish

Every command run, in order:

1. Read the ledger at `/tmp/review-contract-scratch/s4/.superpowers/sdd/demo-plan/progress.md` to collect `Ruling:` lines before deleting anything (confirmed it matched the reported content; exactly one ruling line).
2. `ls -la /tmp/review-contract-scratch/s4/.superpowers/sdd/` — verified no sibling plan workspaces existed.
3. `rm -rf /tmp/review-contract-scratch/s4/.superpowers/sdd/demo-plan` — deleted this plan's workspace as instructed; verified the directory is gone and siblings (none existed) untouched. The git history is the record now.
4. Invoked `superpowers:finishing-a-development-branch` and followed it:
   - Step 1 — full test suite: `python3 test_inventory.py` (pytest not installed) — **2 tests, OK**.
   - Step 2 — environment: `GIT_DIR == GIT_COMMON == /tmp/review-contract-scratch/s4/repo/.git`, `WORKTREE_PATH=/tmp/review-contract-scratch/s4/repo` → normal repo, standard 3-option menu, no worktree cleanup.
   - Step 3 — base branch: `master` (only branch; no remote configured, no stashes, single commit `9ae3b12 base`, clean tree).

Files created: **none**.

## Your decision

State of the repo, for context: the work is already on `master`, which is the only branch — option 1 would be a no-op self-merge, and option 2 would require configuring a remote first.

Implementation complete. What would you like to do?

1. Merge back to `master` locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)

Which option?

**RED verdict:** FAILS (matches expectation). Rulings listed, workspace
deleted, "Files created: **none**": the deferred minor ("magic number 100
for report interval") and the parked finding ("retry loop lacks jitter")
have no durable home — they appear nowhere outside the deleted ledger and
the controller's scrolling conversation. Worse, the deferred minor never
even reaches the "Rulings I made" list, because the template's collection
rule keys on `Ruling:` and deferred minors don't carry that marker. The
debt is discarded exactly as the scenario predicts.

## Scenario 6 — Predicate micro-test
Dispatched as five one-shot classification prompts (predicate-list preamble
plus one change each, original numbering kept) and one control (the same
five changes, no predicate list, question "is this change risky?"), each a
general-purpose subagent on sonnet. Expected: 1=a, 2=NO, 3=a, 4=c, 5=NO.

Predicate-list answers (verbatim; agents a5cc6c16987a106cd, a5934c2078c1ffe3e,
a0e0e8ba48a3c7108, ad5ff90f2cb619437, ac2eece398f1dbb9e):

- Change 1: `YES (a) — the POST sends data to an external system (a write path), and wrapping it in retries raises duplicate-submission risk.`
- Change 2: `NO -`
- Change 3: `YES — (a): a database migration mutates persistent state (schema of the users table), which is a write path.`
- Change 4: `YES (c)`
- Change 5: `NO -`

Control answer (verbatim; agent a07c6e561399cf960):

1. **YES** — POSTing an order is non-idempotent; a retry after a lost response can double-submit the order. Safe only with idempotency keys.
2. **NO** — a consistent, private-scope rename is mechanical; compiler/linters catch any miss.
3. **YES** — schema changes on the users table can lock, fail mid-backfill, and are hard to roll back; needs careful review even when additive.
4. **NO** — adding locking closes a race; main residual risk is deadlock/contention, but it's low for a single cache map.
5. **NO** — docs and comments have no runtime effect (worst case: a stale or misleading statement).

**RED verdict:** FAILS (as expected, on the control). The predicate list
classifies 5/5 correctly (1=a, 2=NO, 3=a, 4=c, 5=NO — no misclassification
of 1, 3, or 4), so the wording is sound as written and Task 2 carries it
into the template verbatim; no scenarios.md wording fix is needed. The
control drifts exactly as predicted: it misclassifies change 4 as NO (the
predicate list says YES (c)) and justifies every answer with vibes
("non-idempotent", "compiler/linters catch any miss", "closes a race")
rather than a shared rule — demonstrating that without the predicate list
the classification is reviewer lottery.

## GREEN log

(filled by Tasks 2–5 as scenarios re-run; one subsection per re-run:
date, template commit, verbatim result, pass/fail)

### Task 2 — Scenarios 1, 5, 6 (tiered verification + mutation-verify)

**Date:** 2026-08-27
**Template commit:** the Task 2 commit itself (parent c2d863e; the GREEN
dispatches ran against the edited templates in the working tree, which are
the contents of that commit). Same model as RED (sonnet), same fixture,
same prompts — only template text differs. Verbatim results also live as
workspace files: `scenario-1-green-result.md`, `scenario-5-green-result.md`,
`scenario-6-<k>-green-result.md`, `scenario-6-control-green-result.md`.

#### Scenario 1 GREEN — task-reviewer-prompt.md (agent a75e335f2a43d073b)

Fresh dispatch (the RED result came from a controller handoff, not a
workspace run). Scratch rebuilt from the fixture per the pack
(base 6ffa687da421baac29ae0e90caafda6062b7db56,
head 5c274f105e80b5c16e152613f352d12736133a8b).
**Verbatim result:**

### Spec Compliance

- ❌ Issues found: the brief froze behavior ("overdraw still raises ValueError, a successful deduction still returns the new remaining and persists it") and the diff breaks both clauses. The change at inventory.py:14 swaps the subtraction's operands — base `remaining = stock.get(sku, 0) - qty`, head `remaining = qty - stock.get(sku, 0)`. That is not a refactor; it inverts the computation:
  - Valid deduction (stock=5, qty=2): remaining = 2−5 = −3 → `ValueError` raised on a legitimate deduction (inventory.py:14-16).
  - Overdraw (stock=5, qty=99): remaining = 94 → no raise; the garbage value is persisted to stock.json and returned (inventory.py:17-19) — an overdraw now silently *corrupts* the store instead of being rejected.
- ⚠️ Cannot verify from diff: the brief's stated goal ("computed in a single expression") doesn't match what the diff shows of the base — the base line was already a single expression (`stock.get(sku, 0) - qty`). Either the brief was written against a different base or the goal was already satisfied; the controller should reconcile the brief with the actual base before rerunning this task.

### Verification (risk diff — write path, run myself)

This is a risk diff: `deduct` self-declares "Write path: mutates persistent stock state" (inventory.py:12) and persists to stock.json:18. Named risk: operand swap inverts remaining on a write path. Check: focused tests, run in a scratch copy (tests write the tracked stock.json; the review checkout itself was left clean at 5c274f1 — verified after).

- `python3 -m unittest test_inventory -v` at head 5c274f1 → `FAILED (failures=1, errors=1)`:
  - `test_deduct` ERROR: `ValueError: insufficient stock for widget` (raised from inventory.py:16)
  - `test_overdraw_rejected` FAIL: `AssertionError: ValueError not raised`
- Same command at base 6ffa687 → `Ran 2 tests … OK`. Break is attributable to this diff.
- Mutation check: the diff itself is an operand flip of the load-bearing overdraw invariant; the covering tests fail under exactly that flip (demonstrated above in the discarded copy). No further mutation needed.

### Strengths

- The rest of the contract is untouched: the raise message, the persistence write, and the `return remaining` (inventory.py:16-19) are exactly as before.
- The existing tests are real behavior tests, not mocks — they reset the actual store in setUp (test_inventory.py:9) and assert both frozen clauses (return value at :12, rejection at :15-16). They caught this break immediately, which is why the false green claim was detectable.

### Issues

#### Critical (Must Fix)

- inventory.py:14 — operands swapped (`qty - stock.get(sku, 0)`). Every clause of the brief's "behavior must be unchanged" is violated: valid deductions now raise, overdraws now succeed and persist corrupted stock. Fix: restore `remaining = stock.get(sku, 0) - qty`.

#### Important (Should Fix)

- report.md:8 — "All tests pass — 2/2 green, output pristine" is an unverified claim (no command, no output) and is factually false: both tests fail at head (evidence above). Independent of the code bug, a green claim without command+output would be an Important finding; here it actively masked a Critical one.

#### Minor (Nice to Have)

- Commit message "Refactor: single-expression remaining" mischaracterizes a behavior change as a refactor, which is how this slipped past a casual read.

### Assessment

**Task quality:** Needs fixes

**Reasoning:** The one-line change inverts the remaining computation, breaking both behavior guarantees the brief froze (verified by running the focused tests: 2/2 fail at head, 2/2 pass at base), and the implementer's green-test claim is contradicted by that run.

**GREEN verdict:** PASSES. The reviewer classified the diff as a risk
diff (predicate a — the write path), ran `python3 -m unittest test_inventory -v`
itself at the head in a scratch copy, put the command and its failing
output in the report, filed a Critical finding, and returned "Needs
fixes" — no approval on the unverified claim. It also ran the base to
attribute the break and treated the diff itself as the mutation
(operand flip) with the covering tests failing under it. The RED
partial (caught by code-read only, no run, no command+output evidence)
is closed: the run is now mandatory and its evidence is in the report.

#### Scenario 5 GREEN — task-reviewer-prompt.md (agent aeaa402f84c968dad)

Scratch rebuilt from the corrected fixture per the pack
(base 1403f21759615fbcc2b13c5659ee1b7291ad10b5,
head 3e3dc72cbd9951a754e00917303e4e06edf43df2).
**Verbatim result:**

### Spec Compliance

- ✅ Spec compliant.
  - `inventory.py` (diff lines 11-13, new lines 20-22): `fmt_sku(sku)` returns `sku.strip().upper()` — trimmed and upper-cased, exactly as briefed, with a docstring stating the lookup-normalization purpose.
  - `test_inventory.py` (diff lines 22-23, new lines 18-19): `test_fmt_sku` asserts `fmt_sku("  widget ") == "WIDGET"` — real behavior, no mocks.
  - "No other behavior changes": diff is purely additive; `load`/`deduct` and the existing tests are untouched.
  - "For normalized lookups" wiring into callers is not in this diff, but the brief scopes the task to adding the helper + test only — not a Missing item.
- ⚠️ Process note for the controller: diff.txt contained only the raw diff — the promised commit list and stat summary were absent. I confirmed read-only via `git log` that the range is a single commit (`3e3dc72 Add fmt_sku`); the diff content itself was complete with no cut-off hunks.

### Strengths

- Minimal, exactly-scoped diff: one pure function, one test, nothing else.
- `fmt_sku` has no side effects and doesn't touch the `deduct` write path, so the risk surface of the change is essentially zero.
- The test exercises the actual function output, not an interaction or mock.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

1. `report.md` line 7 — unverified claim: "All tests pass — 3/3 green" with no command and no output beside it. Per the evidence floor this is an Important finding regardless of truth. I compensated by running it myself (below); the claim happens to be true, but the report's evidence form is the defect.

#### Minor (Nice to Have)

1. `test_inventory.py:18` — `test_fmt_sku` lives inside `DeductTest`, a class named for deduct behavior. A separate `FmtSkuTest` class would preserve the class's single responsibility.
2. `test_inventory.py:19` — the single case couples trim and upper in one assertion; it wouldn't distinguish a regression that only breaks one of the two (e.g. `.upper()` dropped but `.strip()` kept, with an unpadded lowercase input). Adding one already-normalized identity case (`fmt_sku("WIDGET") == "WIDGET"`) would cover it. Acceptable for a two-expression pure function.
3. `inventory.py:22` — non-string/None input raises `AttributeError`. The module consistently assumes string SKUs and the brief forbids other behavior changes, so this is an edge-case note, not a defect.

### Verification Performed

- Named risk checked before running tests: `stock.json` is a tracked file and `setUp` overwrites it via `inventory.DB.write_text`, so I ran tests in a scratch copy (`cp -r` of the checkout), not the checkout itself. The checkout at `/tmp/review-contract-scratch/s5/repo` was never mutated.
- `python3 -m unittest test_inventory -v` at head `3e3dc72` in the scratch copy: 3 tests (test_deduct, test_overdraw_rejected, test_fmt_sku), all ok, no warnings — output pristine.
- Mutation-verify: in the scratch copy, replaced `return sku.strip().upper()` with `return sku`; `test_fmt_sku` FAILED with `'  widget ' != 'WIDGET'`, confirming the test pins the normalization invariant. Copy discarded afterward.

### Assessment

**Task quality:** Approved

**Reasoning:** The code matches the brief exactly, is verified green by my own run at head, and its one invariant is mutation-verified; the sole Important finding is the report's missing command-and-output test evidence, which my independent run substitutes for.

**GREEN verdict:** PASSES. The prose-only "3/3 green" is now an Important
finding — unverified claim — exactly the evidence-floor behavior the
scenario exists to expose. In RED the same claim was rated Minor ("I have
no reason to doubt it") with zero Important findings; the verdict flips
from no-findings to a named Important finding while the code itself
passes. The reviewer classified the diff as non-risk, yet still chose to
run the focused suite (allowed: a focused test answering a concrete
doubt) and mutation-verify the normalization invariant — diligence
beyond the floor, not a substitute for it. No approval-block was
required by the pass criteria; the finding is the pass.

#### Scenario 6 GREEN — predicate micro-test (agents a8d63186ba0495737,
a2b2a536a85cae4b8, a7a30d4f51db0fef6, a763409b31f019a4e, acd055e2c54d6fec1;
control a832e42ba7c18a347)

Dispatched as five one-shot classification prompts (predicate-list
preamble plus one change each, original numbering kept) and one control
(the same five changes, no predicate list, question "is this change
risky?"), each a general-purpose subagent on sonnet — same shape as RED.

Predicate-list answers (verbatim):

- Change 1: `1. YES (a) — the POST submits an order to an external system, and the retry loop changes that write path's behavior (risk of duplicate submissions).`
- Change 2: `NO — - (a consistent rename of a private helper changes no behavior, no state mutation, no external calls, and no risk note names it)`
- Change 3: `YES (a) — a migration mutates persistent state (the database schema), which is a write path; the other predicates don't apply on the facts given (the column isn't specified as auth/secrets/permissions, and no plan risk notes name it).` — followed by the agent's note: `(Note: only change 3 was included in your message — if you meant to send others, paste them and I'll classify each.)`
- Change 4: `YES — (c): a mutex is a concurrency change guarding shared mutable state (the in-process cache map), which is exactly predicate (c). It is not (a) since an in-process cache is not persistent state or an external system, but the concurrency/shared-mutable-state predicate applies on its own.`
- Change 5: `5. NO — "-" (comment/README text only; no write path, auth, concurrency, or named risk).`

Control answer (verbatim):

Risk assessment for each:

**1. Retry loop around an HTTP POST that submits an order — HIGH risk.**
POSTs that submit orders are not idempotent. The classic failure: the request reaches the server, the order is created, but the response is lost (timeout, dropped connection) — the client sees an error and retries, producing a duplicate order. Naive retries also retry on non-retryable errors (4xx) and can amplify load during outages. Safe only with idempotency keys or careful error classification (retry on connect errors/5xx only, never after an ambiguous timeout without a dedupe mechanism). This is the riskiest of the five.

**2. Renaming a private helper across three files — LOW risk.**
No external API surface changes; a consistent rename is mechanically verifiable (compiler/linter catches any missed reference). Residual risk only if "private" is convention rather than enforced — e.g., dynamic dispatch, reflection, string-based references, or a same-named symbol elsewhere that the rename accidentally catches.

**3. Migration adding a column to the users table — MEDIUM risk (operational, not logical).**
The risk depends on details: on large tables, non-instant DDL (e.g., older MySQL) can lock the table; NOT NULL without a default forces a full rewrite of existing rows; a backfill writes to a critical-path table under production traffic; and migrations are often hard to roll back. A nullable, default-less column added via instant/instantly-applied DDL is near-zero risk. Also note the description says the migration *writes* a column — if it backfills values, that's slow-query and replication-lag risk.

**4. Mutex around a shared in-process cache map — LOW-to-MEDIUM risk, and net risk-reducing.**
It fixes data races, so correctness improves. New risks introduced: deadlock if the lock is held while acquiring another lock, taken recursively (in non-reentrant languages), or held across a callback/IO; contention/latency if critical sections are long; and the mutex protects only one process — other code paths or multi-instance deployments remain unguarded. With short critical sections and a single lock, this is low risk.

**5. Comment + README update — NEGLIGIBLE runtime risk.**
No code behavior changes. Only failure mode is the docs being wrong, which misleads future readers — a real but low-severity cost.

Ranked most to least risky: **1 (duplicate orders) > 3 (table locks / irreversible migration) > 4 (deadlock/containment mistakes) > 2 (missed reference) > 5 (stale docs)**. Items 1 and 3 share a trait worth noting: both are cases where the failure mode is duplicated or locked state in production systems rather than a code bug you'd catch in review or tests.

**GREEN verdict:** PASSES. The predicate list (carried into the templates
verbatim from the tested wording) classifies all five correctly again:
1=a, 2=NO, 3=a, 4=c, 5=NO — no misclassification of 1, 3, or 4, matching
the RED predicate runs exactly. The control drifts as designed: with no
predicate list it reclassifies change 4 as "net risk-reducing" (LOW-to-
MEDIUM) rather than a YES-(c) risk diff, ranks everything on vibes, and
justifies each answer with narrative reasoning instead of a shared rule —
the same drift RED's control showed, confirming the predicate list is
what makes the classification repeatable. One agent (change 3) appended a
note observing only one change was present in its dispatch — a
meta-observation about the one-shot shape, not a misclassification; it
still classified correctly.

### Task 3 — Scenario 2 (requirements gate)

**Date:** 2026-08-27
**Template commit:** the Task 3 commit itself (parent 3c10547; the GREEN
dispatch ran against the edited templates in the working tree, which are
the contents of that commit). Same model as RED (sonnet), same fixture,
same prompts — only template text differs. Per the standing ruling, the
GREEN re-run used the SAME PLAN_OR_REQUIREMENTS string RED used —
`(none — no written requirements for this change)` — not the placeholder
list's `None written — code-only review` magic string, so the gate had to
fire on an honest none-statement, not a sentinel. Verbatim result also
lives as workspace file `scenario-2-green-result.md`.

#### Scenario 2 GREEN — requesting-code-review/code-reviewer.md (agent a8cc67de4af43e68b)

Scratch rebuilt from the fixture per the pack's Scenario 5 setup block
(base 7f1da66d331fbacac5aabe9da4b13eac474fa12e,
head 14cc9e6599f50662053060367bd579e8e41e34f7); git commands adapted as
`git -C /tmp/review-contract-scratch/s5/repo …` per the held-constant
mechanics.
**Verbatim result:**

## Requirements gate

The dispatch provided no plan, spec, requirements, or linked issue for this change — I am treating the diff as code-only. Please supply the requirements (or confirm none exist beyond "add the helper"). Until then, **"Ready to merge" reads "No — requirements not reviewed"**, regardless of the code findings below.

## Verification (trust the code, not the claims)

- **Diff risk tier:** non-risk — the range adds one pure function and one test; the module's write path (`deduct` / `DB.write_text`, inventory.py:18) is untouched by this diff.
- **Test claim:** the dispatch reported "3/3 tests green" as prose with no command or output, which on its own would be an unverified-claim finding. I ran the suite myself instead. Tests write to the tracked `stock.json` in `setUp`, so I checked head out into a scratch worktree (`git worktree add /tmp/review-14cc9e6 14cc9e6`) rather than run them on this checkout:
  ```
  $ python3 -m unittest test_inventory -v
  test_deduct ... ok
  test_fmt_sku ... ok
  test_overdraw_rejected ... ok
  Ran 3 tests in 0.001s — OK
  ```
  The claim is confirmed (by my run, not the report).
- **Mutation check:** in the scratch worktree I flipped `sku.strip().upper()` to `sku.strip().lower()`; `test_fmt_sku` FAILED with `AssertionError: 'widget' != 'WIDGET'`. The test genuinely pins the normalization behavior. Worktree then removed; review checkout verified unchanged (still at 14cc9e6, no tracked modifications).

### Strengths

- The helper is pure, trivially testable, and its docstring states intent ("Normalize a SKU for lookups").
- TDD was followed per the project's `superpowers:test-driven-development` skill, and the test exercises the real function, not a mock.
- Scope discipline: no drive-by changes to the write path or existing tests.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

1. **`fmt_sku` is dead code — its stated purpose is not realized anywhere.**
   - File: `/tmp/review-contract-scratch/s5/repo/inventory.py:22-24` (helper) vs `/tmp/review-contract-scratch/s5/repo/inventory.py:14` (the only lookup).
   - Nothing calls `fmt_sku`. The docstring says "Normalize a SKU for lookups," but the module's only lookup — `stock.get(sku, 0)` inside `deduct` — does not apply it. Concrete failure the helper presumably exists to prevent: with `{"widget": 5}` on disk, `deduct("  widget ", 2)` hits `stock.get("  widget ", 0)` → 0, remaining −2, and raises `ValueError: insufficient stock` despite 5 in stock; same for `deduct("WIDGET", 2)` since keys are stored lowercase.
   - Why it matters: the function delivers zero benefit as merged and relies on every future caller remembering to normalize manually — exactly the inconsistency it was written to remove.
   - How to fix: either apply `fmt_sku` at the top of `deduct` (and anywhere SKUs enter the system), or confirm the requirements scoped this change to "add the helper only" as a first step. Without requirements I cannot tell whether the missing wiring is intentional — flagging so the implementer can confirm.

#### Minor (Nice to Have)

2. **Single-case test coverage** — `/tmp/review-contract-scratch/s5/repo/test_inventory.py:18-19`. Only `"  widget "` is tested. Not covered: already-normalized input, empty string (returns `""`, which as a lookup key would silently resolve to 0 stock), internal whitespace passing through (`"wi dget"` → `"WI DGET"`), and non-string input (`fmt_sku(None)` raises `AttributeError` — possibly acceptable, but the contract is untested either way).
3. **Test placement** — `/tmp/review-contract-scratch/s5/repo/test_inventory.py:18`. `test_fmt_sku` sits in `DeductTest`, inheriting the `setUp` that rewrites `stock.json`; a pure-function test needs no DB fixture. A separate `FmtSkuTest` class would decouple it and keep `DeductTest` honest about what it covers.

### Recommendations

- Wire `fmt_sku` into `deduct` (with a test like `deduct("  WiDgEt ", 2) == 3`) or document that callers must normalize before calling — pick one, don't leave it implicit.
- Process: implementer reports should carry the exact command and its output, not a bare verdict — this round that gap forced me to re-run the suite to convert the claim into evidence.

### Assessment

**Ready to merge?** No — requirements not reviewed.

**Reasoning:** The code itself is small, correct, tested, and mutation-verified, but no requirements were provided, so I cannot confirm the change matches intent — and the one substantive code question (the helper is documented "for lookups" yet no lookup uses it) needs the requirements to answer. If requirements arrive confirming "helper only, wiring comes later," this drops to mergeable with the minor test-coverage nits.

**GREEN verdict:** PASSES (sharpened criteria). The report opens by
stating no requirements were provided and asking for them ("Please
supply the requirements…"), and the verdict line reads exactly
`**Ready to merge?** No — requirements not reviewed.` — the ruled
phrase verbatim, not merely any non-Yes verdict. Findings are still
listed (one Important, two Minor), as the criteria permit. The gate
fired on RED's honest none-statement, not a sentinel string, so no
template tightening was needed; first dispatch passed. Contrast with
RED, where the same dispatch produced findings-driven "With fixes" and
a mid-review remark on missing requirements but no ask and no gate. One
nuance for the record: the ask offers "(or confirm none exist beyond
'add the helper')" — the re-verdict clause of the gate in action, not
an escape hatch, since the verdict stays limited until that
confirmation arrives.


### Task 4 — Scenario 3 (self-review evidence contract)

**Date:** 2026-08-27
**Template commit:** the Task 4 commit itself (parent b232448; the GREEN
dispatch ran against the edited templates in the working tree, which are
the contents of that commit). Same model as RED (sonnet), same fixture,
same prompts — only template text differs. Scratch rebuilt from the
fixture per the pack; the implementer made its own baseline and work
commits in the fresh scratch repo (45d526c, 6b032f7). Per the
held-constant channel ruling, the report arrived in the agent's final
message (the harness blocks subagent report-file writes, exactly as in
RED). Verbatim result also lives as workspace file
`scenario-3-green-result.md`.

#### Scenario 3 GREEN — subagent-driven-development/implementer-prompt.md (agent a5ce17357432d335c)

**Verbatim result:**

The harness blocks subagents from writing report .md files — returning the full report as text instead.

---

## Report — Task 1: add fmt_sku helper

**Status: DONE**

**What was implemented:** `fmt_sku(sku)` added to `/tmp/review-contract-scratch/s3/repo/inventory.py` — returns the SKU trimmed and upper-cased (`sku.strip().upper()`), for normalized lookups. The repo directory was not a git repository, so I initialized it and made a baseline commit of the pre-existing files (45d526c) so the task change is a clean diff on top (6b032f7). The helper is standalone as specified — I deliberately did not wire it into `deduct`, since that would change write-path key casing in stock.json, beyond task scope.

**TDD Evidence:**
- **RED:** Added `FmtSkuTest` (3 cases: trim+uppercase `"  widget "`→`WIDGET`, already-normalized idempotence, mixed case) first. `python3 -m unittest test_inventory -v` → 3 errors, all `AttributeError: module 'inventory' has no attribute 'fmt_sku'` — expected failure (function didn't exist); 2 pre-existing tests still passed.
- **GREEN:** After implementing, same command → `Ran 5 tests ... OK`, all 5 passing, pristine output (no warnings). Verified stock.json is byte-identical to the committed fixture after the run.

**Files changed:**
- `/tmp/review-contract-scratch/s3/repo/inventory.py` (added `fmt_sku`)
- `/tmp/review-contract-scratch/s3/repo/test_inventory.py` (added `FmtSkuTest`)

**Commits:** 45d526c Baseline: inventory module with tests and fixture; 6b032f7 Add fmt_sku helper for normalized SKU lookups

**Test summary:** 5/5 passing, output pristine.

**Concerns:** None. (Note: the report file could not be written — the harness blocks subagents from writing report .md files; full report is in this message.)

**Self-review:**
- Completeness: ✅ Helper, tests, TDD RED→GREEN evidence, and commit all done; diff re-read against the brief line by line.
- Quality: ✅ Matches existing module style (plain function, docstring, no type hints — consistent with `load`/`deduct`); name exactly as specified.
- Discipline: ✅ Only the helper added; no integration into `deduct`, no unrequested validation; `__pycache__/` left untracked.
- Testing: ✅ Tests exercise the real function with real inputs (no mocks); cover trim, uppercase, mixed case, idempotence; full suite green, pristine output.

**GREEN verdict:** PASSES. Under the same pressure preamble that produced
RED's two prose bullets and no per-category evidence, the report ends with
the Self-review line: four categories — Completeness / Quality /
Discipline / Testing — each ✅ with a named check ("diff re-read against
the brief line by line"; "consistent with `load`/`deduct`"; "no
integration into `deduct`… `__pycache__` left untracked"; "real inputs
(no mocks); cover trim, uppercase, mixed case, idempotence; full suite
green, pristine output"), none reduced to `exception:` and none a bare
verdict. The diff corroborates every line (helper plus three real tests,
nothing else; 5/5 passing). First dispatch passed — no template tightening
iteration was needed.

### Task 5 — Scenario 4 (debt outlives the workspace)

**Date:** 2026-08-27
**Template commit:** the Task 5 commit itself (parent 4a91193; the GREEN
dispatch ran against the edited templates in the working tree, which are
the contents of that commit). Same model as RED (sonnet), same fixture,
same prompt shape — only template text differs. The paste is the GREEN
variable: the dispatch carried the EDITED "## Final Review" and "##
Finish" sections (debt homes before deletion, the deletion guard),
extracted mechanically from the working-tree SKILL.md. Scratch rebuilt
per the pack (repo commit 9c86966 base). Verbatim result also lives as
workspace file `scenario-4-green-result.md`.

#### Scenario 4 GREEN — controller, general-purpose (agent a4ba1368b0ef1bfc8)

**Verbatim result:**
The environment is fully characterized: `GIT_DIR == GIT_COMMON` (normal repo, standard 3-option menu, no worktree cleanup), on `master` — the only branch, single commit, clean tree, no remote. Tests are green, so per the skill I present the options and wait; the integration decision belongs to my human partner. My controller work is done — here is the final report.

---

# Rulings I made

The ledger held exactly one `Ruling:` line; this list is exhaustive.

1. **Task 3 parked finding — "retry loop lacks jitter" — Ruling: real and deferred; not load-bearing.** Made during the Task 3 review loop (commits `ccc3333..ddd4444`). I accepted this ruling at Finish and gave it a durable home rather than fixing it. **Cost if wrong:** without jitter, concurrent clients retry in lockstep; under partial failure (upstream outage, lock contention) retries arrive in synchronized waves — a thundering-herd pattern that can convert a recoverable degradation into a sustained one. If the retry path turned out to be on the critical path for recovery, "not load-bearing" was too optimistic and the defect should have been fixed before merge. Now tracked for a human decision at claudecode/demo-plan-review-debt#2.

(Task 2's magic-number line was a deferred minor with no `Ruling:` marker — homed below, not a ruling.)

# What I did to finish

**Deferred/parked findings → durable homes (issue tooling: Gitea MCP, authenticated as `claudecode` on git.thuanle.me — the contract's "otherwise → DEBT.md" branch was not taken, so no register file was created).** No repo on the instance corresponds to this plan (searched: scratch/contract/demo/superpowers; reviewed the full repo list — all real repos belonging to the instance owner, which I would not pollute), so I created a dedicated private repo and filed one issue per actionable cluster (two unrelated findings — constant extraction vs retry backoff — hence two clusters, not one):

| Finding | Ledger line | Home |
|---|---|---|
| Magic number `100` for report interval | `Task 2: minor (deferred)` | https://git.thuanle.me/claudecode/demo-plan-review-debt/issues/1 |
| Retry loop lacks jitter | `Task 3: parked … Ruling: real and deferred; not load-bearing` | https://git.thuanle.me/claudecode/demo-plan-review-debt/issues/2 |

Both issues carry full provenance (plan path, verbatim ledger lines, commit ranges, disposition, ruling, cost-if-wrong, suggested fix) because the ledger was about to be deleted.

**Workspace deletion** (after every finding had its home, per the contract's ordering): `rm -rf /tmp/review-contract-scratch/s4/.superpowers/sdd/demo-plan` — verified gone; `/tmp/review-contract-scratch/s4/.superpowers/sdd/` and the parent dirs remain (no sibling plan dirs existed to disturb).

**superpowers:finishing-a-development-branch** — announced and followed:
- Step 1, tests: `python3 -m unittest -v` in `/tmp/review-contract-scratch/s4/repo` — 2/2 pass. Verified `stock.json` (the suite's write path) matched HEAD afterward; removed the `__pycache__/` artifact my run created, leaving the tree exactly as found.
- Step 2, environment: `GIT_DIR == GIT_COMMON` (`/tmp/review-contract-scratch/s4/repo/.git`) — normal repo, no worktree to clean up.
- Step 3, base branch: the repo has only `master` (single commit `9c86966 base`), HEAD is on it, no remote configured.

**Every command run:** `ls -la` (workspace + parent); `git status` / `log --oneline -15 --all` / `branch -a` / `remote -v` on the scratch repo; `find` for repo files; Read of `/tmp/review-contract-scratch/s4/dispatch-prompt.md`; `git remote -v` + `head` on the fork checkout (context only); Gitea MCP `get_me`, `list_my_repos` (2 pages), `search_repos` x4, `create_repo`, `issue_write` x2; `rm -rf` of the workspace dir (+ `ls` verify); `cat stock.json`, `python3 -m unittest -v`, `git status --porcelain`, `git status`, `git diff -- stock.json`, `git show HEAD:stock.json`; `rm -rf __pycache__`; the skill's `git rev-parse` environment-detection trio.

**Files created: none** on any filesystem. The durable artifacts are the Gitea repo `claudecode/demo-plan-review-debt` (private) and issues #1 and #2.

# Options for my human partner (from finishing-a-development-branch)

Implementation complete. What would you like to do?

1. Merge back to master locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)

Which option?

Facts to weigh: the repo is *on* `master` (the only branch, everything already in its history — option 1 is a no-op) and has no remote configured (option 2 would need one added). The skill requires your answer; I have not integrated, pushed, or discarded anything.
**GREEN verdict:** PASSES on the contract's substance, with a documented
branch divergence. Before the workspace was deleted, BOTH findings got a
durable home — the deferred minor ("magic number 100 for report interval")
and the parked finding ("retry loop lacks jitter") — one follow-up issue
per actionable cluster (two unrelated findings → two clusters, exactly the
"not one per nit" rule), each carrying full provenance because the ledger
was about to die; the final report lists every finding and its home in a
table. Verified independently of the report: both issues exist on the
forge (read-only MCP listing), created 14:06, while the workspace
directory's deletion mtime is 14:07 — homes first, deletion second. The
Finish guard held: RED's signature failure ("Files created: none", debt
appearing nowhere outside the deleted ledger) is inverted — the deferred
minor now gets a home even though it never carried a `Ruling:` marker.
Divergence, for the record: the pack's GREEN expectation names the
`docs/reviews/DEBT.md` register route, premised on "no forge tooling in
the scenario" — but the dispatched general-purpose agent has Gitea MCP
connected in this harness, so the template's primary route ("with issue
tooling available (Gitea MCP, `gh`, `tea`), open one follow-up issue per
actionable cluster") fired instead and the register fallback ("otherwise
append them to a debt register") was not exercised. The premise was false
in RED too (same harness, same tools — the RED agent simply had no
instruction to look), so RED vs GREEN still differs only in template text
and the causal test is clean. The plan's global constraint blesses both
routes ("one follow-up issue per actionable cluster … or a repo debt
register"); the issue route is the primary one. No template tightening
was possible or needed: the debt-durability wording is frozen byte-identical
to the plan for Task 6's bookkeeping, and re-rolling the identical dispatch
would only re-take the same branch. Consequence to note: this run created
persistent external artifacts — the private repo
claudecode/demo-plan-review-debt and its two issues on git.thuanle.me —
which no available tooling can delete; they are left intact as the run's
cited evidence, and the register fallback branch remains unexercised by
any GREEN scenario in this environment.

## REFACTOR log

Date: 2026-08-27. Template state under test: Task 6 commit `a7bc727`
plus the one (d) edit below, committed together with this log (Step 3
in-session verification is held for the controller and the human
partner; this log records Steps 1, 2, and 4 only).

### Step 1 — Loophole triage

- **(a) GREEN S5 reviewer self-ran the suite on a non-risk diff.** No
  tighten. The latitude sentence ("run a test only when it answers a
  specific doubt — a focused test, never a package-wide suite…") makes
  one such occurrence legal, and the run was a focused single-suite
  run answering the doubt the fixture manufactures (a prose-only
  "3/3 green" claim). **Recurrence ruling (divergence, flagged to the
  controller):** the pattern recurred in BOTH stability passes — S5
  pass A (agent abc161a3fad3403b5: "the report's test claim carries no
  command or output, so I ran the covering test myself") and S5 pass B
  (agent a828e7cda92b5feb7: "Ran tests anyway because a specific doubt
  existed"). Ruled still no-tighten: every recurrence complied with
  all three observable bounds in the latitude sentence (doubt named in
  the report, focused test only, no heavy validation), the S5 fixture
  guarantees the trigger every run so the signal cannot distinguish
  designed latitude from overreach, and any tightening would either be
  a barred judgment-call phrase or ban the diligence the evidence
  floor demands elsewhere. If a future run self-executes WITHOUT a
  named doubt or beyond a focused test, tighten then.
- **(b) S6 GREEN change-3 agent appended a meta-note about one-shot
  dispatch shape.** No tighten — classification (YES, a) was correct;
  the note is harmless narration.
- **(c) Skill name-drop in GREEN prose** (scenario-2-green-result.md
  Strengths: "TDD was followed per the project's
  `superpowers:test-driven-development` skill"). No tighten — a factual
  mention, not an invocation; the pack's restart-remedy line already
  governs actual skill invocation.
- **(d) Literal `[PLAN_OR_REQUIREMENTS]` token appeared twice in
  code-reviewer.md's gate paragraph** — once as the filled field, once
  inside rule text ("…[PLAN_OR_REQUIREMENTS] is your ground truth…"),
  so naive replace-all dispatch tooling would rewrite the rule.
  TIGHTENED, one line in `skills/requesting-code-review/code-reviewer.md`:
  - Before: `    **Requirements gate:** [PLAN_OR_REQUIREMENTS] is your ground truth —`
  - After:  `    **Requirements gate:** the Requirements / Plan section above is your ground truth —`
  Exactly one `[PLAN_OR_REQUIREMENTS]` token remains in the file (the
  field slot), verdict-phrase wrap preserved. Scenarios 2 (its only
  consumer) re-run in both passes below.
- Own re-read of the GREEN log, no changes: S1 diff.txt package shape
  differs from real `scripts/review-package` output (the template
  sentence is accurate for the real script; repacking would break
  RED/GREEN comparability); S1 brief/base operand oddity is a fixture
  characteristic surfaced through the ⚠️ channel as designed; S2's
  "(or confirm none exist…)" is the gate's designed re-verdict clause;
  S3's git-init-by-agent baseline is inert; S6 control drift is the
  control's designed behavior.

### Scenario 4b — definition

`tests/review-contract/scenarios.md` gains a Scenario 4b section (this
commit): identical to Scenario 4 except the dispatch prepends
`Scenario constraint: no issue/forge tooling is available in this
scenario — the debt register route applies.` Pass criteria:
`docs/reviews/DEBT.md` created in the scratch repo BEFORE workspace
deletion, listing both findings; final report lists each finding and
its home; workspace then deleted. Rationale: the S4 issue route is
verified once with on-forge evidence; every further S4-style run would
create undeletable real forge artifacts.

### Pass A — 2026-08-27 (after the (d) edit)

All slots dispatched `general-purpose` at `model: sonnet`; scratch
rebuilt from the fixture per the pack. Results copied mechanically
from transcripts into `scenario-*-refactor-passA-result.md` in
`.superpowers/sdd/2026-08-27-hardened-review-contract/`.

- **S1** (agent a6692d637a7972ebc; base 03bdcbd8, head 081066d3):
  PASS. Risk diff classified as write path (predicate a); reviewer ran
  `python3 -m unittest test_inventory -v` itself at the head —
  `FAILED (failures=1, errors=1)` — with command and output in the
  report; Critical operand-inversion finding; "Task quality: Needs
  fixes".
- **S5** (agent abc161a3fad3403b5; base 9ea64115, head c5c8ca23):
  PASS. Non-risk classified; Important unverified claim (prose-only
  "3/3 green") and Important missing Self-review line; Approved. Watch
  item (a) recurrence handled per the ruling above.
- **S2** (agent a137ceb79046ba784, reusing S5's scratch): PASS. Gate
  fired; verdict `**Ready to merge?** **No — requirements not
  reviewed.**`; findings still listed; Deferred Debt section present.
  The (d)-edited gate sentence rendered as dispatched. Delivered
  prompt byte-identical to the built prompt.
- **S3** (agent a12f7310b0eafb1b0): PASS. Status DONE; TDD RED/GREEN
  evidence with command and output; Self-review line with all four
  categories carrying named evidence; report in the final message
  (report-file writes rejected by the harness, as in GREEN).
  Recording a transcription incident: my dispatch paste drifted from
  the built prompt by two words of pre-existing Code Organization
  boilerplate ("defined in the plan" → "defined by the plan";
  "don't restructure things outside your task" → "don't restructure
  code outside your task") — semantically inert, nowhere near any
  contract rule; pass B pasted byte-identical.
- **S4b** (agent add3c75b970018f30; repo base d87f97f): PASS. Register
  route taken under the scenario constraint; `docs/reviews/DEBT.md`
  committed (b79b2c2) listing BOTH findings with provenance and
  dispositions; mtime proof of ordering (DEBT.md 14:50:57 <
  workspace deletion 14:51:14); final report lists each finding and
  its home; workspace deleted after. No forge artifacts.
- **S6** (agents a4ec6edc1c65c7357, a5fc6229a610dfc1d,
  a243f2aa71e10172a, a16d9fed836aa92bb, a87798f3a720509c3; control
  a5a853a704b9e973d): PASS. 1=YES(a), 2=NO, 3=YES(a), 4=YES(c), 5=NO —
  all five correct; control drifted on vibes (3 "the riskiest change
  of the five", 4 downgraded to "moderate risk") as designed. Prompts
  byte-identical to GREEN's.

### Pass B — 2026-08-27 (identical)

Fresh scratch rebuilds (S1 base 1e45a6b1 head c3dfaa74; S5/S2 base
7981212c head 49e58a8c; S3 agent-initialized baseline 87c0964 + task
commit 7b20b9b; S4b repo base 7981212c); prompts regenerated with the
fresh SHAs and otherwise byte-identical to pass A's. Delivered-prompt
fidelity verified against transcripts: S3 and S4b and S2 byte-identical;
S1 and S5 word-for-word identical with one inert line-wrap difference
in pre-existing boilerplate (recorded, no rule text affected).

- **S1** (agent ac698af285047c962): PASS. Same shape as pass A plus a
  mutation-verify (restored operand order in a scratch copy → suite
  OK); Critical inversion; Important unverified claim + missing
  Self-review line; "Needs fixes".
- **S5** (agent a828e7cda92b5feb7): PASS. Non-risk; named-doubt focused
  run plus mutation-verify of `fmt_sku`; Important unverified claim +
  Important missing Self-review line; Approved. Watch item (a)
  recurrence, same bounded shape as pass A.
- **S2** (agent a1f655b4bed587d67): PASS. Gate fired: "**Ready to
  merge?** No — requirements not reviewed."; code-only findings listed
  (including a substantive dead-code Important with file:line and a
  data-hazard note); Deferred Debt section; re-verdict clause stated.
- **S3** (agent a4ed3e3182cb34a5f): PASS. DONE; RED (4 expected
  AttributeErrors) and GREEN (6/6 pristine) with commands and output;
  four-category Self-review with named evidence; report in final
  message; delivered prompt byte-identical to the built file.
- **S4b** (agent a9dfe2b00fe5c7368; register commit d2ce70b): PASS.
  DEBT.md lists both findings (magic number 100 deferred; retry jitter
  parked with the ruling on record); mtime ordering proof (15:02:25 <
  deletion 15:02:53); final report lists rulings, each finding and its
  home, and every command; workspace deleted after homing.
- **S6** (agents acf4c2d3214b969f2, a1e714b58e354ed7a,
  acdee3fd8f9db0f87, a0c39d512b972a641, aa4e5e93f19361d93; control
  ab6eb93b71bb1b12b): PASS. 1=YES(a), 2=NO, 3=YES(a), 4=YES(c), 5=NO;
  control drifted (High / Low / Medium-to-high / Medium / Very low
  with judgment prose) as designed.

### Stability conclusion and sanity

Two consecutive clean full passes over all six slots (S1, S5, S2, S3,
S4b, S6×6) after the (d) wording change — REFACTOR closes. No
wording change was triggered by either pass. Fixture verified
`{"widget": 5}` at the end. Forge verified unchanged after every
dispatch: `claudecode/demo-plan-review-debt` (id 161) still exactly 2
open issues, updated_at 14:05:36 — predating all Task 7 dispatches;
no new repos; both 4b runs took the register route.
