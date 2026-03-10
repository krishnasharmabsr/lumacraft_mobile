# Android Manual QA Checklist (S002)

## Prerequisites

- Install debug or release APK on physical Samsung A13 (Android 14)

## Test Cases

### 1. Import video

- [ ] Tap "Import Video" on home screen
- [ ] Document picker (SAF) opens (no separate permission prompt needed)
- [ ] Select a video → navigates to editor screen

### 2. Preview playback

- [ ] Video plays automatically on load
- [ ] Play/Pause button toggles correctly
- [ ] Duration label shows current position / total duration

### 3. Trim range adjust

- [ ] RangeSlider adjusts start and end markers
- [ ] Start/End labels update in real-time
- [ ] Seeking to new start position on drag

### 4. Preview Trim

- [ ] Tap "Preview Trim" → player seeks to trim start and plays
- [ ] Player auto-pauses when reaching trim end

### 5. Process Trim

- [ ] Tap "Process Trim" → spinner shows
- [ ] New (shorter) video loads into player
- [ ] Snackbar confirms "Trim successful"

### 6. Export

- [ ] Export button is disabled (greyed out) before any trim
- [ ] Tap disabled Export → no action
- [ ] After successful Process Trim, Export button becomes enabled
- [ ] Tap "Export" → saves video to device gallery
- [ ] Snackbar confirms "Exported to gallery!"
- [ ] Video visible in device Photos/Gallery app

### 7. Negative cases

- [ ] Set trim start and end to same position (or range < 300ms)
- [ ] Tap "Process Trim" → shows red validation error snackbar
- [ ] Import without trimming → tap Export → shows orange "No edits to export" snackbar

## Sign-off

- **Tester:**
- **Device:**
- **Date:**
- **Result:** PASS / FAIL
