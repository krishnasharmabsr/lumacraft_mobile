# Brand Registry

## Brand Attributes

- **Chosen Name:** LumaCraft
- **Locked Date:** 2026-03-10
- **Rule:** No rename without explicit approval from core stakeholders.

## Historical Options (Rejected)

1. VideoFlow Studio
2. RapidClip Mobile
3. FreeRender AI

## Rename History

- **2026-03-10:** Renamed from the original bootstrap name to `LumaCraft` to better reflect the lighting (Luma) and creator-focused (Craft) nature of the application, prioritizing a premium brand feel over the more aggressive sounding "cut". GitHub repository and local folders renamed to `lumacraft_mobile`.

## Canonical Master Asset

| Asset | Path | Purpose |
|-------|------|---------|
| Master Logo | `assets/branding/logo_mark_master_1024.png` | Single source of truth for all runtime UI and icon generation. MUST be pure vector/PNG-generated with transparent background (no checkerboard pixel artifacts allowed). |
| Icon Foreground | `assets/branding/ic_launcher_foreground.png` | Android adaptive icon foreground (derived from master, transparent background). |

## Runtime UI References

| Screen | Widget | Asset Path |
|--------|--------|------------|
| Splash | `Image.asset` in `SplashScreen` | `assets/branding/logo_mark_master_1024.png` |
| Home | `Image.asset` in `HomeScreen` | `assets/branding/logo_mark_master_1024.png` |
| Export watermark | `rootBundle.load` in `FFmpegProcessor` | `assets/branding/logo_mark_master_1024.png` |

> [!IMPORTANT]
> **Fallback Policy**: Any `errorBuilder` for the master logo must render a structurally similar fallback: a container with `AppColors.accentGradient` and the `Icons.play_arrow_rounded` (matching the glowing triangle motif). The `Icons.movie_edit` icon is **strictly forbidden** in primary branding contexts. All buttons (e.g., Import Video) that reference media should strive to use motif-adjacent icons like `Icons.play_arrow_rounded` or `Icons.play_circle_fill_rounded` rather than generic structural icons like `video_library`.

## Android Icon Config

Defined in `pubspec.yaml` under `flutter_launcher_icons`:

- `image_path`: `assets/branding/logo_mark_master_1024.png`
- `adaptive_icon_foreground`: `assets/branding/ic_launcher_foreground.png`
- `adaptive_icon_background`: `#16213E`
- `adaptive_icon_monochrome`: `assets/branding/ic_launcher_foreground.png`

Generated outputs in `android/app/src/main/res/`:

- `mipmap-*/ic_launcher.png` — legacy raster icons
- `drawable-*/ic_launcher_foreground.png` — adaptive foreground
- `drawable-*/ic_launcher_monochrome.png` — monochrome

## Cleanup Log

| Date | Action |
|------|--------|
| 2026-03-10 (S005D) | Removed legacy `assets/branding/logo_mark.png` (unreferenced in runtime code). Unified home screen to use canonical master. Fixed version badge text. |
| 2026-03-10 (S005E) | Regenerated pristine `logo_mark_master_1024.png` and `ic_launcher_foreground.png` via script to eliminate checkerboard artifacts. Regenerated launcher icons. Polished splash animation to 1.5s. |
