# CycleZen-Mobile theme implementation

GitHub write access was blocked by the integration with:

`403 Resource not accessible by integration`

This package contains the completed Flutter implementation files.

## Files to replace

Copy these files into the same paths in the `CycleZen-Mobile` repo:

- `lib/core/theme/app_theme.dart`
- `lib/main.dart`

## What changed

- Applied the same web app CycleZen palette:
  - Deep Teal `#0F4D4D`
  - Route Teal `#1D7F78`
  - Mint `#58B3A6`
  - Sky `#CFE8F6`
  - Sunrise Gold `#F5C36A`
  - Cloud White `#F5FBFA`
- Updated Material 3 light/dark theme.
- Improved rounded cards, inputs, chips, buttons, snackbars and navigation styling.
- Added reusable brand gradients and soft brand shadow.
- Updated app splash screen with premium CycleZen logo-style mark and brand tagline.
- Kept existing project structure and dependencies unchanged.

## Commands

After copying the files, run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
git add lib/core/theme/app_theme.dart lib/main.dart THEME_IMPLEMENTATION_NOTES.md
git commit -m "style: apply CycleZen mobile brand theme"
git push origin main
```

## Optional next UI files to brand

The repo already contains branded landing and home pages, but after applying this theme, you can further polish:

- `lib/features/landing/pages/landing_page.dart`
- `lib/features/home/pages/home_page.dart`
- `lib/core/router/app_router.dart`

Use `AppTheme.brandGradient`, `AppTheme.sunriseGradient`, `AppTheme.primaryDark`, `AppTheme.secondaryTeal`, `AppTheme.greenAccent`, and `AppTheme.goldRing` instead of hard-coded older colors.
