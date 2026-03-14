# LumaCraft Mobile

A premium video editing experience built with Flutter and FFmpeg.

## Project Status Summary (2026-03-14)

The project has reached a stable, feature-complete state for its initial core release.

### Core Features (Phase 1 & 2)

- **Engine Reliability:** Normalized playback source for imported/downloaded videos with robust seek fallbacks.
- **Export Studio:** Complete with resolution controls (up to 4K), FPS selection (24, 30, 60), orientation support, and quality presets.
- **Editing Tools:** 
  - **Trim:** Precise frame-accurate timeline trimming.
  - **Speed:** 0.25x to 3.0x adjustment with high-quality audio processing (`atempo`).
  - **Filters:** Curated set of filters (B&W, Vintage, etc.) with real-time preview and export integration.
  - **Canvas:** Multi-aspect ratio support (9:16, 1:1, 16:9) with content-anchored watermark logic.

### Branding & UI (Phase 2 Polish)

- Unified Teal core branding (`AppColors.accent`).
- High-fidelity assets and adaptive Android icons.
- Polished splash animations and responsive landscape layout for the editor.

### Monetization & Ads (Phase 4 Foundation)

- **RevenueCat:** Real entitlement wiring. Pro tier unlocks 1080p+, 60 FPS, and removes watermarks.
- **AdMob:** Interstitial ad placement on export completion for free users (suppressed for Pro).
- **Paywall:** Production-ready surface with live package presentation and "Restore Purchases" feedback.

---

## 🛠 Active Branch Status

**Current Branch:** `fix/s016-restore-feedback-paywall-copy`  
**Status:** **Stable / Ready for Merge**  
**Summary:** This branch addresses the final polish for the Monetization UI:
- Implements explicit "Restoring..." feedback states.
- Normalizes Paywall copy to comply with store guidelines.
- Fixes minor UI alignment issues in the Export Studio.

---

## Next Steps
1. **Merge** `fix/s016-restore-feedback-paywall-copy` into `main`.
2. **Production Signing:** Configure `key.properties` (Keystore pending owner setup).
3. **AAB Generation:** Build and upload to Google Play Internal Testing.
