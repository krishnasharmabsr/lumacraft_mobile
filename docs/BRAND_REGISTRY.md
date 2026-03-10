# Brand Registry

## Canonical Master Asset

| Asset | Path | Purpose |
|-------|------|---------|
| Master Logo | `assets/branding/logo_mark_master_1024.png` | Single source of truth for all runtime UI and icon generation |
| Icon Foreground | `assets/branding/ic_launcher_foreground.png` | Android adaptive icon foreground (derived from master) |

## Runtime UI References

| Screen | Widget | Asset Path |
|--------|--------|------------|
| Splash | `Image.asset` in `SplashScreen` | `assets/branding/logo_mark_master_1024.png` |
| Home | `Image.asset` in `HomeScreen` | `assets/branding/logo_mark_master_1024.png` |
| Export watermark | `rootBundle.load` in `FFmpegProcessor` | `assets/branding/logo_mark_master_1024.png` |

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
