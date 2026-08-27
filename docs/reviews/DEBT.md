# Debt Register

Durable record of deferred findings that outlive their development
workspaces — appended at the Finish step of subagent-driven development
(`skills/subagent-driven-development/SKILL.md`). One entry per actionable
cluster. Closed entries keep their record so the history shows why.

## Open

- **[2026-08-27] In-session plugin-reinstall verification outstanding**
  (hardened-review-contract, final-review Minor 2; branch
  `tune/hardened-review-contract`). The fork's own verification rule —
  reinstall the plugin from this fork and verify the cached template's
  behavior — was skipped for this change set by the human partner's
  decision. Template content is scenario-verified (RED / GREEN / two
  clean REFACTOR passes); the installed-plugin pathway is not. Recovery
  recipe: in-session verification appendix of
  `docs/superpowers/specs/2026-08-27-hardened-review-contract-baseline.md`.
  Run it at the next plugin update and amend the appendix; until then the
  fork's reinstall rule stays unsatisfied for this change set.
- **[2026-08-27] External scenario artifacts on git.thuanle.me**
  (Scenario 4 debt-route evidence). The scenario run created private repo
  `claudecode/demo-plan-review-debt` with issues #1 and #2; the baseline
  doc cites them as evidence and no delete tooling exists. Owner may
  delete them manually once the evidence is accepted; until then they
  stay as the cited record.

## Closed (record)

- **Untested `.claude-plugin` manifest identity** — final-review Minor 1;
  fixed in `28ab61d`: `tests/codex/test-marketplace-manifest.sh` now pins
  the `superpowers-ldt116` name and the fork `repository` URL;
  mutation-verified in both directions by the implementer, one direction
  re-verified by the scoped re-reviewer.
- **README divergence-2 wording drift** ("a final" → "one final
  whole-plan review") — fixed in `28ab61d`.
- **Baseline REFACTOR-log precision** (token-count statement, S1 command
  quote) — fixed in `d106f78`.
- **Scenario-pack minors** (vestigial Scenario 5 lead-in; Scenario 6
  one-shot shape note) — fixed in `3c10547`.
- All other per-task review Minors were classified polish, byte-exactness
  constraints, or plan-mandated idiom and ruled closed at review time —
  no debt survives them.
