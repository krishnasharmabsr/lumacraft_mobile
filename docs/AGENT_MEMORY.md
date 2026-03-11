# Agent Memory Context

## Critical constraints

- This project must remain completely independent of legacy code.
- Dependencies should not rely on heavy native code that has paid processing walls.
- Error handling must gracefully scale to low-end devices without crashing the main thread.

## Task Tracking

- **Completed:** S001 + S001B + S002 + S003/A/B/H + S004 + S004A/B/C/D/E/F/G/H/I/K/L/M/N/O + S005/A/B/C/D/E/G + S006/A/B + S007/A + S008 + S009/A/B + S010 + S011 (Export/UX/Stability/Landscape/Autohide/Speed).
- **Active:** S012 (AI Feature TBD)

## Environment Identity

- **Local Path:** `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- **Remote Repo:** `https://github.com/krishnasharmabsr/lumacraft_mobile`

## S004Q Start

- **Date:** 2026-03-10
- **Branch:** `fix/s004p-seek-proxy-fix`
- **Memory:** Manual QA still reports failed scrub and +/-10 seeks on downloaded videos despite valid duration. Current task is to remove dual-timebase seek math, promote a normalized playback source, and harden verified seek execution without touching export/watermark.

## S004Q Update

- **Status:** Code fix merged to `main` via PR `#9`.
- **Memory:** Editor playback now uses a single active playback source; imported/problematic files are normalized once for playback, and scrub plus +/-10 both route through the same verified seek path with retry and hard reinit fallback.
- **PR State:** PRs `#4` to `#8` were closed as superseded by the canonical cumulative merge in PR `#9`.

## S005 Watermark Fallbacks & S005G Merge

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Memory:** Completed cumulative reliability fix. Replaced fragile `ffmpeg` PNG decode step with a multi-attempt raw RGBA stream matrix fallback. Removed `ffmpeg` drawtext to guarantee asset rendering. Safely integrated production premium `watermark_lockup.png` cleanly on top without corrupting rules. Cleaned up multiple redundant experimental branches (S005E, S005F, S005). `main` is validated and strictly clean for subsequent phases.

## S005D Branding Consistency

- **Memory:** Unified all runtime logo references. Canonical path: `assets/branding/logo_mark_master_1024.png`. Home screen now uses Image.asset with canonical PNG. Removed stale `logo_mark.png`. See `docs/BRAND_REGISTRY.md` for full contract.

## S005E Brand Identity Polish

- **Memory:** Regenerated pristine vector-based PNGs without checkerboard artifacts. Regenerated adaptive Android icons using `flutter_launcher_icons`. Polished splash animation duration to 1.5s total. Branch: `feat/s005e-brand-identity-polish`.

## S005E2 Branding Lockdown Fix

- **Memory:** Enforced teal core branding color match. Hand-centered play motif via generation script. Stripped all `Icons.movie_edit` references to maintain single motif style. Added strict fallback rules to `BRAND_REGISTRY.md`.

## S006 Export Quality Presets UI Revert

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Memory:** Deprecated confusing 0-100 continuous quality slider. Brought in discrete bounded set of presets: Low (q:v 6), Standard (q:v 4 - Default), High (q:v 2). Updated UI widget `ExportSettingsSheet` to use premium discrete buttons matching the pro resolution locks style. Engine test assertions migrated successfully.

## S007 Content-Anchored Watermark

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Memory:** Refactored filter graph in `FFmpegProcessor` to correctly anchor the watermark to the actual scaled video content boundaries, rather than the padded canvas edges. Programmatic analysis confirmed the layout protects the watermark from rendering incorrectly on letterboxes or pillarboxes across all aspect ratio transformations.

## S008 Keep Screen Awake During Playback

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Memory:** Integrated `wakelock_plus` to automatically hold the screen awake while a video is playing in the `EditorScreen`. Wired the `WakelockPlus.enable/disable` methods directly into the `_controllerListener` driven by `_videoController.value.isPlaying` state. Ensured fallback cleanup on `dispose()` and when playback halts.

## S009 Landscape Editor & Responsive Export

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Memory:** Redesigned Landscape Editor to use a 2-pane layout (left: video/timeline, right: tool dock). Fixed Export Settings to use a constrained centered dialog in landscape. Implemented a robust orientation transition handler in `EditorScreen` that pops and re-opens the settings surface with state persistence to prevent visual corruption on rotation.

## S010 Playback Overlay Auto-hide

- **Date:** 2026-03-11
- **Memory:** Fixed the issue where playback controls stayed visible indefinitely. Implemented a 2.5s auto-hide timer active only during playback. Used a `_wasPlaying` transition tracker in the video listener to ensure controls appear when pausing and start hiding when playing. Tapping while playing toggles visibility and resets/cancels timers as needed.

## S011 Editor Speed Range Expansion

- **Date:** 2026-03-11
- **Memory:** Expanded the editor's speed adjustment range to support 0.25x to 3.0x. Updated the `Slider` in `EditorScreen` with precise 0.25x increments (divisions: 11). Verified that `FFmpegProcessor` correctly handles the expanded range for exports using chained `atempo` filters.

## S012 Editor Filters V1

- **Date:** 2026-03-11
- **Memory:** Introduced shared `VideoFilter` definitions for preview/export, with separate preview-vs-applied filter state in `EditorScreen`. Filters preview only on the video content surface, not overlays or black bars. Export wires the applied filter through `FFmpegProcessor.buildExportCommand()` before watermark overlay and before pad.
- **Testing:** Added export-command coverage for filter insertion/order and model coverage for curated filter selection. Manual QA is still pending for visual fidelity and UX regression checks.
