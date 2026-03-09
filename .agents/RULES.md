# LumaCraft Agent Rules

## Mandatory Pre-Task Reading

Before beginning any new task, agents MUST read the following files in order:

1. `docs/MODEL_HANDOFF.md`
2. `docs/AGENT_MEMORY.md`
3. `docs/RELEASE_TASK_BOARD_V2.md`

## Absolute Directives

1. **No Merge Without Approval:** Do not merge PRs without the explicit "APPROVED TO MERGE" trigger from the user.
2. **Strict Scoping:** No code changes outside the explicitly scoped task domain.
3. **State Maintenance:** Always update `MODEL_HANDOFF.md` and `AGENT_MEMORY.md` at the end of a task with progress and next steps.
4. **Token Efficiency:** Prefer minimal token usage and diff-focused or tightly scoped responses over full-file rewrites unless necessary.
