---
name: status-handoff
description: Use when opening a PR that a reviewer in another session or machine will review, or when asked to review someone else's PR — runs the dev↔review loop through status refs on the shared git remote, all the way to merged or closed
---

# Status Handoff

## Overview

**Core principle:** The shared git remote is a status board. Work status lives in refs — each side pushes its own transitions, and exactly one status ref per task is alive at a time. Detect changes with a silent `git ls-remote` monitor — token-free, identical on every forge. Read details through the forge's tracker tooling (API, CLI, MCP) exactly once, after an event fires. A silent monitor costs nothing; every line it prints costs a wake-up.

**Announce at start:** "I'm using the status-handoff skill to coordinate this work."

**When NOT to use:** both sides are in the same harness — dispatch a subagent instead. This skill is for the case where the only shared channel is the git remote.

## The Status Contract

One live status ref per task. `<key>` is the **work branch name** — the one identifier both sides see in the same form: the dev names it when pushing, the PR carries it, the reviewer reads it from the PR. Never use the issue number or the PR number as the key: the same work can be issue 85 to the dev and PR 98 to the reviewer, and two different keys put the two sides on two boards that never meet. A transition **pushes the new ref first, then deletes the old one, in the same turn** — so the transition owner cleans up their own predecessor, and a snapshot mid-transition still shows the new state.

| Ref (`refs/heads/status/<key>-…`) | Points at | Meaning | Pushed by |
|---|---|---|---|
| `status/<key>-dev` | head so far | task started, work in progress | dev |
| `status/<key>-ready-review` | head SHA to review | PR open / fix pushed — review this SHA | dev |
| `status/<key>-changes` | reviewed head SHA | changes requested (details in the PR) | reviewer |
| `status/<key>-merged` | merge commit | merged | reviewer |
| `status/<key>-closed` | head SHA | closed unmerged | reviewer |

The ref name carries the state; the SHA it points at carries the payload. The receiver deletes the final state (`-merged` / `-closed`) once consumed — that deletion is the dev's acknowledgment, and it leaves the board clean with nothing to sweep later.

Each side watches only the states the *other* side pushes — that way your own transitions never wake you:

- dev monitors: `status/<key>-changes`, `status/<key>-merged`, `status/<key>-closed`, plus the work branch (a branch vanishing without a verdict is a failure mode, not a state)
- reviewer monitors: `status/<key>-ready-review`

If the other side is a human, state the contract in the PR body — every transition is a single `git push`, easy to honor manually.

Why refs and not API polling inside the wait loop: `ls-remote` needs no API token (SSH credentials both machines already have) and no per-forge client code, and a named state ref says what happened outright — a vanished branch is ambiguous between merged, rejected, and housekeeping. The API's job is one confirmation call after the event.

## Dev Side: start → ready → react → done

1. **Start:** push `git push origin HEAD:refs/heads/status/<key>-dev` when work begins.
2. **Hand off:** push the branch, open the PR with the forge's tooling, state the contract in the PR body — naming the key (the branch) explicitly so the reviewer never has to guess it. Transition: push `status/<key>-ready-review` (pointing at the head to review), then delete `status/<key>-dev`. Arm the monitor (recipe below). Say you're waiting, then stop.
3. **React to each wake-up:**
   - `-changes` → read the review comments via tracker tooling, fix on the same branch, push, then transition back: push `-ready-review` (new head SHA) and delete `-changes`. That transition *is* your reply. The monitor stays armed.
   - `-merged` → confirm once via the tracker: `merged` is true and the merge commit matches (or descends from your head). Then delete `-merged`, finish per superpowers:finishing-a-development-branch, report done.
   - `-closed`, or branch gone with no verdict → verify via the tracker before concluding anything. Either way, surface it to your human partner.
   - Monitor expired with no event → re-arm and say so. If review stalls for hours, surface the stall — the merge decision is not yours to take.
4. Never merge your own PR.

## Review Side: watch → review → transition

1. Arm the monitor on `status/<key>-ready-review`. Derive the key by reading the work branch from the PR — never the PR number, never the issue number: the dev watches refs under the branch name, so any other key means watching a board nobody writes to. Wake when the ref appears or moves.
2. Review **the SHA the ref points at** — re-verify risk paths at that commit, not at a remembered head.
3. On a verdict:
   - **Changes requested** — post findings to the PR via tracker tooling, then transition: push `status/<key>-changes` (pointing at the reviewed head), delete `-ready-review`. Re-arm.
   - **Approve** — merge through the forge (so PR state stays truthful), then push `status/<key>-merged` pointing at the merge commit.
   - **Reject** — close through the forge, then push `status/<key>-closed`.
4. Never push to the dev's branch — your channels are PR reviews and status transitions.

## The Flow

```
 DEV (machine A)                    refs on origin                  REVIEWER (machine B)
 ───────────────                    ──────────────                  ────────────────────
 start task <key>
 │ push status/<key>-dev     ───►  status/<key>-dev
 implement, push branch,
 open PR
 │ push status/<key>-ready-        status/<key>-
 │   review, delete -dev    ───►  ready-review       ──────────►  wake: review this SHA
 │                                                               │ findings → post to PR
 │                               status/<key>-changes  ◄──────── │ push -changes, delete -ready
 │ ◄─────────────────────────────  (reviewed head SHA)           │ re-arm monitor
 wake: read comments via tracker
 fix, push branch
 │ push -ready-review        ───►  status/<key>-                  ──────────►  wake: re-review new head
 │   (new SHA), delete -changes      ready-review                      ⋮  (loop until clean)
 │                                                               │ approve → merge via forge
 │                               status/<key>-merged   ◄──────── │ push -merged (merge commit)
 wake: confirm via tracker once                                   │ done — stop monitor
 │ delete -merged            ───►  (board clean)
 cleanup branch/worktree, report done
```

## Monitor Recipe

One generic script per waiter; run it detached — a background process of **your own session** (background Bash or your harness's monitor). It prints the ref diff and exits on the first change — silence costs nothing.

The monitor is a shell loop, never a subagent. A subagent asked to "keep an eye on the refs" pays tokens on every check and drains its budget in hours — the loop above pays only for the lines it prints, and its exit is what wakes you. Arm or re-arm it in the same turn as the transition you're answering, before you stop — your next wake-up exists only if the loop is running when you go quiet.

```bash
#!/usr/bin/env bash
# wait-status.sh <ref-pattern>... — e.g. with key = work branch feat/475:
#   dev:      wait-status.sh refs/heads/status/feat/475-changes \
#                    refs/heads/status/feat/475-merged refs/heads/status/feat/475-closed \
#                    refs/heads/feat/475
#   reviewer: wait-status.sh refs/heads/status/feat/475-ready-review
prev=""
while true; do
  cur=$(git ls-remote origin "$@" 2>/dev/null | sort) || true
  if [ -n "$prev" ] && [ "$cur" != "$prev" ]; then
    diff <(printf '%s\n' "$prev") <(printf '%s\n' "$cur") | grep '^[<>]'
    exit 0
  fi
  prev="$cur"; sleep 60
done
```

Read the output as: `>` = ref appeared or moved (new state / new head), `<` = ref removed (old state cleaned up, or the branch vanished — verify before assuming merge). If your harness caps long runners, catch the expiry notification and re-arm — expiry is not an outcome.

## Quick Reference

| Moment | Dev side | Reviewer side |
|---|---|---|
| Task starts | push `-dev` | — |
| PR open / fix pushed | push `-ready-review`, delete predecessor | wake, review the ref's SHA |
| Findings | wake, fix, push, transition to `-ready-review` | push `-changes`, delete `-ready-review`, re-arm |
| Approved | wake, confirm via tracker, delete `-merged`, clean up | merge via forge, push `-merged` |
| Rejected | wake, verify, surface to human | close via forge, push `-closed` |
| No event for hours | surface the stall | surface the stall |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll just poll the PR API every minute" | API in the wait loop needs a token and per-forge code; `ls-remote` needs neither. The API's job is one confirmation call after the event. |
| "I'll dispatch a subagent to watch for the change" | A subagent watching refs pays tokens on every check and burns out its budget in hours; the detached shell loop pays only when something changes. Watching is the shell's job — waking and acting is yours. |
| "The merge state is already the signal" | A vanished branch is ambiguous — merged, rejected, or housekeeping. A named state ref says what happened and carries the payload SHA. |
| "I'll check every 30 seconds to react faster" | Shrinking the interval changes nothing you're woken by — only the lines the monitor prints cost tokens. React to changes, don't chase latency. |
| "The fix is pushed, I'll ping the reviewer too" | The `-ready-review` transition *is* the reply. A second signal for the same event trains both sides to ignore signals. |
| "I'll delete the old status ref later" | Later never comes. The transition is push-new then delete-old, same turn — that's what keeps one live ref per task. |
| "The PR number is right there — I'll use it as the key" | The dev watches refs under the branch name; the PR number is the forge's channel id, not the key. Read the branch from the PR and watch what the dev actually pushes. |
| "Branch gone, no ref — it must have merged" | Verify through the tracker before reporting done. Silent rejection is exactly what the contract exists to catch. |
| "Review has been quiet for hours — I'll merge it myself" | Merging your own PR is your human partner's call. Surface the stall and wait. |
| "I'll just fix the typo on the dev's branch while reviewing" | Never push to the dev's branch. Your channels are PR reviews and status transitions. |
