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

- **Completed:** S001 + S001B + S002 + S003/A/B/H + S004 + S004A/B/C/D/E/F/G/H/I/K/L/M/N/O + S005/A/B/C/D/E/G + S006/A/B + S007/A + S008 + S009/A/B + S010 + S011 + S012/A/B/C + S013 + S014 + S015.
- **Active:** Next phase features pending

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

## S010 Playback Overlay Auto-hide

- **Date:** 2026-03-11
- **Status:** Merged to `main` (commit: `7f3971c`)
- **Focus:** Implemented inactivity-based auto-hiding for editor playback controls. Controls hide after 2.5s of playing if no interaction occurs. Controls stay visible when paused. Transitions between playing/paused correctly sync overlay visibility.

## S011 Editor Speed Range Expansion

- **Date:** 2026-03-11
- **Status:** Completed on `feat/s011-speed-range-025-to-30`
- **Focus:** Expanded the editor's speed adjustment range to support 0.25x to 3.0x. Updated the `Slider` in `EditorScreen` with precise 0.25x increments (divisions: 11). Verified that `FFmpegProcessor` correctly handles the expanded range (0.25x-3.0x) for exports using chained `atempo` filters.

## S012 Editor Filters V1

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Focus:** Added a Filters tool to the editor with curated presets: Original, Bright, Contrast, Warm, Cool, Vintage, and B&W. Preview is contained to the video content widget only via `ColorFiltered`, while export applies FFmpeg filter equivalents before watermark overlay and before final pad so watermark assets and black bars stay visually normal.
- **Validation:** `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter build apk --release` passed on 2026-03-11.
- **Known Gap:** Preview and export are intentionally approximate, not exact-parity; preview uses Flutter color-matrix approximations while export uses FFmpeg filters chosen to stay reasonably close.

## S012 Filters UI Polish

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Focus:** Replaced the wrapped multi-row filter chip layout with a single horizontal scrollable selector to reduce panel height and improve portrait usability. Selected state remains accent-filled, applied state remains marked with a check indicator, and apply/export behavior was left unchanged.

## S012 Filter State Messaging Consistency

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Root Cause:** The Filters panel exposed preview and applied/export state from separate UI elements without labeling them explicitly enough. The top pill represented the applied/export filter while the helper text represented the previewed filter, which could appear contradictory during QA even when the underlying state was correct.
- **Fix:** Introduced a shared `FilterPanelState` model so the top pill, helper text, and apply CTA are derived from one preview-vs-applied source of truth. The pill now reads `Export: ...`, helper text always states both preview and export semantics, and the apply button disables once preview already matches export.

## S012A/B/C Follow-up Fixes

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Focus:** 
  - **S012A:** Clarified Filter Behavior Contract so filters do not stack and global reset correctly restores them.
  - **S012B:** Fixed `Bright` and `Contrast` export failure caused by missing `eq` filter in FFmpegKit; replaced with robust `colorlevels` calculation and corrected false fallback logic in `FFmpegProcessor`.
  - **S012C:** Implemented tool-scoped UI reset buttons inside Trim, Canvas, Filter, and Speed panels for precision UX alongside the `Reset All` global option.

## S013 RevenueCat Freemium Foundation

- **Date:** 2026-03-11
- **Status:** Merged to `main`
- **Branch:** `feat/s013-revenuecat-freemium-foundation` (merged)
- **Focus:** Implemented robust freemium gating via RevenueCat. Replaced hardcoded checks with dynamic entitlement verifications, added build-time config via `String.fromEnvironment(...)`, introduced debug-only `DEV_FORCE_PRO`, and shipped a minimalist `PaywallSheet` UI for 1080p, 4K, and 60 FPS upsell flow. Free/pro export gating and watermark behavior now follow live entitlement state.

## S013B Honor Explicit FPS Selection in Export

- **Date:** 2026-03-12
- **Status:** Merged to `main`
- **Root Cause:** `FFmpegProcessor.processExport()` probed source FPS and clamped any explicit user-selected `30` or `60` FPS back down to the lower source FPS before command construction. On 24 FPS inputs, both `30` and `60` therefore collapsed back to `24`.
- **Fix:** Removed source-FPS clamping from export preparation and added an explicit `fps=` stage in the FFmpeg filter graph for non-`Source` selections, while still emitting `-r <selected>` on output. `Source` mode still omits both and preserves the original timestamps.
- **Validation:** `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter build apk --release` passed on 2026-03-12.

## S014 AdMob Foundation + No Ads for Pro

- **Date:** 2026-03-12
- **Status:** Merged to `main`
- **Focus:** Added AdMob foundation with build-time config via `String.fromEnvironment(...)`, Android manifest placeholder wiring for AdMob app ID, and a dedicated `AdMobService` with safe no-op fallback when config is missing. Implemented only one placement for V1: export-complete interstitial after successful gallery save.
- **Contract:** Free users can load/show the export interstitial when available. Pro users bypass AdMob initialization, loading, and showing entirely via `ProGate.isPro`.

## S015 Paywall Polish + Real Package Presentation

- **Date:** 2026-03-12
- **Status:** Merged to `main`
- **Focus:** Rebuilt the paywall into a premium dark-sheet layout with stronger hierarchy, benefit blocks, real package cards, and a CTA/footer zone. Real RevenueCat offerings are presented through package-selection cards with yearly prioritized and visually highlighted when both yearly and monthly exist.
- **Fallback:** Missing offerings remain safe: no fake pricing is shown, restore stays visible, and the unavailable state stays polished with retry.

## S016 Restore Purchases Feedback + Paywall Copy Cleanup

- **Date:** 2026-03-12
- **Status:** Merged to `main`
- **Focus:** Refined the paywall restore path so it no longer silently no-ops. `RevenueCatService.restorePurchases()` now returns typed restore outcomes for restored entitlement, no purchases found, and failure. `PaywallSheet` now exposes a distinct restore-loading state, explicit user-facing feedback for each restore result, and cleaned the pricing helper copy to remove vendor wording.
- **Validation:** `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter build apk --release` passed on 2026-03-12.

## S017 Restore Purchase Feedback Visibility & Play Console Release

- **Date:** 2026-03-14
- **Status:** Merged to `main`
- **Focus:** Addressed invisible SnackBar feedback during the _restorePurchases_ and _purchasePackage_ flows caused by BottomSheet modal contexts unmounting. Replaced them with custom, premium-styled `Dialog` overlays. Configured production signing in `build.gradle.kts` using `key.properties`. Built a signed release Android App Bundle (AAB), bumped the version to `1.0.0+3` (`versionCode 3`) to resolve Play Console duplicates, and successfully handed off the artifact for internal testing.
