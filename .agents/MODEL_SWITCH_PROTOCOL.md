# Model Switch Protocol

**Follow these steps when inheriting an incomplete session due to rate limits or context window exhaustion:**

1. **Read Order:**
   Immediately ingest `docs/MODEL_HANDOFF.md`, `docs/AGENT_MEMORY.md`, and `docs/RELEASE_TASK_BOARD_V2.md`.
2. **State Capture:**
   Verify the current working branch and last commit (`git log -1`).
3. **Task Capture:**
   Read any open PR state (`gh pr view`) to understand pending reviewers or failing checks.
4. **Blockers:**
   Identify if the previous model was blocked. Check if tests (e.g., `flutter test`) were failing.
5. **Resume:**
   Continue executing the latest uncompleted Task ID listed in `MODEL_HANDOFF.md`.
