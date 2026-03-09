# Standard Task Workflow

## 1. Pre-flight Check

Review `MODEL_HANDOFF.md` and `AGENT_MEMORY.md`. Confirm current branch aligns with task requirements. Create new branch from `main` (e.g., `feature/s002-import-layer`).

## 2. Implement

Execute code changes strictly within task scope. Prioritize modularity and clean architecture.

## 3. Validate

Run the following commands locally and confirm success before opening PR:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

## 4. Document Update

Update `MODEL_HANDOFF.md` & `AGENT_MEMORY.md` to reflect completed items and prepare next step state.

## 5. Open PR

Commit with conventional format. Push to remote. Open Draft PR via GH CLI.

## 6. Wait for Approval

Output the required PR format and suspend execution pending user approval.
