# Agent Memory Context

## Critical constraints

- This project must remain completely independent of legacy code.
- Dependencies should not rely on heavy native code that has paid processing walls.
- Error handling must gracefully scale to low-end devices without crashing the main thread.

## Task Tracking

- **Completed:** S001 (Bootstrap) + S001B (Brand Rename) merged to main.
- **QA_PENDING:** S002/B/C/D/E/F (Core pipeline hardened) - All plugin channels replaced with native Kotlin MethodChannel. `path_provider` removed. Zero plugin deps for import/paths.

## Environment Identity

- **Local Path:** `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- **Remote Repo:** `https://github.com/krishnasharmabsr/lumacraft_mobile`
