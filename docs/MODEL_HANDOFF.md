# LumaCraft Model Handoff

## Current Baseline

- Repo: `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- Remote: `https://github.com/krishnasharmabsr/lumacraft_mobile`
- Expected branch when resuming feature/fix work: clean `develop`
- Expected branch when resuming release-only work: clean `main`
- Integration branch: `develop`
- Release branch: `main`
- Remote default branch: `develop`
- Current app version: `1.0.0+5`
- Release signing: configured through `android/app/build.gradle.kts` with `key.properties`
- Latest signed artifact milestone: signed Android App Bundle prepared for Play Console upload

## Current Product State

LumaCraft is now past basic editor prototyping. The Android app currently includes:

- native video import
- preview playback with overlay controls and auto-hide behavior
- trim
- speed controls (`0.25x` to `3.0x`)
- canvas presets
- filters
- interactive video cropping (Crop V1)
- export studio with discrete quality presets
- watermark logic for free tier
- content-anchored watermark placement
- landscape editor workspace
- landscape-safe export settings flow
- wakelock during active playback
- RevenueCat freemium gating
- AdMob post-export interstitial foundation
- polished paywall with package cards
- restore-purchase feedback dialogs

## Revenue / Access Contract

### Free

- `480p`
- `720p`
- `24 FPS`
- `30 FPS`
- watermark remains
- ads may show after successful export when available

### Pro

- `1080p`
- `4K`
- `60 FPS`
- watermark removed
- ads disabled

### Important behavior

- `Source` FPS preserves original source FPS
- explicit `24 / 30 / 60` export selections are honored
- filters do not stack
- tool resets are scoped to the active tool
- `Reset All` restores the full edit state

## Recent Merged Work

### S013 - RevenueCat Freemium Foundation

- build-time config via `String.fromEnvironment(...)`
- `RC_ANDROID_KEY`
- debug-only `DEV_FORCE_PRO`
- live entitlement-based gating replaced hardcoded pro checks

### S014 - AdMob Foundation

- build-time config for AdMob
- export-complete interstitial placement only
- Pro users bypass ad init/load/show entirely

### S015 - Paywall Polish

- premium paywall layout
- monthly/yearly package cards
- yearly prioritized and highlighted when available
- polished unavailable-state fallback

### S016 - Restore Feedback + Paywall Copy Cleanup

- typed restore outcomes: restored / no purchases found / failed
- better restore loading state
- removed RevenueCat vendor wording from user-facing paywall copy

### S017 - Restore Feedback Visibility + Release Prep

- replaced hidden snackbars with explicit dialogs for:
  - restore success
  - no purchases found
  - restore failure
  - purchase success
- configured Android release signing
- built signed AAB
- bumped app version to `1.0.0+4` for closed testing

### S018 - Editor Time Display Fix (Speed)

- updated the displayed elapsed and total playback strings in `EditorScreen` and `TrimCard` to accurately reflect the _effective_ edited duration based on the active `speed` state
- isolated the scaling exclusively to the Presentation layer via the `_formatDuration` utility, ensuring zero regression impact to global trim bounds, underlying export logic, or scrubber integrity

### S019 - Export Success Ad Sequencing

- extracted the S017 premium dialog into a centralized `PremiumResultDialog`
- removed legacy transient snackbars from the editor export flow
- wrapped the AdMob interstitial presentation inside a `Completer<void>` that resolutely blocks until the ad is fully dismissed by the user
- explicitly sequenced the presentation layer securely so the `PremiumResultDialog` appears immediately and only after the ad sequence completes

### S020 - Architecture Stabilization V1 (Pass 1)

- extracted all 8 raw, primitive state tracking fields out of EditorScreen entirely
- introduced the EditorEdits domain model to immutably represent mathematically verifiable export timelines
- introduced the EditorPreviewOverrides presentation model to manage transient dragging behavior completely isolated from commit actions
- established secure boundary for keepEdits: true behavior mapping during post-trim duration clamping

### S021 - Architecture Stabilization V1 (Pass 2)

- completely extracted preview rendering layer out of `EditorScreen` down into `EditorPreviewSurface` and `PlaybackTimeline`
- orchestrated presentation callbacks up to `EditorScreen` while enforcing state decoupling guarantees
- simplified the visual mapping logic away from the orchestration boundaries and maintained exact pixel matching to existing UI contracts

### S022 - Architecture Stabilization V1 (Pass 3)

- stabilized export configuration flow by encapsulating inputs into immutably typed `VideoExportRequest`
- refactored `FFmpegProcessor` internal commands and `IVideoProcessor` contracts unconditionally preserving existing product contracts
- successfully modernized automated FFmpeg regression tests to use structurally sound configuration bundles

### S023 - Crop V1 Engine + UI
- implemented `CropSelection` normalized coordinate model with stable centered aspect-ratio logic
- integrated professional `CropOverlay` with refined 36px hit-test corners and accurate `EditorPreviewSurface` content-box mapping
- suppressed playback overlay interaction while in Crop mode to prevent handle blocking
- redesigned `CropToolPanel` with standard teal selection chips and real `Free` default state
- perfected visual preview parity by rendering cropped regions directly in `EditorPreviewSurface` post-apply
- enforced integer rounding (even-numbered) and source-clamping in `FFmpegProcessor` export pipeline

### S024 - Crop V1 Stabilization (Corrective)
- restored playback usability in Crop mode by making overlay background non-interactive (`IgnorePointer`) while keeping controls functional
- modified `EditorScreen` to keep the Crop tool open after `Apply Crop`, aligning with standard tool workflow
- enabled explicit clearing of aspect ratios in `CropSelection` to fix the `Free` preset selection bug
- implemented robust least-squares diagonal resizing for corner handles to provide true two-axis behavior with ratio locks
- revalidated export-path parity (`VideoExportRequest.crop` -> `FFmpegProcessor`)

### S024B - Crop V1 Corrective Stabilization (Pass 3)
- replaced the crop-mode full overlay with compact play/pause controls so playback remains usable without stealing crop gestures
- decoupled Crop panel visibility from live overlay visibility so `Apply Crop` keeps the tool open while showing the committed cropped preview immediately
- fixed `Free` re-selection by making aspect-ratio clearing explicit in `CropSelection.copyWith`
- replaced the locked-corner resize behavior with anchor-based two-axis resizing from the dragged corner
- rebuilt committed crop preview rendering in `EditorPreviewSurface` using clipped aligned content for more reliable post-apply parity
- ensured global editor reset clears crop along with trim, speed, filter, and canvas state
- follow-up adjustment: crop-mode play/pause control now renders back at the centered overlay position expected by users
- follow-up adjustment: crop move hit area is inset so free-mode corner drags are not swallowed by the central move gesture
- follow-up adjustment: crop handles now show an explicit active visual state to make the selected resize point visible
- follow-up adjustment: crop handles now render as circular targets with larger hit boxes, and drag sensitivity was increased for faster crop movement
- follow-up adjustment: handle hit targets are centered on the visible dots rather than spanning full edges, improving corner selection reliability
- follow-up adjustment: crop displacement can again be started from anywhere inside the crop region, including small crop boxes, and drag sensitivity was increased again
- follow-up adjustment: committed crop preview rendering now uses clipped translated source pixels so tiny free crops preview the exact selected area after apply
- follow-up adjustment: crop resize interaction now uses border and corner zones while the markers remain visual-only, making very small crop selections reliable
- follow-up adjustment: teal crop markers were refined into line-aligned border indicators that sit directly on the crop border instead of floating inside or outside it

### Post-S023 Stability Fixes

- **Playback Speed Persistence**: fixed regression where `VideoPlayerController` re-initialization (after trim/source change) lost the active playback speed; re-sync added to `_initializePlayer`.
- **Trim Baseline Normalization**: fixed bug where `_edits` trim state remained relative to the old source after `processTrim`; explicit reset to `[0, new_duration]` added to the `_processTrim` success path.
- **Export/Filter Sync**: verified filter survival and FFmpeg command generation; added regression test coverage for non-zero trim + filter combinations.

## Known External Platform State

### Play Console

- developer verification complete
- payment profile complete
- internal testing active with `12` testers
- closed testing active on `1.0.0+4`
- real Play subscription products/base plans created
- release signing artifacts are ready locally
- closed-testing compliance answers decided for the next Play Console pass:
  - Advertising ID: `Yes`
  - reasons:
    - `Advertising or marketing`
    - `Analytics`
    - `Fraud prevention, security, and compliance`
  - Data safety top-level: `Yes`
  - declared data types:
    - `Approximate location`
    - `Purchase history`
    - `App interactions`
    - `Diagnostics`
    - `Device or other IDs`

### RevenueCat

- project created
- entitlement identifier: `pro`
- current offering: `default`
- package structure configured:
  - `$rc_monthly`
  - `$rc_annual`
- real Play-backed subscriptions mapped to `pro`
- store-backed purchase and restore flows already verified in internal testing with Google Play test cards
- RevenueCat sandbox receives the internal-test transactions correctly

### AdMob

- app created
- App ID created
- export interstitial ad unit created
- account/app review is still in progress
- live serving may remain limited until production listing/review state is complete

### Public legal site

- separate public repo prepared for legal pages: `krishnasharmabsr/lumacraft-legal`
- developer/legal name used in public documents: `Krishna Kant`
- support email used in public documents: `lumacraftstudio.support@gmail.com`
- legal pages prepared:
  - `privacy.html`
  - `terms.html`
- expected GitHub Pages URLs:
  - `https://krishnasharmabsr.github.io/lumacraft-legal/privacy.html`
  - `https://krishnasharmabsr.github.io/lumacraft-legal/terms.html`
- Play Console privacy policy field should point to the `privacy.html` URL once GitHub Pages is enabled and live

## Public Build-Time Config

These values are safe to inject into app builds:

- `RC_ANDROID_KEY`
- `ADMOB_ANDROID_APP_ID`
- `ADMOB_INTERSTITIAL_EXPORT_ID`
- `DEV_FORCE_PRO` for debug only

Never place these in the app bundle:

- RevenueCat secret keys
- Play service-account JSON
- keystore secrets
- admin credentials

## Closed Testing Build Config

Use these values for the active Android closed-testing bundle:

- `RC_ANDROID_KEY=goog_ofdcUQJjlZWEkVnQlaEPiUviKkR`
- `ADMOB_ANDROID_APP_ID=ca-app-pub-3940256099942544~3347511713`
- `ADMOB_INTERSTITIAL_EXPORT_ID=ca-app-pub-3940256099942544/1033173712`
- keep `DEV_FORCE_PRO` unset for release / closed-testing builds

This preserves real Play-backed RevenueCat purchase testing while keeping AdMob on Google test IDs until AdMob review/live readiness is complete.

## Operational Notes

## Branch / Release Workflow

- Create all new `feat/...` and `fix/...` branches from clean `develop`
- Merge approved feature/fix branches into `develop` first
- Keep `main` reserved for release-ready promotions only
- Do not merge `develop` into `main` unless the user explicitly instructs it
- Default rule: bump app version when promoting approved `develop` state into `main`
- Explicit exception: `develop` may carry a closed-testing candidate version bump when the user requests pre-release build preparation before the final promotion
- Update `docs/RELEASE_NOTES.md` as part of every versioned `main` promotion

- If config is missing, the app must fall back safely:
  - freemium defaults to free tier
  - AdMob remains a no-op when unavailable
- Do not reintroduce `.env` for mobile monetization config
- Keep production-facing text product-focused; do not expose backend vendor names in user copy
- AdMob placement is intentionally minimal for now: only after successful export

## Next Practical Focus

Priority should stay on release productization, not random feature expansion:

1. finish Play Console compliance/app content entry:
  - Advertising ID declaration
  - Data safety form
2. finish AdMob review / production linkage
3. legal-page publishing and store listing / compliance readiness
4. production rollout readiness after closed testing sign-off
5. decide the next post-crop editor feature only after `develop` integration remains stable

## Related References

- `docs/AGENT_MEMORY.md`
- `docs/RELEASE_TASK_BOARD_V2.md`
- `docs/PLATFORM_ONBOARDING_CHECKLIST.md`
- `docs/TEST_LOG_ANDROID.md`
