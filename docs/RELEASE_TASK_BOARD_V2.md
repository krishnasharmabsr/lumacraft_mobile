# Release Task Board V2

## Phase 1: Core Pipeline

- [x] Import module setup (MERGED — S002)
- [x] Preview player stabilization (MERGED — S002)
- [x] Trim functionality (MERGED — S002)
- [x] Export engine (FFmpeg) stabilization (MERGED — S002)

## Phase 2: UI Polish + Export Studio

- [x] S003 — Export Studio + UI Polish Foundation (MERGED)
- [x] S003H — Brand Alignment + Export Productization + Pro Gate (MERGED)
- [x] S004 — Editing Pack A: Speed, Aspect Ratio, Watermark (QA_PENDING)
- [x] S004E — Editor Screen Stability (Trim Pipeline Restored, Speed Slider UX).
- [x] S004F — Trim UX Polish (Auto-preview range, Remove separate Preview button).
- [x] S004G — Editor Playback UX Upgrade (Playable timeline, Audio controls, Landscape UI, Icon Toolbar, Native Duration Fallback).
- [x] S004H — Editor Player Controls Overlay + Downloaded Video Duration Parse Fix.
- [x] S004I — Duration Zero Hard Fix + Volume UI Alignment (MediaExtractor Fallback, Volume Popover).
- [x] S004K — Timeline 00:00 Root-Cause Fix + Overlay Control Cleanup (Late Duration Promotion, FFprobe harden, ±10s seek).
- [x] S004L — Downloaded Video Timeline Hard Fix (Normalization Fallback, [DurationProbe] Forensics, Overlay Overflow Fix).
- [x] S004M — Real Root-Cause Fix (Probed Duration Record Return, No-Downgrade Guard, Duplicate Volume Icon Removal).
- [x] S004N — Downloaded Video Timeline 00:00 Gate Fix (1000ms threshold + Player sanity recovery).
- [x] S004O — Fix Non-Working Seek Controls (+10/-10 and Timeline Drag).
- [x] S004Q â€” Canonical seek-flow fix merged via PR #9; PRs #4-#8 closed as superseded.
- [x] S005 — Export Reliability Hard Fix (watermark, atempo, output directory safety).
- [x] S005/C/D/E/G — Complete cumulative watermark branding & reliability fixes, branch pruned. (MERGED)
- [x] S006 — Export Quality Presets / UI Polish (S006, S006A, S006B) (MERGED)
- [x] S007 — Content-Anchored Watermark Positioning (S007, S007A) (MERGED)
- [x] S008 — Keep Screen Awake During Active Video Playback (MERGED)
- [x] S009 — Landscape Editor & Export Fixed Workspace (S009, S009A, S009B) (MERGED)
- [x] S012 - Filters V1 implemented on branch (QA_PENDING)

## Phase 3: AI Capabilities

- [ ] ML model optimization
- [ ] AI Blur / Cutout tools
- [ ] Processing memory limits

## Phase 4: Monetization & Release

- [ ] AdMob integration
- [ ] Play Billing setup
- [ ] Release hardening & diagnostics
