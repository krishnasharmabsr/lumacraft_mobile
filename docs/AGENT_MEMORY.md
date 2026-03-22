# Agent Memory Context

## Repo Identity

- Project: `lumacraft_mobile`
- Local path: `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- Remote: `https://github.com/krishnasharmabsr/lumacraft_mobile`
- Expected resume point for feature/fix work: clean `develop`
- Expected resume point for release-only work: clean `main`

## Current Stable Baseline

The app is no longer in early pipeline stabilization. Current `main` includes:

- editor playback with overlay auto-hide
- trim / speed / canvas / filters / crop (V1)
- export studio with locked pro options
- stable watermark logic anchored to visible content
- landscape editor split layout
- landscape-safe export settings flow
- explicit FPS export honoring selected `24 / 30 / 60`
- RevenueCat freemium foundation
- AdMob post-export interstitial foundation
- paywall polish with live package cards
- restore purchase feedback dialogs
- signed release AAB prep
- `version: 1.0.0+5`

## Branch / Release Policy

- `develop` is the integration branch for all new `feat/...` and `fix/...` work
- `develop` is also the intended default branch locally and on remote
- new feature/fix branches must be created from clean `develop`
- approved work merges into `develop` first
- `main` is reserved for release-ready promotions only
- do not merge `develop` into `main` unless the user explicitly instructs it
- default rule: app version bumps happen on `main`
- explicit exception: `develop` may carry a closed-testing candidate version bump when the user requests pre-release build preparation before final promotion
- every version bump on `main` must include updated `docs/RELEASE_NOTES.md`

## Hard Product Contracts

### Free tier

- max resolution: `720p`
- max FPS: `30`
- watermark remains
- ads may show after successful export

### Pro tier

- `1080p`
- `4K`
- `60 FPS`
- no watermark
- no ads

### Editing contract

- filters do not stack
- filters are independent from trim/speed/canvas
- tool-level reset affects only that tool
- `Reset All` restores the entire edit state
- `Source` FPS preserves source rate
- explicit FPS choices must not clamp back to the source rate

## Recent Merged Tasks

### S013

- RevenueCat freemium gating
- build-time config
- debug-only `DEV_FORCE_PRO`

### S014

- AdMob service foundation
- export-complete interstitial only
- Pro suppresses all ads

### S015

- premium paywall layout
- package selection cards
- yearly emphasis

### S016

- restore-purchase feedback states improved
- paywall copy cleaned to remove backend wording

### S017

- snackbars replaced with explicit dialogs for purchase/restore results
- Android release signing configured
- signed AAB built
- version bumped to `1.0.0+4` for closed testing

### S018

- fixed editor time display UX after speed multiplier is applied
- introduced display-only `speed` parameter to `_formatDuration` to mathematically scale the duration before string interpolation
- preserved native timestamp integrity for all trim bounds, timeline scrubber logic, and FFmpeg export configurations

### S019

- extracted the premium dialog into a reusable `PremiumResultDialog` component
- enforced structural async execution sequencing using a `Completer` for `AdMobService`
- permanently deleted legacy snackbars from export completion output in favor of blocking dialogs

### S020

- State Model Extraction: editor state strictly isolated into committed `EditorEdits` and transient `EditorPreviewOverrides` with behavior-preserving `keepEdits: true` semantics
- explicitly eliminated mixed local state mutation paths during player keepEdits lifecycles

### S021

- Layout Extraction: preview UI cleanly separated into `EditorPreviewSurface` and `PlaybackTimeline` while keeping `EditorScreen` as the orchestration root
- preview rendering/layout responsibilities moved out of `EditorScreen` without changing playback, filter, canvas, or export behavior

### S022

- VideoExportRequest encapsulation: strictly consolidated editor config bundles replacing granular args payload
- safely migrated `FFmpegProcessor` building flows without FFmpeg command generation or business behavior change

### S023 - Stabilized Interactive Crop V1
- implemented `CropSelection` normalized coordinate model with stable centered aspect-ratio logic
- integrated professional `CropOverlay` with refined 36px hit-test corners and accurate `EditorPreviewSurface` content-box mapping
- suppressed playback overlay interaction while in Crop mode to prevent handle blocking
- redesigned `CropToolPanel` with standard teal selection chips and real `Free` default state
- perfected visual preview parity by rendering cropped regions directly in `EditorPreviewSurface` post-apply
- verified `crop` filter in the export pipeline with coordinate clamping and even-integer rounding matches preview result exactly

### S024 - Crop V1 Stabilization (Corrective)
- fixed playback control usability in Crop mode using non-interactive overlay background (`IgnorePointer`)
- enforced tool persistence: Crop tool remains open after `Apply Crop` for better UX
- corrected `Free` preset logic by allowing explicit clearing of aspect ratios in `CropSelection`
- implemented robust least-squares diagonal resizing for ratio-locked corner handles
- revalidated export-path parity (`VideoExportRequest.crop` -> `FFmpegProcessor`)
- verified all 88 regression tests pass on `feat/crop-v1`

### S024B - Crop V1 Corrective Stabilization (Pass 3)
- replaced the blocking crop-mode overlay with compact play/pause controls so crop gestures remain usable while playback stays controllable
- decoupled Crop tool visibility from live overlay visibility so `Apply Crop` keeps the panel open while the committed cropped preview becomes visible immediately
- fixed `CropSelection.withAspectRatio(null)` by making aspect-ratio clearing explicit and value-safe
- replaced the corner resize behavior with anchor-based two-axis resizing for ratio-locked corner drags
- restored committed crop preview rendering in `EditorPreviewSurface` using clipped aligned content instead of the previous unstable transform
- ensured global editor reset also clears committed/preview crop state
- verified all 92 regression tests pass locally on `feat/crop-v1`
- follow-up tweak: crop-mode play/pause control returned to the centered overlay position expected by QA
- follow-up tweak: crop move gestures are now inset away from edges/corners so free-mode corner drags are not stolen by the center move detector
- follow-up tweak: all 8 crop handles now expose an explicit active visual state so the selected resize point is visible during interaction
- follow-up tweak: crop handles now render as circular targets with larger hit areas, and drag sensitivity was increased slightly to reduce sticky-feeling movement
- follow-up tweak: handle hit targets are now centered on the visible dots instead of stretching across the full edge, reducing corner/edge overlap during selection
- follow-up tweak: drag sensitivity increased again to better match finger travel, and full-area crop displacement was restored even for smaller crop regions
- follow-up tweak: committed crop preview now uses clipped translated source pixels so very small free-crop selections preview the exact chosen region after apply
- follow-up tweak: crop resize interaction now comes from border and corner zones, with markers acting as visual indicators only, which makes tiny-crop resizing reliable
- follow-up tweak: crop markers were converted into line-aligned border indicators that sit directly on the crop border for both normal and small crop boxes

### Post-S023 Stability Fixes

- **Playback Speed Persistence**: Added speed re-sync to `_initializePlayer` to prevent speed loss during controller re-initialization.
- **Trim Baseline normalization**: Implemented explicit trim reset to `[0, duration]` in `_processTrim` success path to correctly baseline the new trimmed source.
- **Export/Filter Verification**: Confirmed filter survival and command injection; added non-zero trim export test coverage.

## Build / Config Memory

Public app-side config:

- `RC_ANDROID_KEY`
- `ADMOB_ANDROID_APP_ID`
- `ADMOB_INTERSTITIAL_EXPORT_ID`
- `DEV_FORCE_PRO` for debug only

Never bundle:

- RevenueCat secret keys
- Play service-account credentials
- keystore secrets
- admin credentials

## External Platform State

### RevenueCat

- project exists
- entitlement identifier: `pro`
- offering identifier: `default`
- real Play-backed products are now linked
- active package structure:
  - `$rc_monthly`
  - `$rc_annual`
- current subscription pricing baseline:
  - monthly: `249`
  - yearly: `1499`
- internal-test purchase and restore flows have already been validated with Google Play test cards
- RevenueCat sandbox updates correctly during internal testing

### AdMob

- Android app registered
- App ID created
- export interstitial ad unit created
- review is still in progress
- live serving may remain limited until production listing / review state is complete

### Play Console

- developer verification complete
- payment profile complete
- internal testing track active with `12` testers
- closed testing is now active on `1.0.0+4`
- real Play subscription products / base plans created
- release signing and signed bundle prep already exist locally
- closed-testing compliance answers fixed for the next console pass:
  - Advertising ID: `Yes`
  - reasons:
    - `Advertising or marketing`
    - `Analytics`
    - `Fraud prevention, security, and compliance`
  - Data safety top-level: `Yes`
  - selected data types:
    - `Approximate location`
    - `Purchase history`
    - `App interactions`
    - `Diagnostics`
    - `Device or other IDs`

### Public legal site

- separate public repo exists for legal/compliance pages: `krishnasharmabsr/lumacraft-legal`
- public-facing document owner name: `Krishna Kant`
- support contact: `lumacraftstudio.support@gmail.com`
- legal page files prepared in that repo:
  - `index.html`
  - `privacy.html`
  - `terms.html`
- expected policy URLs:
  - `https://krishnasharmabsr.github.io/lumacraft-legal/privacy.html`
  - `https://krishnasharmabsr.github.io/lumacraft-legal/terms.html`
- if GitHub Pages is not yet enabled/live, treat public policy hosting as still pending for release readiness

## Current Release Readiness Reality

What is ready:

- signed AAB generation
- freemium gating
- paywall flow
- real store-backed purchase flow in internal testing
- real store-backed restore flow in internal testing
- Pro suppression of ads
- Pro watermark removal
- Play internal testing completed and closed testing started
- closed-testing config decision:
  - real RevenueCat Android public key
  - AdMob Google test App ID + interstitial ID
  - current closed-testing build: `1.0.0+5`

What is still external/platform-dependent:

- AdMob full review / live serving
- public legal-page hosting / privacy policy URL activation
- privacy / store listing completion
- Play Console submission of Advertising ID and Data safety forms

## Reference Files

- `docs/MODEL_HANDOFF.md`
- `docs/RELEASE_TASK_BOARD_V2.md`
- `docs/PLATFORM_ONBOARDING_CHECKLIST.md`
- `docs/TEST_LOG_ANDROID.md`
