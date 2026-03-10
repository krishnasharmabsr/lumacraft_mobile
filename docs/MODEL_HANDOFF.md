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

- **Completed:** S001 + S001B + S002 + S003/A/B/H + S004 + S004A/B/C/D/E/F/G/H/I/K/L/M/N/O (Export Hotfix/UX/Stability/Duration/Seek).
- **Active:** S005 (Video AI Generation Foundation)

## Environment Identity

- **Local Path:** `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- **Remote Repo:** `https://github.com/krishnasharmabsr/lumacraft_mobile`

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
