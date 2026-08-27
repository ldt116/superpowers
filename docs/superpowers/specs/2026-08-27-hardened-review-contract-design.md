# Hardened Review Contract Design

**Date:** 2026-08-27
**Author:** Bot & Thuan Le
**Status:** Design Complete, Awaiting Implementation

## Overview

Tighten every review seat in this fork around three commitments: reviewers trust
code and fresh evidence over implementer claims, no review approves against
unknown requirements, and deferred technical debt always outlives the workspace.
The changes live entirely in the existing prompt templates and the skills that
dispatch them — no new skills, no packaging changes.

## Background

An audit of the projects that consume this plugin (2026-08-27) compared their
review processes against the fork's skills:

- **gate-keeper** (`AGENTS.md` + `docs/ai/workflow/review.md`) enforces
  evidence-not-assertion self-review (S1–S8), fresh validation run by the
  reviewer at the PR head, a hard FAIL gate when a PR has no linked
  requirements, and follow-up issues for out-of-scope debt.
- **hcmut-util** (`CLAUDE.md` + `docs/reviews/`) mandates context-carrying PR
  review (read description, commits, linked issue, acceptance criteria — "no
  blind review"), and its real PR reviews (by a different agent account than
  the implementer) re-ran the test suite locally and mutation-verified
  load-bearing invariants.

The fork's gaps, against those practices:

1. **Reviewer trusts the implementer's report by design.** SDD says "Do not ask
   a reviewer to re-run tests the implementer already ran" and the reviewer
   templates forbid re-running the suite. `verification-before-completion`
   covers the implementer/controller side ("agent reports success → verify
   independently") but nothing covers the reviewer seat.
2. **No requirements gate.** The generic reviewer template takes
   `PLAN_OR_REQUIREMENTS` as optional input; a dispatch without requirements
   still yields "Ready to merge: Yes".
3. **Debt dies with the workspace.** Minor findings are parked in the SDD
   ledger, triaged by the final review, and then the workspace is deleted —
   "git history is the record" buries the debt.
4. **Self-review is unaudited.** The implementer self-review section asks
   questions but the report carries only "Self-review findings (if any)" — no
   evidence contract, nothing for the reviewer to check.
5. **No mutation-verify or cross-model guidance**, both proven in the audited
   projects.

## Design Principles

- **Rules live in the prompt templates.** Reviewer subagents see only their
  dispatch prompt; CLAUDE.md of a consuming project never reaches them. A rule
  that is not in the template does not exist for the reviewer.
- **Observable predicates over judgment calls.** Every conditional keys on
  something visible in the diff, the brief, or the report — never on "seems
  risky".
- **Preserve the existing voice and structure** of each skill (fork rule);
  duplicated rule text across templates follows the existing idiom (the
  read-only / no-subagents rules are already duplicated verbatim).

## 1. Tiered Verification (code over claims)

Replaces "Do not re-run the suite to confirm their report" in all three
reviewer surfaces: `code-reviewer.md`, `task-reviewer-prompt.md`,
`re-review-prompt.md`; controller-side rule updated in
`subagent-driven-development/SKILL.md` and `executing-plans/SKILL.md`, with a
one-paragraph tiered-contract summary in
`requesting-code-review/SKILL.md` (it is the dispatch skill for the generic
reviewer).

**Risk-diff predicates** (any one makes the diff a risk diff):

- (a) a write path — code that mutates persistent state or sends data to an
  external system;
- (b) authentication, secrets, or permissions;
- (c) concurrency or shared mutable state;
- (d) anything the plan/brief's risk notes name.

**Risk diff:** the reviewer MUST run verification at the review head — the
focused tests covering the changed code, or the verification commands the plan
names — and report the command and key output. If the reviewer cannot run it
(missing toolchain/dependencies), the report says so explicitly and the
verdict cannot be a clean approval; it becomes ⚠️ "verified by code-read
only", which the controller must resolve.

**Non-risk diff — evidence floor:** the implementer's report counts as
evidence only when it contains the exact command and its output. Prose
("tests pass", "14/14 green") without output is an Important finding:
unverified claim.

**Cost guardrails kept:** focused tests, never package-wide loops beyond the
mandate; the existing evidence-legibility rules (re-read the file before
declaring evidence missing) stay.

**Implementer side:** `implementer-prompt.md`'s "Reviewers will not re-run
tests for you" becomes: "Your report IS the test evidence for non-risk diffs —
command and output, or it counts as an unverified claim. Risk diffs get
independently re-run by the reviewer."

## 2. Requirements Gate (no blind review)

**Files:** `code-reviewer.md`, `requesting-code-review/SKILL.md`.

- The reviewer template gains a Requirements gate: if the dispatch provides no
  plan/spec/requirements, the reviewer asks for them in the report and the
  verdict is limited — findings are fine, but "Ready to merge" must read
  "No — requirements not reviewed". Never approve blind. With requirements in
  hand, re-verdict.
- `requesting-code-review` dispatch step makes `PLAN_OR_REQUIREMENTS`
  REQUIRED. If genuinely no written requirements exist, the dispatch says so,
  and the reviewer produces a code-only review with the limited verdict.
- SDD's task reviewer (reads the brief) and final review (reads the plan), and
  `executing-plans` (reviews against the plan) already carry requirements;
  unchanged.

## 3. Self-Review Evidence Contract (implementer side)

**Files:** `implementer-prompt.md`, `task-reviewer-prompt.md`.

- The implementer's report ends with a `Self-review:` line — each existing
  category (Completeness / Quality / Discipline / Testing) gets ✅ plus a
  one-line evidence note (what was checked and where), or an explicit
  exception with a reason. "I think it's fine" is not evidence.
- The task reviewer checks the line exists and is not contradicted by the
  diff. Missing or contradicted = Important finding.

Mechanism mirrors gate-keeper's S1–S8 but reuses the four categories already
in the template — no new rubric.

## 4. Debt Outlives the Workspace

**Files:** `subagent-driven-development/SKILL.md` (Final Review + Finish),
`finishing-a-development-branch/SKILL.md`, `code-reviewer.md`.

- Before the SDD workspace is deleted, every deferred-minor and parked finding
  gets a durable home: with issue tooling available (Gitea MCP, `gh`, `tea`),
  open one follow-up issue per actionable debt cluster (not per nit);
  otherwise append to a debt register in the repo — `docs/reviews/DEBT.md` or
  the project's existing convention. The final report lists every deferred
  finding and where it now lives. Deleting the workspace with unrecorded
  deferred findings is a violation (rationalization-table entry).
- The generic reviewer template's Code quality lens names code smells
  explicitly (duplication, dead code, needless complexity, swallowed errors),
  and its output gains a Deferred debt section: every Minor that is real debt
  gets a disposition recommendation (fix now / follow-up issue / register).
- `finishing-a-development-branch` surfaces the debt disposition (issues
  opened / register updated) in the completion summary before presenting the
  integration menu.

## 5. Mutation-Verify and Cross-Model Reviewer (conditional recommendations)

**Files:** `task-reviewer-prompt.md`, `code-reviewer.md`,
`subagent-driven-development/SKILL.md` (Model Selection).

- When the diff pins a load-bearing invariant (retry semantics, atomicity,
  access control) and the toolchain runs, the reviewer should mutation-verify:
  flip the invariant in a scratch worktree, run the covering test, confirm it
  FAILS, restore. The read-only rule holds — mutations happen only in a
  throwaway worktree or are reverted with evidence in the report.
- Model Selection: when the harness offers more than one model family, prefer
  a reviewer from a different family than the implementer for risk diffs and
  the final review. Preference, not mandate — single-family harnesses still
  work.

## Files Touched

| # | File | Change |
|---|------|--------|
| 1 | `skills/requesting-code-review/SKILL.md` | PLAN_OR_REQUIREMENTS required; evidence-floor summary |
| 2 | `skills/requesting-code-review/code-reviewer.md` | Requirements gate; tiered verification; smells + Deferred debt section; mutation-verify |
| 3 | `skills/subagent-driven-development/SKILL.md` | Replace don't-re-run rule with tiered rule; debt-outlives-workspace in Final Review/Finish; cross-model preference; rationalization entries |
| 4 | `skills/subagent-driven-development/task-reviewer-prompt.md` | Tiered verification; self-review line check; mutation-verify |
| 5 | `skills/subagent-driven-development/re-review-prompt.md` | Tiered verification for fix diffs |
| 6 | `skills/subagent-driven-development/implementer-prompt.md` | Self-review evidence contract; report-is-evidence wording |
| 7 | `skills/executing-plans/SKILL.md` | Tiered-rule summary in independent task review; evidence floor in fresh-eyes fallback |
| 8 | `skills/finishing-a-development-branch/SKILL.md` | Debt disposition in completion summary |
| 9 | `CLAUDE.md` | Divergence #4: Hardened review contract |
| 10 | `README.md` | Fork section updated to match |

No packaging, manifest, or hook changes.

## Testing Strategy (writing-skills Iron Law)

No skill is edited without a failing baseline first. RED-GREEN-REFACTOR:

**RED — baseline scenarios (run without the edits, document verbatim):**

1. *Unverified claim on a risk diff:* reviewer subagent receives a risk diff +
   implementer report claiming "tests pass" with no command/output. Baseline
   expectation to beat: approves.
2. *No requirements:* dispatch a review with empty PLAN_OR_REQUIREMENTS.
   Baseline: "Ready to merge: Yes".
3. *Self-review under pressure:* implementer subagent with time/sunk-cost
   pressure omits self-review evidence, self-grades "looks good".
4. *Debt discarded:* controller finishing a plan with parked minors deletes
   the workspace without recording them.
5. *Evidence floor:* reviewer accepts "14/14 green" prose with no output on a
   non-risk diff.

**Wording micro-tests** for the risk-predicate list and the verdict-limiting
language: 5+ reps per variant with a no-guidance control; every flagged match
read manually; converge on one interpretation.

**GREEN:** re-run each scenario with the edited templates; agents comply.

**REFACTOR:** new rationalizations discovered in GREEN get explicit counters
and rationalization-table entries; re-run until stable.

**In-session verification** (fork rule): reinstall the plugin from this fork
and exercise a real review seat before declaring done.

## Fork Bookkeeping

CLAUDE.md's divergence list gains entry **4. Hardened review contract**
(tiered verification, requirements gate, self-review evidence contract,
durable debt, mutation-verify/cross-model), and README.md's fork section is
updated to match — both required by the fork's own rules. Upstream merges must
preserve these like the other three divergences.

## Out of Scope

- No new skills (a canonical `reviewing-code` skill was considered and
  rejected: templates are the portable mechanism that reaches reviewer
  subagents on every harness).
- `receiving-code-review` and `verification-before-completion` are untouched —
  they already cover their sides (verify findings before implementing;
  evidence before claims for the actor).
- No Gitea-specific wiring in the skills: issue tooling is probed at runtime
  ("if available"), keeping every harness supported.
- No change to the fix-loop cap, breaker, or ledger mechanics — this design
  adds gates around the loop, not a new loop.
