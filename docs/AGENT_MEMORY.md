# Agent Memory Context

## Critical constraints

- This project must remain completely independent of legacy code.
- Dependencies should not rely on heavy native code that has paid processing walls.
- Error handling must gracefully scale to low-end devices without crashing the main thread.
