# Agent Memory Context

## Critical constraints

- This project must remain completely independent of legacy code.
- Dependencies should not rely on heavy native code that has paid processing walls.
- Error handling must gracefully scale to low-end devices without crashing the main thread.

## Task Tracking

- **Completed:** S001 (Bootstrap) + S001B (Brand Rename) merged to main.
- **Next Task:** S002 (Core video pipeline: import -> preview -> trim -> export)
