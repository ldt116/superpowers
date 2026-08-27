# Superpowers — ldt116 Fork

Fork of obra/superpowers, fine-tuned to change how coding-agent harnesses behave. Install from this repository, not the official marketplaces (see README).

## Tuned Divergences from Upstream

Every intentional difference from upstream is listed here. When merging upstream updates, preserve these.

1. **Subagent-driven development is the default.** After saving a plan, `writing-plans` proceeds directly into `superpowers:subagent-driven-development` — it never offers an execution choice. `superpowers:executing-plans` is the fallback for harnesses without subagent access only.
2. **Independent review during inline plan execution.** `executing-plans` runs an independent review after every task — a dispatched reviewer subagent, or a fresh-eyes self-review when subagents are unavailable — plus one final whole-plan review before finishing.
3. **Fork packaging identity.** The marketplace is `superpowers-ldt116` (both manifests; asserted by `tests/codex/test-marketplace-manifest.sh`). Marketplace `owner` is ldt116 and `.claude-plugin/plugin.json` `repository` points at the fork; `author` credits stay with upstream (Jesse Vincent).

When this list changes, update the fork section of README.md to match.

## Working in This Fork

- This is a personal fork; all changes are fork-specific tuning.
- Modify skill content through the `superpowers:writing-skills` skill, preserving the existing voice and structure of the skills.
- Verify skill changes by reinstalling the plugin from this fork and checking behavior in a real session.
