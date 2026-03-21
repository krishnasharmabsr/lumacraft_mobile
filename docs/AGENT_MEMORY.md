# Agent Memory Context

## Repo Identity

- Project: `lumacraft_mobile`
- Local path: `C:\Users\pc\Documents\GitHub\VideoEditor\lumacraft_mobile`
- Remote: `https://github.com/krishnasharmabsr/lumacraft_mobile`
- Expected resume point: clean `main`

## Current Stable Baseline

The app is no longer in early pipeline stabilization. Current `main` includes:

- editor playback with overlay auto-hide
- trim / speed / canvas / filters
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
- `version: 1.0.0+3`

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
- version bumped to `1.0.0+3`

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
- real Play subscription products / base plans created
- release signing and signed bundle prep already exist locally

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
- Play internal testing in progress

What is still external/platform-dependent:

- AdMob full review / live serving
- public legal-page hosting / privacy policy URL activation
- privacy / store listing completion

## Reference Files

- `docs/MODEL_HANDOFF.md`
- `docs/RELEASE_TASK_BOARD_V2.md`
- `docs/PLATFORM_ONBOARDING_CHECKLIST.md`
- `docs/TEST_LOG_ANDROID.md`
