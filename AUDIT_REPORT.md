# CycleZen Flutter App — UX Audit Report

**Audit date**: 2026-05-24  
**Files audited**: 40 Dart files across lib/  
**Scope**: Accessibility, Animation, Performance, Responsive Design, Platform Conventions, Error UX, Edge Cases

---

## 1. Accessibility — 🔴 CRITICAL GAPS

### 1.1 Missing Semantics & Accessibility Labels (Severity: HIGH)

Only **one** `Semantics` widget exists in the entire app (landing_page.dart line 457, on the swipe control). Everything else is invisible to screen readers.

- **All IconButtons lack `semanticLabel`**: auth_page.dart, home_page.dart, dashboard_page.dart, saved_routes_page.dart, route_detail_page.dart, unified_ride_page.dart.
  - Example: `IconButton(icon: const Icon(Icons.bookmark, ...), tooltip: 'Saved Routes')` — `tooltip` is **not** the same as `semanticLabel`. Screen readers won't pick it up reliably.
- **Decorative images lack `excludeFromSemantics: true`**: The logo mark (`Image.asset(AppAssets.logoMark)`) appears in multiple places (splash, appbar, landing, auth page). Screen readers will try to describe them, producing noise.
- **No `Semantics` on any StatChip, MetricTile, or summary data**: Ride stats, weather data, achievement info are invisible to TalkBack/VoiceOver.

**Fix**: Add `semanticLabel` to every `IconButton`. Wrap non-interactive icons in `ExcludeSemantics`. Add `Semantics` wrappers on stat cards and metric displays.

### 1.2 Touch Target Sizes Below Minimum (Severity: MEDIUM)

WCAG / Material Design require minimum **48×48dp** touch targets.

- `saved_routes_page.dart:150-161`: Edit/Delete `IconButton`s use `visualDensity: VisualDensity.compact` — touch targets may fall below 48×48.
- `route_card.dart:96-104`: `_ActionButton`s use `padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)` with `icon(18)` + small label — tap area may be too small.
- `route_filter_chips.dart:88-89`: Filter chips use `padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7)` — below minimum.
- `unified_ride_page.dart:301-305`: Close button in ride view uses `padding: EdgeInsets.all(8)` with `icon(22)` — the circle is ~38dp, significantly below minimum.

**Fix**: Increase padding on all interactive elements to ensure 48×48dp minimum. Use `constraints: BoxConstraints(minWidth: 48, minHeight: 48)` on icon buttons.

### 1.3 Contrast Ratio Issues (Severity: LOW-MEDIUM)

- `textOnDarkMuted` (#B8D8D4) on `surfaceDark` (#082A2B): Contrast ratio ~5.7:1 — passes AA for large text but fails for body text <18px.
- `textHint` (#6B8A8C) on light backgrounds: Ratio ~3.7:1 — fails AA for all text sizes.
- `_MetricTile` uses `Colors.white38` on dark panel background — extremely low contrast; metric labels are barely visible in bright conditions.

**Fix**: Lighten `textOnDarkMuted` to at least #C6E5E1. Use `Colors.white54` instead of `white38` for metric labels with an override in light mode.

---

## 2. Animation — 🟡 DECENT BUT INCOMPLETE

### 2.1 Strengths

- **Landing page** (`landing_page.dart`): Excellent staggered entrance animations (`_Entrance` widget), ambient floating logo, cloud/bird `_SkyPainter` with continuous animation. The swipe-to-start control is polished.
- **Route card reveals** (`home_page.dart:391-412`): `TweenAnimationBuilder` with staggered delays creates a satisfying cascade effect.
- **Saved routes** (`saved_routes_page.dart:112-126`): Same staggered reveal pattern.
- **Haptic feedback**: Well-used — `lightImpact`, `mediumImpact`, `heavyImpact`, `selectionClick` throughout the home page and ride controls.
- **Page transitions** (`app_router.dart:17-44`): Custom `_SlideTransitionPage` with 280ms slide + fade using `easeOutCubic`.

### 2.2 Gaps (Severity: MEDIUM)

- **No Hero animations anywhere**: Route cards → route detail page, route card → ride page — no shared element transitions. A `Hero` widget on the route name/icon between home → detail → ride would dramatically improve perceived continuity.
- **No explicit animation for ride metrics**: When the ride page switches metric pages, the stats change abruptly. A cross-fade or slide would improve the bike-computer feel.
- **Map transitions are jarring**: When `_fitCameraToRoutes()` is called, the camera snap-zooms. `CameraUpdate.newLatLngBounds` with padding and animation would be smoother than the current `Future.delayed` + `fitBounds` approach.
- **No animation on ride panel expand**: The bottom panel on the ride page switches from idle → active without transition. An `AnimatedSwitcher` or `AnimatedSize` would help.

**Fix recommendations**:
1. Add `Hero` widgets on route card icons/names.
2. Wrap ride metric pages in `AnimatedSwitcher`.
3. Replace `_fitCameraToRoutes` with `animateCamera(CameraUpdate.newLatLngBounds(...))`.
4. Use `AnimatedCrossFade` for ride panel idle ↔ active states.

---

## 3. Performance — 🟡 MODERATE CONCERNS

### 3.1 Rebuild Scope (Severity: HIGH)

**Home page `_HomePageState`** is the biggest offender. The entire widget tree (GoogleMap + all controls + all route cards) lives under a single `setState` cycle:

- `_rebuildOverlays()` (`home_page.dart:153-179`) is called from `_onMapTap`, `_onModeChanged`, `_onClearWaypoints`, `_onRouteTap`, `_generateAIRoutes`, and `_generateManualRoute`. Every call rebuilds the entire scaffold.
- The `GoogleMap` widget is inside the main `build()` method — it **reconstructs every time** any state changes, even though only markers/polylines changed.

```dart
// home_page.dart:337-350 — GoogleMap rebuilt on every setState
GoogleMap(
  initialCameraPosition: const CameraPosition(...),
  markers: _markers,
  polylines: _polylines,
  onMapCreated: (c) => _mapController = c,
  ...
)
```

The GoogleMap widget itself is heavyweight and should be extracted into a widget that rebuilds less often.

**Fix**: Extract the `GoogleMap` into a separate `StatefulWidget` that only rebuilds when `_markers` or `_polylines` change. Use `const` constructors where possible.

### 3.2 Missing RepaintBoundary (Severity: MEDIUM)

**Zero** `RepaintBoundary` widgets in the entire app.

- The GoogleMap is the primary candidate — wrapping it in `RepaintBoundary` prevents its repaint from cascading to parent widgets during camera pan.
- The continuously-animated `_SkyPainter` on the landing page should be isolated.
- The `CircularProgressIndicator` on the splash page animates indefinitely without isolation.

### 3.3 Const Constructor Opportunities (Severity: LOW)

Many statically-declared widgets lack `const`:

- `route_card.dart:46-49`: `Icon(isSelected ? Icons.route : Icons.route_outlined, ...)` — the ternary prevents `const` usage.
- `route_card.dart:121-125`: `_StatChip` uses `Theme.of(context)` in build — should receive theme as a parameter for const construction.
- Multiple `Text` widgets with `Theme.of(context).textTheme...` patterns prevent const construction at the leaf level.

**Fix**: Pass `TextStyle` objects down from parents where possible. Use const on all static container/wrapper widgets.

### 3.4 Stream Subscription Safety (Severity: LOW — already good)

All stream subscriptions in `unified_ride_page.dart` check `if (mounted)` before `setState`. This is correct.

### 3.5 Theme Caching (Severity: LOW — already good)

`AppTheme.lightTheme` / `AppTheme.darkTheme` are cached via `_cachedLight` / `_cachedDark` static fields. Good.

---

## 4. Responsive Design — 🔴 TABLETS NOT SUPPORTED

### 4.1 Tablet/Large Screen Layout (Severity: HIGH)

- **Home page uses fixed `flex: 3` / `flex: 4` split** (`home_page.dart:334-357`): On a tablet in landscape, this wastes 60% of screen height on an unnecessarily tall map, cramming controls into the remaining 40%. Should use `OrientationBuilder` or `MediaQuery.sizeOf(context).width` thresholds.
- **No adaptive layouts**: Every page is a mobile-first single-column layout with no breakpoints for 600dp+ widths.
- **Hardcoded sizes**: Logo is `104×104` (`main.dart:156-157`), which looks tiny on a 10" tablet.
- **AchievementsGrid** is the only widget with any responsive logic — it checks `constraints.maxWidth < 360`.

### 4.2 Landscape Mode (Severity: MEDIUM)

- `main.dart:25-29` enables landscape, but no page adjusts its layout for landscape.
- The landing page's scenic image `height: MediaQuery.sizeOf(context).height * 0.42` — in landscape, the image becomes extremely tall relative to screen width, pushing content off-screen.
- The ride page bottom panel uses `MediaQuery.of(context).padding.bottom` correctly for safe area, but in landscape, the panel height is still hardcoded.

### 4.3 Pixel Density (Severity: LOW)

All sizes use logical pixels (dp), which Flutter handles automatically. No hardcoded physical pixel values. The `filterQuality: FilterQuality.high` on images is appropriate.

**Fix recommendations**:
1. Add `OrientationBuilder` on home page: use side-by-side layout (map | controls) on landscape/tablet.
2. Use `LayoutBuilder` with breakpoints (600dp, 840dp, 1200dp) for adaptive column counts.
3. Scale logo sizes relative to `MediaQuery.sizeOf(context).shortestSide`.

---

## 5. Platform Conventions (Material Design 3) — 🟢 MOSTLY GOOD

### 5.1 MD3 Compliance (Severity: LOW)

- ✅ `useMaterial3: true` in both themes.
- ✅ `ColorScheme.fromSeed` used for dynamic color generation.
- ✅ Proper `AppBarTheme` with centerTitle, elevation 0.
- ✅ `SegmentedButton` used on profile page (MD3 component).
- ✅ `FilledButton` used in saved_routes_page.dart (rename/delete dialogs).
- ⚠️ Mixed button styles: Some `ElevatedButton` usage where `FilledButton` would be more MD3-appropriate (`auth_page.dart`, `route_card.dart`).

### 5.2 Back Gesture / Pop Handling (Severity: LOW)

- ✅ Home page uses `PopScope` with double-tap-to-exit pattern — good Android convention.
- ✅ Router uses `CustomTransitionPage` for native-feel slide transitions.
- ⚠️ No `BackButton` icon customization — relies on default platform behavior.

### 5.3 Scaffold Structure (Severity: MEDIUM)

- `_BrandedAppBar` (`home_page.dart:461-537`): This is a custom `PreferredSizeWidget` used as an `appBar:` parameter. It uses its own `SafeArea(bottom: false)` and a gradient `Container`. This is **not** a standard `AppBar` — it can't participate in scrolling behaviors (no `SliverAppBar` collapse), Material 3 elevation/scroll-under effects won't work, and accessibility services won't recognize it as a navigation bar.

**Fix**: Either extend `AppBar` properly or wrap in a `SliverAppBar` for scroll-aware behavior.

### 5.4 Auth Form Bug (Severity: MEDIUM)

`auth_page.dart:26` — `_formKey = GlobalKey<FormState>()` is shared between **both** sign-in and sign-up tabs (`_buildSignInTab` and `_buildSignUpTab` both use `key: _formKey`). When the user switches tabs, both forms briefly exist in the tree. The shared form key causes validation and state confusion.

**Fix**: Use separate `GlobalKey<FormState>` instances for each tab.

---

## 6. Error UX — 🟡 ADEQUATE BUT ROUGH

### 6.1 Strengths

- ✅ `_ErrorApp` fallback in `main.dart` for initialization failures — branded error screen.
- ✅ Most async operations have try-catch with SnackBar feedback.
- ✅ Auth page has detailed error dialog with monospace details.
- ✅ SavedRoutesPage has proper loading/error/empty/retry states.
- ✅ UnifiedRidePage validates empty route coordinates before proceeding.
- ✅ Location permission denials show clear SnackBars with guidance.

### 6.2 Gaps (Severity: MEDIUM)

- **Raw error messages in SnackBars**: `home_page.dart:218` shows `'Error: $e'` — users see technical error strings like `SocketException: Connection refused`. Should show a user-friendly message and log the technical details.
- **Weather API failures are silent**: `weather_service.dart:31-33` catches all errors and returns `null`. The widget shows "Weather unavailable" — no indication of why or how to retry.
- **Dashboard `_loadData` catch block is empty**: `dashboard_page.dart:48-50` — catches error, sets `_loading = false`, but **shows nothing to the user**. The page just renders with null/zero data.
- **No offline/connectivity detection**: App makes network calls (weather, Firebase, route generation) with no connectivity check. Users on poor connections get cryptic errors.
- **No retry mechanism**: When route loading fails, there's no "Retry" button — the user must restart the app or re-trigger from scratch.
- **No loading skeleton screens**: Only `AchievementsGrid` has a loading skeleton. Dashboard stats, route lists, and profile page show a bare `CircularProgressIndicator`.

**Fix**:
1. Create a `UserFacingError` helper that maps technical exceptions to human-readable messages.
2. Add connectivity awareness via the `connectivity_plus` package.
3. Add retry buttons to dashboard and route loading error states.
4. Add shimmer/skeleton loading for dashboard stats.

---

## 7. Edge Cases — 🟡 PARTIAL COVERAGE

### 7.1 Safe Area & System Bars (Severity: LOW — mostly good)

- ✅ `SafeArea` used on landing page, onboarding, branded app bar.
- ✅ Ride page correctly uses `MediaQuery.of(context).padding.bottom` for the bottom panel.
- ✅ Ride page close button offsets by `MediaQuery.of(context).padding.top + 8`.
- ⚠️ `home_page.dart:18-22`: `statusBarIconBrightness: Brightness.light` is hardcoded — won't adapt to light/dark theme switching during the session.

### 7.2 Keyboard Avoidance — 🔴 CRITICAL

**No `resizeToAvoidBottomInset` is set anywhere.** All Scaffolds use the default `true`.

The auth page (`auth_page.dart:52`) has multiple `TextField`s inside tabs with a `SingleChildScrollView`, but:
- The ScrollView's padding is `EdgeInsets.symmetric(horizontal: 24)` — no bottom padding for keyboard.
- When the keyboard opens, the form fields may be obscured.
- The sign-up form has 3 fields (name, email, password) — on smaller phones, the password field may be behind the keyboard.

**Fix**: Set explicit `resizeToAvoidBottomInset: true` on auth page Scaffold, add `MediaQuery.of(context).viewInsets.bottom` to the ScrollView padding, and consider wrapping form fields in `AutofillGroup`.

### 7.3 RTL Support — 🔴 NONE

**Zero RTL consideration**:
- No `Directionality` widgets.
- No `textDirection` properties set.
- No RTL-aware layout (all `Row` widgets assume LTR, no `textDirection: TextDirection.rtl` awareness).
- The swipe-to-start control uses `onHorizontalDragUpdate` with `details.delta.dx` — in RTL, the swipe direction would be reversed (left-to-start).

**Fix**: Add `Directionality` testing. Wrap `Row` widgets with `textDirection` awareness. Test with Arabic/Hebrew locale. Use `AxisDirection` for swipe direction if RTL-sensitive.

### 7.4 Long Text Handling (Severity: LOW — partial)

- ✅ Route card titles use `TextOverflow.ellipsis` with `maxLines: 1`.
- ✅ Navigation instructions use `maxLines: 2` with `TextOverflow.ellipsis`.
- ✅ Achievement descriptions use `maxLines: 2`.
- ⚠️ `_BrandedAppBar` tagline text uses `TextOverflow.ellipsis` at `fontSize: 10` — could truncate to nothing on very narrow screens.
- ⚠️ Ride summary stats (`_SummaryTile`) — the `value` label uses `maxLines: 2` with ellipsis, but the tight 3-column layout means even 2-line values may clip if text is long (e.g., translated locales).
- ⚠️ Dashboard `_StatCard` values have no overflow handling — long numbers like "1234.5 km" could overflow.

### 7.5 Empty/Null Data States (Severity: LOW — mostly good)

- ✅ Saved routes has distinct empty state ("No saved routes yet").
- ✅ Dashboard shows "No rides yet" card.
- ✅ Manual route panel shows "Tap the map to place waypoints".
- ✅ Achievements has an empty state.
- ⚠️ Profile page for unauthenticated users shows a single "Sign In" button — could show a more engaging prompt.
- ⚠️ Weather widget when no weather: shows a subtle "Weather unavailable" in grey — easy to miss.

---

## Summary of Findings

| Category | Severity | Count | Key Issues |
|----------|----------|-------|-----------|
| **Accessibility** | 🔴 HIGH | 3 | No Semantics/labels anywhere; touch targets < 48dp; contrast issues |
| **Animation** | 🟡 MED | 3 | No Hero animations; jarring map transitions; no ride panel transition |
| **Performance** | 🟡 MED | 3 | Entire home page rebuilds on setState; no RepaintBoundary; missing const |
| **Responsive** | 🔴 HIGH | 3 | No tablet layouts; fixed flex splits; hardcoded sizes |
| **Platform/MD3** | 🟡 LOW | 3 | Custom AppBar breaks MD3 scrolling; shared FormKey bug; button style mix |
| **Error UX** | 🟡 MED | 3 | Raw error messages; silent failures; no offline detection or retry |
| **Edge Cases** | 🟡 MED | 3 | No RTL support; no keyboard avoidance on auth; missing long-text handling |

### Top 5 Priority Fixes

1. **Add `semanticLabel`** to all interactive elements and `ExcludeSemantics` on decorative images.
2. **Fix keyboard avoidance** on the auth page — add `resizeToAvoidBottomInset` + bottom padding.
3. **Make home page responsive** — use `OrientationBuilder` for side-by-side map/controls on landscape.
4. **Extract GoogleMap widget** — stop rebuilding it on every `setState` in home page.
5. **Add user-facing error messages** — map technical exceptions to readable strings.

### Top Quick Wins

1. Add `semanticLabel` to the 10 most-used `IconButton` widgets.
2. Add `const` to all static `Container`, `Padding`, `SizedBox`, `Text` widgets.
3. Fix shared `_formKey` in auth_page.dart (split into two keys).
4. Add `RepaintBoundary` around GoogleMap.
5. Add `Hero` tags on route card → route detail transitions.
