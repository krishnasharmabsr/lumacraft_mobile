# Agent Memory Context

## Critical constraints

- This project must remain completely independent of legacy code.
- Dependencies should not rely on heavy native code that has paid processing walls.
- Error handling must gracefully scale to low-end devices without crashing the main thread.

## Task Tracking

- **Completed:** S001 + S001B + S002 + S003/A/B/H + S004 + S004A/B/C/D/E/F/G/H/I/K/L/M/N/O (Export Hotfix/UX/Stability/Duration/Seek).
- **Active:** S005 (Video AI Generation Foundation)

## Environment Identity

- **Local Path:** `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- **Remote Repo:** `https://github.com/krishnasharmabsr/lumacraft_mobile`

## S004Q Start

- **Date:** 2026-03-10
- **Branch:** `fix/s004p-seek-proxy-fix`
- **Memory:** Manual QA still reports failed scrub and +/-10 seeks on downloaded videos despite valid duration. Current task is to remove dual-timebase seek math, promote a normalized playback source, and harden verified seek execution without touching export/watermark.

## S004Q Update

- **Status:** Code fix implemented and build-validated.
- **Memory:** Editor playback now uses a single active playback source; imported/problematic files are normalized once for playback, and scrub plus +/-10 both route through the same verified seek path with retry and hard reinit fallback.
