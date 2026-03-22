# LumaCraft Model Handoff

## Current Baseline

- Repo: `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- Remote: `https://github.com/krishnasharmabsr/lumacraft_mobile`
- Expected branch when resuming: clean `main`
- Current app version: `1.0.0+4`
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

## Related References

- `docs/AGENT_MEMORY.md`
- `docs/RELEASE_TASK_BOARD_V2.md`
- `docs/PLATFORM_ONBOARDING_CHECKLIST.md`
- `docs/TEST_LOG_ANDROID.md`
