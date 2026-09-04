# Superpowers — ldt116 Fork

Fork of obra/superpowers, fine-tuned to change how coding-agent harnesses behave. Install from this repository, not the official marketplaces (see README).

## Tuned Divergences from Upstream

Every intentional difference from upstream is listed here. When merging upstream updates, preserve these.

1. **Subagent-driven development is the default.** After saving a plan, `writing-plans` proceeds directly into `superpowers:subagent-driven-development` — it never offers an execution choice. `superpowers:executing-plans` is the fallback for harnesses without subagent access only.
2. **Independent review during inline plan execution.** `executing-plans` runs an independent review after every task — a dispatched reviewer subagent, or a fresh-eyes self-review when subagents are unavailable — plus one final whole-plan review before finishing.
3. **Fork packaging identity.** The marketplace is `superpowers-ldt116` (both manifests; asserted by `tests/codex/test-marketplace-manifest.sh`). Marketplace `owner` is ldt116 and `.claude-plugin/plugin.json` `repository` points at the fork; `author` credits stay with upstream (Jesse Vincent).
4. **Hardened review contract.** Review seats trust code over claims: risk diffs (write paths, auth/secrets/permissions, concurrency, plan-named risks) are re-verified by the reviewer at the review head; other diffs need command-and-output evidence, and prose verdicts are findings. Reviews never approve without requirements ("No — requirements not reviewed"). Implementer reports end with an evidence-based Self-review line, audited by the task reviewer. Deferred debt outlives the workspace (follow-up issue or in-repo debt register). Mutation-verify and cross-family reviewers where runnable.
5. **Gate artifacts live on the issue tracker; internal artifacts are never tracked.** Plans (`writing-plans`) and specs (`brainstorming`) — the documents a human reviews and approves — are created as tracker issues (GitHub, Gitea, …) when the repo has one; the `docs/superpowers/` file paths are the no-tracker fallback, and specs are no longer auto-committed to git. Workspace-internal artifacts (task briefs, implementer reports, review packages, ledgers) exist only to be run — nobody reads them after — so they stay in git-ignored scratch and are never posted. When a plan runs from an issue, `subagent-driven-development` materializes the body into git-ignored scratch (`.superpowers/plans/`), and on a clean final review posts the final summary to the issue and closes it before deleting the workspace.

When this list changes, update the fork section of README.md to match. The README lists behavioral divergences only — packaging identity (#3) stays out of it; the manifests and the test carry it.

## Working in This Fork

- This is a personal fork; all changes are fork-specific tuning.
- Modify skill content through the `superpowers:writing-skills` skill, preserving the existing voice and structure of the skills.
- Verify skill changes by reinstalling the plugin from this fork and checking behavior in a real session.
