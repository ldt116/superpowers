---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks with an independent review after each, run a final whole-plan review, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that Superpowers works much better with access to subagents (Claude Code, Codex CLI, Codex App, Copilot CLI, and Gemini CLI all qualify; see the per-platform tool refs in `../using-superpowers/references/`). If subagents are available, use superpowers:subagent-driven-development instead of this skill.

## The Process

### Step 1: Load and Review Plan
1. Ensure an isolated workspace: use superpowers:using-git-worktrees to create one or verify the existing one
2. Read the plan — if it lives on a tracker issue, fetch it first (issue body or its comment)
3. Review critically - identify any questions or concerns about the plan
4. If concerns: Raise them with your human partner before starting
5. If no concerns: Create todos for the plan items and proceed

### Step 2: Execute Tasks

For each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Mark as completed
5. Run the independent task review below - **before** starting the next task

#### Independent Task Review (every task)

You just implemented this task, which makes you the worst reviewer of it. Get independent eyes on it:

1. Build the review package: the task's section from the plan, what it was supposed to produce, and its commit range (`git diff BASE_SHA..HEAD_SHA` for just this task)
2. Dispatch a fresh reviewer subagent using the prompt template at `../requesting-code-review/code-reviewer.md`
3. Verify each finding is real before acting on it - **REQUIRED SUB-SKILL:** Use superpowers:receiving-code-review. Reproduce the problem; don't perform agreement
4. Critical findings: fix, commit, and have the reviewer re-check the fix
5. Non-critical findings: record them for the final review

The reviewer template re-runs risk diffs (write paths,
auth/secrets/permissions, concurrency, plan-named risks) at the head —
your earlier runs do not transfer. For everything else, carry the task's
verification command and output into the dispatch; prose verdicts come
back as findings.

**No subagent access?** Fall back to a fresh-eyes self-review: re-read this task's diff line by line against the task spec - implementation matches the spec, the verification commands actually ran and passed, nothing extra slipped in. Reading is not verifying: re-run the verification commands. For non-risk diffs, the evidence floor is the command and its output in your task record — write it down as you run it, not from memory.

### Step 3: Final Whole-Plan Review

After all tasks complete:
1. Dispatch one independent review of the whole branch diff against the full plan (same reviewer prompt template)
2. Fix critical findings; re-run the affected tasks' verifications
3. Report non-critical findings to your human partner with your disposition of each

### Step 4: Complete Development

After the final review is clean:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly
- Task review surfaces a finding that invalidates the plan's approach

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Independent review after every task - completed is not verified
- Final whole-plan review before finishing
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent
