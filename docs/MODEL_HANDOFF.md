# ML Model Handoff Architecture

## Principles

- All models must be evaluated against strict memory bounds (`< 200MB` peak during inference) to ensure stable background operations.
- Inter-layer communication for model tracking should be heavily decoupled and dependency injected.
- Any model addition or swap requires updating this document with new benchmark results.

**Objective**: Finalize Editor screen playback UX with an overlay controls system and harden duration/seek fallback (S004H-O).
**Key Decisions**:

- Implemented tap-to-toggle overlay player controls.
- Hardened `_resolveDurationViaFFprobe` adding robust sexagesimal parsing `_parseDurationString`.
- Forced `FileInputStream` fallback in `MainActivity.kt`'s `MediaMetadataRetriever` usage when file paths fail.
- Restructured `EditorScreen` to nest controls overlay inside video viewport, removing external duplicated bars.

## Next Up: S005 / Review

**Objective**: Fix the ML Export / FFmpeg pipeline broken in S004D.g

## Task Tracking

- **Completed:** S001 + S001B + S002 + S003/A/B/H + S004 + S004A/B/C/D/E/F/G/H/I/K/L/M/N/O + S005/A/B/C/D/E/G + S006/A/B + S007/A + S008 + S009/A/B (Export/UX/Stability/Landscape).
- **Active:** S010 (AI Feature TBD)

## Environment Identity

- **Local Path:** `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- **Remote Repo:** `https://github.com/krishnasharmabsr/lumacraft_mobile`

## S005D Branding Consistency

- **Date:** 2026-03-10
- **Focus:** Unified all runtime logo references to canonical `assets/branding/logo_mark_master_1024.png`. Removed stale `logo_mark.png`. Created `docs/BRAND_REGISTRY.md`.

## S006 Export Quality Presets & UI Polish

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Focus:** Replaced the freeform quality slider in Export Studio with discrete `Low`, `Standard`, and `High` presets. Mapped output behavior strictly to stable codecs (`mpeg4: q:v` of 6, 4, 2 respectively mapped to audio bitrates of 96k, 128k, 192k) inside `FFmpegProcessor`. UI was updated to a premium segmented control style. Also refined the export processing overlay and success snackbars (S006A and S006B).

## S007 Content-Anchored Watermark

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Focus:** Fixed the watermark placement logic in the export pipeline so it anchors perfectly to the edge of the visible video frame, never rendering on the black padding introduced by forcing landscape/square resolutions. Implemented using a scale -> overlay -> pad filter graph sequentially within `FFmpegProcessor`.

## S008 Keep Screen Awake During Playback

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Focus:** Implemented screen wake-locking using `wakelock_plus`. The lock is exclusively tied to the `EditorScreen`'s active playback state, cleanly releasing the lock if paused, buffering, or if the screen is dismissed entirely.

## S005E Brand Identity Polish

- **Date:** 2026-03-10
- **Branch:** `feat/s005e-brand-identity-polish` (branched from main, isolating from S005 series)
- **Focus:** Regenerated clean vector-based PNGs without checkerboard artifacts. Regenerated adaptive Android icons. Polished splash animation duration to 1.5s total. seek handling with a single playback timeline, deterministic normalized playback source, and verified centralized seek flow for scrub plus +/-10 actions.

## S005E2 Branding Lockdown Fix

- **Date:** 2026-03-11
- **Focus:** Complete branding lockdown. Hand-generated a perfect teal logo matching `AppColors.accent`, strictly optically-centered on X bounding box. Banned `Icons.movie_edit` in fallback context, replacing with `Icons.play_arrow_rounded`. Fixed home screen version string and button motifs.

## S004Q Start

- **Date:** 2026-03-10
- **Branch:** `fix/s004p-seek-proxy-fix`
- **Focus:** Takeover after model switch to replace proxy/ratio-based seek handling with a single playback timeline, deterministic normalized playback source, and verified centralized seek flow for scrub plus +/-10 actions.

## S004Q Update

- **Status:** Merged to `main` via PR `#9`
- **Result:** Removed proxy timebase seek mapping from editor playback, introduced deterministic playback-source preparation with normalization for imported/problematic sources, and rewired scrub plus +/-10 to the same verified seek helper with reinit fallback.
- **Validation:** `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter build apk --release` all passed on 2026-03-10.
- **PR Consolidation:** PR `#9` was squash-merged as the canonical cumulative merge. PRs `#4`, `#5`, `#6`, `#7`, and `#8` were closed as superseded by `#9`.
- **Next Step:** Manual Android QA must confirm downloaded-video scrub and +/-10 behavior on-device on clean `main`.

## S005 Start

- **Date:** 2026-03-10
- **Branch:** `main` (Merged)
- **Focus:** Export reliability hard fix — watermark pipeline, filter graph determinism, atempo chaining, audio mapping.

## S005G Watermark Target Port Lockup
- **Date:** 2026-03-11
- **Focus:** Safe watermark asset port. Generated vector-clean `watermark_lockup.png` applied via preflight substitution. Merged all safe S005 fallback matrix (S005A, S005B, S005C-EXEC, S005D, S005G) strictly and pruned branch history completely. `main` is now functionally verified as the pristine baseline.

## S009 Landscape Editor & Export Fixed Workspace
- **Date:** 2026-03-11
- **Status:** Merged to `main` (commit: `702a69f`)
- **Focus:** Implemented a two-pane landscape layout for the editor. Refactored Export Studio to be responsive (centered modal in landscape, bottom sheet in portrait). Hardened orientation transitions while Export Settings are open using a pop-and-reopen safety pattern with state persistence.
