# ML Model Handoff Architecture

## Principles

- All models must be evaluated against strict memory bounds (`< 200MB` peak during inference) to ensure stable background operations.
- Inter-layer communication for model tracking should be heavily decoupled and dependency injected.
- Any model addition or swap requires updating this document with new benchmark results.

## Current Sprint Focus: S004H (COMPLETED)

**Objective**: Finalize Editor screen playback UX with an overlay controls system and harden duration fallback.
**Key Decisions**:

- Implemented tap-to-toggle overlay player controls.
- Hardened `_resolveDurationViaFFprobe` adding robust sexagesimal parsing `_parseDurationString`.
- Forced `FileInputStream` fallback in `MainActivity.kt`'s `MediaMetadataRetriever` usage when file paths fail.
- Restructured `EditorScreen` to nest controls overlay inside video viewport, removing external duplicated bars.

## Next Up: S005 / Review

**Objective**: Fix the ML Export / FFmpeg pipeline broken in S004D.g

## Task Tracking

- **Completed:** S001 + S001B + S002 + S003/A/B/H + S004 + S004A/B/C/D/E/F/G/H (Export Hotfix/UX/Stability).
- **Active:** S005 (Video AI Generation Foundation)

## Environment Identity

- **Local Path:** `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- **Remote Repo:** `https://github.com/krishnasharmabsr/lumacraft_mobile`
