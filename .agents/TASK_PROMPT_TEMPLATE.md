# Task Prompt Template

**Use this structure for all future tasks:**

```markdown
# TASK [ID] — [Title]

## Current State
- **Branch:** `[Branch Name]`
- **Blockers:** `[None / List Blockers]`

## Objective
[Clear description of the goal]

## Constraints
- Must adhere strictly to `.agents/RULES.md`
- No changes outside scoped files
- Maintain memory limit (`< 200MB`)
- [Add any task-specific constraints]

## Required Actions
1. [Action 1]
2. [Action 2]
3. Update `MODEL_HANDOFF.md` & `AGENT_MEMORY.md`

## Output Format
1. Files changed
2. Validation summary 
3. Commit hash
4. PR Link
5. `WAITING FOR REVIEW APPROVAL`
```
