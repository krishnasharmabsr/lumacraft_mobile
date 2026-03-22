# Platform Onboarding Checklist

This file tracks the external platform setup needed before LumaCraft can ship a production Android build with subscriptions and ads.

## Purpose

Use this checklist when:
- Play Console verification is still pending
- RevenueCat is being configured
- AdMob is being configured
- release AAB build configuration is being prepared

This is the shared reference for:
- product planning
- agent execution prompts
- model handoff continuity
- manual owner setup progress

## Current Status

- Play Console developer account: fully verified
- Play Console app entry: created
- Play internal testing: active with 12 testers
- Play closed testing: active on `1.0.0+4`
- RevenueCat project: created
- RevenueCat entitlement / offering: created and linked to real Play subscriptions
- AdMob app setup: created
- AdMob App ID + export interstitial unit: created
- AdMob review: still in progress pending production listing state
- Production release AAB: signed local artifact already prepared
- Public legal-site repo: created as `krishnasharmabsr/lumacraft-legal`
- Public legal-page owner/contact:
  - developer name: `Krishna Kant`
  - support email: `lumacraftstudio.support@gmail.com`
- Closed-testing build decision:
  - RevenueCat: use real Android public SDK key
  - AdMob: use Google test App ID + interstitial ID
  - target app version: `1.0.0+4`
- Play Console compliance answers fixed for the next submission pass:
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

## 1. Google Play Console

### Account setup

- Complete developer identity verification
- Complete contact phone verification
- Confirm Play Console account is fully activated
- Confirm app creation is available in Play Console

### After verification completes

- Create the Android app entry
- Finalize app name, default language, and app type
- Enable Play App Signing
- Create internal testing track
- Prepare store listing basics
- Create subscription product(s) for Pro

### Keep ready before app entry

- Final app title
- Final package/application ID
- Privacy policy URL
- Support email
- Feature graphic, icon, screenshots
- Upload key / keystore backup

## 2. RevenueCat

### Account and project

- Create RevenueCat account
- Create project for LumaCraft
- Add Android app inside RevenueCat
- Define entitlement ID: `pro`

### Product model

- Create offering for Pro access
- Link Play subscription/in-app product(s) to the offering
- Current linked pricing baseline:
  - monthly: `249`
  - yearly: `1499`
- Confirm entitlement mapping unlocks:
  - 1080p export
  - 4K export
  - 60 FPS
  - watermark removal

### Credentials and backend connection

- Create Google service account for Play Developer API access
- Grant required Play Console/API permissions
- Upload the service-account JSON to RevenueCat
- Do not place service-account credentials inside the app repo or app bundle

### App integration values

The app should only receive:
- RevenueCat public Android SDK key

The app should never receive:
- secret RevenueCat API keys
- service-account JSON

## 3. AdMob

### Account setup

- Create AdMob account
- Add/register the LumaCraft app
- Generate AdMob App ID
- Generate ad unit IDs

### Initial monetization plan

Recommended first rollout:
- Interstitial after export completion or after repeated exports
- Rewarded ad later, if needed for temporary premium-style unlocks

### Required supporting setup

- Set up `app-ads.txt`
- Prepare privacy policy ad disclosures
- Confirm user consent flow requirements

## 3B. Public Legal Pages

### Repo / hosting plan

- Dedicated public repo: `krishnasharmabsr/lumacraft-legal`
- Expected GitHub Pages URLs:
  - `https://krishnasharmabsr.github.io/lumacraft-legal/privacy.html`
  - `https://krishnasharmabsr.github.io/lumacraft-legal/terms.html`

### Document identity

- Developer name on legal pages: `Krishna Kant`
- Support contact on legal pages: `lumacraftstudio.support@gmail.com`
- Privacy Policy URL in Play Console should point to `privacy.html`

### App integration values

The app may receive:
- AdMob App ID
- Ad unit IDs

The app should not receive:
- private account credentials

## 4. Build and Config Strategy

Use build-time configuration, not checked-in secrets.

### Allowed in app build config

- RevenueCat public Android SDK key
- AdMob App ID
- AdMob ad unit IDs

### Must stay outside the app bundle

- RevenueCat secret keys
- Google service-account JSON
- private keystore secrets
- any admin credentials

### Expected injection style

- `--dart-define` for Flutter-side public config
- Gradle manifest placeholders where required for Android manifest values
- CI or local release command should inject production values

### Closed-testing Android values

Use these values for the next Play closed-testing build:

- `RC_ANDROID_KEY=goog_ofdcUQJjlZWEkVnQlaEPiUviKkR`
- `ADMOB_ANDROID_APP_ID=ca-app-pub-3940256099942544~3347511713`
- `ADMOB_INTERSTITIAL_EXPORT_ID=ca-app-pub-3940256099942544/1033173712`
- `DEV_FORCE_PRO` must remain unset in release builds

## 5. Debug and QA Strategy

### Premium feature QA

Use a debug-only override for engineering validation:
- `DEV_FORCE_PRO=true`

Rules:
- only works in debug/non-release contexts
- ignored in release builds
- real RevenueCat entitlement remains source of truth in production

### Billing QA

- Use Play internal testing
- Use RevenueCat real offering setup
- Test purchase flow
- Test restore purchases
- Internal test result:
  - purchase: passed
  - restore: passed
  - Pro ads-off: passed
  - Pro watermark-off: passed

## 6. Release Readiness Gate

Do not call the Android build production-ready until all are true:

- Play Console verification completed
- app entry created
- internal testing track available
- RevenueCat entitlement and offering configured
- AdMob app and units configured
- build-time keys injected safely
- privacy policy ready
- ads/user disclosures ready
- Pro gating validated in debug and internal testing
- release AAB tested successfully

## 7. Owner Progress Log

Update this section as platform work progresses.

- [ ] Play Console identity approved
- [x] Play Console identity approved
- [x] Play Console app entry created
- [x] Play internal testing track created
- [x] RevenueCat project created
- [x] RevenueCat entitlement `pro` created
- [x] RevenueCat offering linked to Play products
- [x] AdMob account created
- [x] AdMob app registered
- [x] AdMob App ID created
- [x] Ad unit IDs created
- [ ] Privacy policy published
- [ ] Terms page published
- [ ] GitHub Pages enabled and legal URLs live
- [x] Release config values ready for injection
- [ ] Advertising ID declaration entered in Play Console
- [ ] Data safety form entered in Play Console
- [x] Closed-testing `1.0.0+4` AAB rebuilt with final closed-testing config

## 8. Notes for Future Agent Work

When implementing or reviewing monetization-related tasks:

- assume free tier by default if config is missing
- never hardcode production secrets
- prefer build-time injection over runtime `.env`
- keep release behavior safe when platform config is incomplete
- use this checklist as the reference before asking for production monetization approval
