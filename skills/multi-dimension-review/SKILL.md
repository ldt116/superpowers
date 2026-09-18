---
name: multi-dimension-review
description: Use when the user asks for a thorough multi-angle review of a diff, a branch, or a commit range — on demand, independent of any development plan
---

# Multi-Dimension Review

Dispatch six dimension reviewers plus one merge/verify seat over a
git-level target. Report-only: findings come back, fixes never do.

**Core principle:** every dimension gets a clean-context reviewer; the
main chat gets conclusions, files get payloads.

## When to Use

- The user asks for a thorough review of a diff, branch, or commit range
  ("review this branch", "look hard at this diff")
- A one-off review outside any plan — SDD's per-task seat covers in-plan
  reviews

Not for: per-task SDD reviews, quick sanity checks, fix requests —
findings are the deliverable, nothing gets fixed here.

## Flow

### 1. Resolve the target

Accept a working diff, `BASE..HEAD`, or branch-vs-base. If the diff is
empty, say so and stop.

Ask for the change's intent (what it is supposed to do). Optional — but
if absent, the requirements dimension returns "unverifiable — no
requirements provided", never a silent pass.

### 2. Build the package

All payloads go to files; nothing bulk-enters the chat:

```bash
LABEL=$(date +%Y%m%d-%H%M%S)-<short-target>
WS=/tmp/superpowers/<project-id>/reviews/$LABEL
mkdir -p "$WS"
git diff BASE..HEAD -U10        > "$WS/package.diff"
git diff BASE..HEAD --stat      > "$WS/package.stat"
git log  --oneline BASE..HEAD   > "$WS/package.log"
git diff --name-only BASE..HEAD > "$WS/package.files"
cp CLAUDE.md "$WS/root-CLAUDE.md" 2>/dev/null || true
# for each changed file's directory: copy its CLAUDE.md / AGENTS.md into
# "$WS/" as "<dir-slug>-CLAUDE.md" / "<dir-slug>-AGENTS.md" when present
```

`<project-id>` is the repo root's basename plus the first 6 hex chars of
the root path's md5 — the same scheme every other skill uses.

### 3. Dispatch six dimension reviewers — one message, six subagents

Fill [dimension-reviewer.md](dimension-reviewer.md) once per dimension:

| Dimension | Brief (goes in {DIMENSION_BRIEF}) |
|---|---|
| correctness | logic, boundaries, null handling, error paths, function contracts |
| security | injection, secrets, authz, trust boundaries |
| code-smells | smells with impact only — read the reference named in the template's extra reads first |
| performance | hot paths, N+1 queries, O(n²) on large inputs, alloc/IO inside loops |
| tests-regression | changed behavior vs test coverage; contracts the diff silently changes |
| requirements-conventions | caller intent (if given) plus CLAUDE.md/AGENTS.md adherence |

### 4. Dispatch the merge/verify seat

Fill [merge-verifier.md](merge-verifier.md) with `{WS}` and the intent
(or `none provided`).

### 5. Post the digest

Relay the merge seat's ≤15-line digest plus the `report.md` path. Done —
no fix dispatches.

## Hard Rules

- No `model:` field on any dispatch — subagents inherit the session's
  model
- Every subagent return is ≤15 lines; detail lives in files
- A finding without file:line plus evidence is self-rejected
- Dimension reviewers never spawn their own subagents — the controller
  dispatches every seat
- Linter/typechecker-catchable issues are out of scope — CI covers them

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll just review the diff inline — faster" | You are the coordinator; six clean-context seats see more than one polluted one, and the diff never enters your context. |
| "Six dispatches is overkill for this small diff" | The six are fixed by contract; independence is exactly what a single pass cannot buy. |
| "The merge seat can skip re-verifying; the dimension agent ran it" | Risk findings re-verify at the head — earlier runs do not transfer. |
| "No intent was given, so requirements must be fine" | No intent → "unverifiable — no requirements provided". Not a pass. |

## Artifacts

Everything lives under `/tmp/superpowers/<project-id>/reviews/<label>/`:
package files, six `findings-<dim>.md`, `report.md`. Machine-internal —
never committed, never posted.
