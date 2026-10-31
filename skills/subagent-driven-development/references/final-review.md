# Final Review and Finish

Part of superpowers:subagent-driven-development. Every task in the plan is
complete.

The final whole-branch review gets a package too: run
`bash scripts/review-package PLAN_FILE MERGE_BASE HEAD` (MERGE_BASE = the commit the
branch started from, e.g. `git merge-base main HEAD`) and include the
printed path in the final review dispatch, so the final reviewer reads
one file instead of re-deriving the branch diff with git commands. Dispatch
on the most capable available model (see SKILL.md's Model Selection), using
superpowers:requesting-code-review's
[code-reviewer.md](../../requesting-code-review/code-reviewer.md). Point it at
the ledger's deferred-minor and parked lines so it can triage which must be
fixed before merge.

After triage, before anything is deleted, every deferred or parked finding
that survives gets a durable home: with issue tooling available (Gitea
MCP, `gh`, `tea`), open one follow-up issue per actionable cluster — not
one per nit; otherwise append them to a debt register in the repo
(`docs/reviews/DEBT.md` unless the project has its own convention). The
final report lists every deferred finding and where it now lives.

Tracker-bound bodies — an issue comment, a PR body —
are files too: compose once in the workspace, then post by path (a CLI
`--body-file`, shell substitution, or a subagent that reads the file,
posts, and returns the URL). In a real session, a controller composing a
full issue comment and PR body inline through a string-only tracker tool
paid a full copy of each, resident for the rest of the run.

If the final whole-branch review returns findings, dispatch ONE fix subagent
with the complete findings list — not one fixer per finding.
Per-finding fixers each rebuild context and re-run suites; a real
session's final-review fix wave cost more than all its tasks combined.
Then run exactly one scoped re-review of the fix wave
(`bash scripts/review-package PLAN_FILE FIX_BASE HEAD` over the fix range,
[re-review-prompt.md](../re-review-prompt.md)).
Adjudicate any residual findings as in the fix loop's breaker
(references/fix-loop.md): park with rulings, or rule on the load-bearing
ones and ledger what you decided. Only the four things that stop a running
plan (top of SKILL.md) stop you here. There is no second fix wave —
residual load-bearing findings surface to your human partner when
finishing-a-development-branch presents the options.

### Finish

Before you delete anything, collect every ledger line containing `Ruling:` —
preflight rulings, parked findings, breaker adjudications, all of them — into
your final message under "Rulings I made", in the order you made them, each
with what it costs if wrong. The list is exhaustive: if the ledger holds a
ruling, the list holds it. That list is the only place the decisions you
took on your human partner's behalf reach them — they read it and rework
whatever you got wrong. A ruling that dies with the workspace was a decision
made in secret.

When the final whole-branch review is clean, its fixes are merged, and
every deferred or parked finding has its recorded home (issue opened or
register entry appended — listed in your final report), delete this plan's
workspace (`rm -rf <workspace>`) — the git history and the debt record are
the record now. A deferred
finding with no home is not deferred, it is
discarded; deleting the workspace while any lacks one is forbidden.
Sibling directories belong to other plans; leave them alone.

Use superpowers:finishing-a-development-branch.
