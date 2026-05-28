# F-01: Flutter App Shell Implementation Plan

## Overview

Replace the Hello World scaffold in `lib/main.dart` with a real Flutter app shell that every subsequent slice hangs off. The shell initializes `supabase_flutter` from compile-time `--dart-define` env vars, establishes a Riverpod state-management baseline, ships a go_router-based auth-aware router with placeholder destinations, applies Material 3 light + dark theming following the OS, scaffolds i18n with `pl` + `en` ARB files (device-locale only in F-01; the override surface ships with S-09), and commits a feature-first `lib/` directory layout. A two-test baseline locks in the auth-redirect contract S-01 will plug into.

## Current State Analysis

- `lib/main.dart` is the 20-line generated Hello World. There is no `test/` directory.
- `pubspec.yaml` declares `supabase_flutter ^2.12.4` but nothing imports it.
- `pubspec.yaml` does not declare `flutter_riverpod`, `go_router`, `flutter_localizations`, or `intl`.
- There is no `l10n.yaml`, no ARB files, no `analysis_options.yaml` change beyond the stock `flutter_lints` package.
- `env.json.example` is referenced in `SETUP.md` §5 and `.gitignore` line 68 already ignores `env.json`, but `env.json.example` does not exist on disk yet.
- The Supabase schema and three RPC functions (`list_tasks`, `add_task`, `complete_task`) already exist in `landing/supabase/migrations/20260522170000_initial_schema.sql` and are out of scope for F-01.

## Desired End State

`flutter run -d linux --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…` boots into a themed, localized placeholder `/sign-in` page. When `--dart-define` is missing, the app boots into a clear full-screen error widget naming the missing var and the SETUP.md fix. When the Riverpod auth-state provider emits a `Session`, the router redirects to a placeholder `/home` page. `flutter test` runs two passing widget tests proving the redirect contract. `flutter analyze` is clean. The same build runs on Android with the same env-var contract.

### Key Discoveries

- Env vars contract is settled by SETUP.md §5: `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` via `--dart-define`. `String.fromEnvironment` reads them. `flutter_dotenv` is parked unless we revisit (CLAUDE.md `## Conventions that aren't in landing/CLAUDE.md`).
- i18n policy is settled by PRD Open Question #4 resolution (2026-05-26): `pl` + `en`, device-locale on first launch with a settings override later. F-01 ships device-locale only - the picker lands with S-09 per the roadmap F-01 entry and the answers in this plan's questioning round.
- Tech-stack contract for Flutter is settled by `context/foundation/tech-stack.md` "Component boundaries (added 2026-05-23)": Flutter talks to Supabase directly via `supabase_flutter` (auth + realtime + PostgREST RPC). No MCP function hop on the client side.
- The Flutter scaffold under `linux/` and `android/` is already configured by the bootstrap; F-01 does not touch native code.

## What We're NOT Doing

- Real sign-in / sign-up / sign-out UI - lives in S-01.
- Task CRUD UI of any shape - lives in S-02 (add) and S-06 (list/edit/delete).
- Focus timer, break presentation, randomization - live in S-03.
- Realtime `tasks` subscription - lives in S-08.
- Account settings UI, locale override picker, credential rotation - live in S-09.
- Android `USE_FULL_SCREEN_INTENT` permission and platform channel - sub-task of S-03.
- Creating an actual `env.json` (only `env.json.example`); `env.json` stays gitignored and the developer fills it locally.
- Dart code-gen from the Postgres schema (`supabase_codegen` is parked per SETUP.md "Optional: generate Dart types").
- A `lib/features/<feature>/{data,domain}/` directory tree under placeholder features - only `presentation/` is pre-created. `data/` and `domain/` land when S-01 / S-02 add real code that needs them.

## Implementation Approach

Three phases, each delivering an independently verifiable milestone:

1. **Project structure & dependencies** - pubspec deps, `lib/` directory layout, `env.json.example`, analysis_options tightening, `l10n.yaml` and empty ARB files. Outcome: `flutter pub get` + `flutter analyze` are clean; project compiles with the chosen deps; no runtime behavior yet.
2. **App initialization & visual baseline** - `Supabase.initialize` with full-screen error widget on missing env; Material 3 light + dark themes; `MaterialApp.router` wired with `localizationsDelegates` and `supportedLocales`; two seed localized strings to prove the i18n loop closed end-to-end. Outcome: app boots on Linux and Android into a themed, localized empty-state page.
3. **Auth-aware router & tests** - Riverpod `StreamProvider` over `supabase.auth.onAuthStateChange`; go_router with `/sign-in` and `/home` placeholder destinations and a `redirect` callback driven by the current session; widget test + redirect-logic test. Outcome: redirect behavior is verified by tests; the contract S-01 plugs into is locked.

## Critical Implementation Details

- **go_router + Supabase auth-state wiring is the one non-obvious piece.** `go_router`'s `redirect` callback is sync - it must read `Supabase.instance.client.auth.currentSession` (sync, available immediately after `Supabase.initialize`). To re-evaluate redirects when the session changes, pass a `refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange)`. Do NOT try to `await` the auth stream inside `redirect`; do NOT subscribe to the stream in a widget and call `context.go()` (race conditions vs first-frame redirect).
- **`ProviderScope` wraps `MainApp`, but `Supabase.initialize` runs BEFORE `runApp`.** The order in `main()` is: `WidgetsFlutterBinding.ensureInitialized()` → `Supabase.initialize(...)` (or `ErrorApp` on failure) → `runApp(ProviderScope(child: MainApp()))`. Initializing Supabase inside a Riverpod provider would force every consumer to handle the loading state, defeating the point of sync `currentSession` reads.
- **`l10n.yaml` should set `synthetic-package: false`.** The modern Flutter recommendation (Flutter 3.27+) emits real generated files at `lib/l10n/app_localizations.dart` instead of a synthetic package import. This makes the generated code reviewable, debuggable, and importable as `import 'package:taskodoro/l10n/app_localizations.dart';`.

## Phase 1: Project structure & dependencies

### Overview

Add the dependency baseline, create the `lib/` directory skeleton, scaffold i18n config files, write `env.json.example`, and tighten `analysis_options.yaml`. Nothing runs yet; this phase is purely about getting the project to compile with the conventions in place.

### Changes Required

#### 1. pubspec.yaml dependency additions

**File**: `pubspec.yaml`

**Intent**: Add the three new runtime dependencies (Riverpod, go_router, intl) plus `flutter_localizations` from the Flutter SDK, and enable the Flutter `generate: true` flag so the i18n tooling produces `AppLocalizations` from the ARB files.

**Contract**:
- `dependencies` adds `flutter_riverpod`, `go_router`, `intl`, and `flutter_localizations` (SDK dependency).
- `flutter:` section adds `generate: true` alongside the existing `uses-material-design: true`.
- Version pins follow the "latest stable on pub.dev as of plan date" rule; the implementer resolves exact constraints via `flutter pub add`.

#### 2. l10n.yaml at the repo root

**File**: `l10n.yaml`

**Intent**: Configure the Flutter i18n generator to read ARB files from `lib/l10n/`, emit real (not synthetic) Dart files into `lib/l10n/`, and treat `app_en.arb` as the template (the file whose keys define the canonical set).

**Contract**:
- `arb-dir: lib/l10n`
- `template-arb-file: app_en.arb`
- `output-localization-file: app_localizations.dart`
- `synthetic-package: false`

#### 3. ARB files: `app_en.arb` + `app_pl.arb`

**File**: `lib/l10n/app_en.arb` and `lib/l10n/app_pl.arb`

**Intent**: Create the two ARB files with one or two seed keys each so Phase 2 has something to render and the i18n round-trip can be verified end-to-end. Keys: at minimum `appTitle` ("Taskodoro" in both locales) and `signInPlaceholder` (the message shown on the placeholder sign-in page). Keep it tiny - real feature strings land with each slice.

**Contract**:
- `app_en.arb` is the template; `@@locale: "en"` plus `appTitle` and `signInPlaceholder` keys.
- `app_pl.arb` is the translation; `@@locale: "pl"` plus matching keys with Polish values.

#### 4. `env.json.example` at the repo root

**File**: `env.json.example`

**Intent**: Create the placeholder file SETUP.md §5 references and the `.vscode/launch.json` `--dart-define-from-file=env.json` line expects. The example shows the two required keys with dummy values and a comment line that points to SETUP.md §1 for where to get real values.

**Contract**:
- Plain JSON object with two string fields: `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
- Dummy values: `https://<your-project-ref>.supabase.co` and `<your-publishable-key>`.

#### 5. `lib/` directory skeleton

**File**: `lib/` (new directories + placeholder files)

**Intent**: Commit the feature-first layout chosen for this project. Each directory under `lib/` exists with at minimum one file (placeholder pages, scaffolds, or a `.gitkeep` if no real file applies yet). This anchors the convention before slices start landing.

**Contract** - directories and files to create (content scaffolded as minimum-viable Dart):

```
lib/
  app/
    app.dart              # MainApp widget - built out in Phase 2
    error_app.dart        # ErrorApp widget - built out in Phase 2
    router.dart           # go_router config + route path constants - built out in Phase 3
  core/
    supabase/
      supabase_init.dart  # Supabase.initialize wrapper + env reading - built out in Phase 2
      auth_providers.dart # Riverpod providers over supabase.auth - built out in Phase 3
    theme/
      app_theme.dart      # light + dark ColorSchemes - built out in Phase 2
  features/
    auth/
      presentation/
        sign_in_page.dart # placeholder for S-01
    home/
      presentation/
        home_page.dart    # placeholder destination after sign-in
  l10n/
    app_en.arb
    app_pl.arb
  main.dart               # rewritten in Phase 2
```

For Phase 1, files referenced as "built out later" contain only their import-able shell (an empty const class, top-level function stub, or a `// Phase N: …` marker comment). Phase 1's job is just to commit the layout - no logic.

#### 6. analysis_options.yaml tightening

**File**: `analysis_options.yaml`

**Intent**: Keep the bootstrap-generated `flutter_lints` include but turn `prefer_relative_imports` and `prefer_single_quotes` on (project convention candidates), and exclude generated i18n output from analysis. This keeps `flutter analyze` from flagging files the build_runner-equivalent step produces.

**Contract**:
- `include: package:flutter_lints/flutter.yaml` (preserved).
- `analyzer.exclude:` adds `lib/l10n/app_localizations*.dart` and `lib/l10n/app_localizations_*.dart`.
- `linter.rules:` adds `prefer_relative_imports: true` and `prefer_single_quotes: true`.

#### 7. Empty `test/` directory placeholder

**File**: `test/.gitkeep`

**Intent**: Stake the `test/` directory now so Phase 3's tests land in an expected location. A `.gitkeep` is enough.

**Contract**: Empty file at `test/.gitkeep`.

### Success Criteria

#### Automated Verification

- `flutter pub get` succeeds with the new deps.
- `flutter pub run flutter_localizations:generate_synthetic_package` is NOT required; the generator runs as part of `flutter pub get` because `flutter.generate: true` is enabled.
- `lib/l10n/app_localizations.dart` is generated and present under `lib/l10n/` after `flutter pub get`.
- `flutter analyze` exits 0 with no warnings or info-level lints (after the analysis_options exclusions).
- `flutter test` succeeds with zero tests collected (no tests yet - exit code 0 with a "no tests found" message is acceptable for this phase).

#### Manual Verification

- `lib/` directory matches the layout in §5 exactly (every named file exists, every directory is present, no extra files).
- `env.json.example` exists at the repo root and is NOT in `.gitignore` (only `env.json` is - verify the existing line).
- `pubspec.yaml`'s `flutter:` section shows `generate: true`.
- Both ARB files render valid JSON when opened (no `@@locale` typos, matching key sets).

**Implementation Note**: After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to Phase 2.

---

## Phase 2: App initialization & visual baseline

### Overview

Turn the empty scaffold into a bootable app. Wire `Supabase.initialize` with a clear-error path, define Material 3 light + dark themes, configure `MaterialApp.router` with i18n delegates pointed at the generated `AppLocalizations`, and render the placeholder pages using the seed ARB strings. After this phase, `flutter run -d linux` boots into a real-looking themed and localized empty-state screen.

### Changes Required

#### 1. `lib/core/supabase/supabase_init.dart`

**File**: `lib/core/supabase/supabase_init.dart`

**Intent**: Centralize env-var reading and `Supabase.initialize`. Expose a function that reads both env vars via `String.fromEnvironment`, throws a typed exception with an actionable message if either is empty, and otherwise awaits `Supabase.initialize`. Surface a top-level `supabaseUrl` / `supabasePublishableKey` constants for debug-tooling reuse.

**Contract**:
- Public function: `Future<void> initializeSupabase()`. No parameters.
- Throws a custom `SupabaseEnvException` (defined in this file) when either env var is empty - the message names which var is missing and quotes the SETUP.md §5 `--dart-define` line.
- Inside, calls `Supabase.initialize(url: supabaseUrl, anonKey: supabasePublishableKey)`.

#### 2. `lib/app/error_app.dart`

**File**: `lib/app/error_app.dart`

**Intent**: A standalone `MaterialApp` that renders a centered full-screen error widget for env-var failures during boot. Independent of the main app's Riverpod scope or router - must run before either is constructed.

**Contract**:
- Stateless widget `ErrorApp` taking a single `message` string in its constructor.
- Builds a `MaterialApp` (not `MaterialApp.router`) with a `Scaffold` whose body is a centered column: a `SelectableText` of the message, a `SelectableText` of the literal example `--dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<key>`, and a hint pointing at `SETUP.md §5`.
- Uses Material 3 default theme - no dependency on `core/theme/`.

#### 3. `lib/core/theme/app_theme.dart`

**File**: `lib/core/theme/app_theme.dart`

**Intent**: Define the project's `ThemeData` for light and dark Material 3, both derived from a single seed color so the brand stays consistent. Both themes use `useMaterial3: true`.

**Contract**:
- Two `static final ThemeData` getters on an `AppTheme` class: `light` and `dark`.
- Each is built via `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: <seed>, brightness: <brightness>))`.
- Seed color: pick one warm/red shade evocative of the Pomodoro tomato (the implementer picks the exact `Color(0xff…)` value; it can be tuned in a later slice when real visual design lands).

#### 4. `lib/app/app.dart`

**File**: `lib/app/app.dart`

**Intent**: The root `MainApp` widget - a `MaterialApp.router` that wires the router from `lib/app/router.dart`, both themes from `AppTheme`, `themeMode: ThemeMode.system`, the generated localizations delegate, supported locales (`en` + `pl`), and `onGenerateTitle` reading from `AppLocalizations.of(context)!.appTitle`.

**Contract**:
- Stateless widget `MainApp` taking the `GoRouter` instance as a constructor parameter.
- `MaterialApp.router(routerConfig: …, theme: AppTheme.light, darkTheme: AppTheme.dark, themeMode: ThemeMode.system, localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle)`.

#### 5. `lib/main.dart` rewrite

**File**: `lib/main.dart`

**Intent**: Wire the app boot sequence: ensure binding, run `initializeSupabase`, on success run the app inside a `ProviderScope`, on `SupabaseEnvException` run `ErrorApp` with the exception message.

**Contract**:
- Top-level `void main() async` body:
  1. `WidgetsFlutterBinding.ensureInitialized()`
  2. `try { await initializeSupabase(); } on SupabaseEnvException catch (e) { runApp(ErrorApp(message: e.message)); return; }`
  3. Build the `GoRouter` (the Phase 3 deliverable; for the Phase 2 milestone, a temporary one-route router pointing at `SignInPage` is fine - replaced when Phase 3 lands).
  4. `runApp(ProviderScope(child: MainApp(router: …)));`

#### 6. Placeholder page bodies render localized strings

**File**: `lib/features/auth/presentation/sign_in_page.dart` and `lib/features/home/presentation/home_page.dart`

**Intent**: Each page renders a `Scaffold` whose body is a centered localized string (`AppLocalizations.of(context)!.signInPlaceholder` for the sign-in page; a hardcoded "Home" or a similar trivial string for the home page is acceptable - only one ARB key is required to prove the loop closed).

**Contract**:
- `SignInPage` and `HomePage` are stateless widgets.
- Each builds a `Scaffold(appBar: AppBar(title: Text(<localized appTitle>)), body: Center(child: Text(<localized message>)))`.

### Success Criteria

#### Automated Verification

- `flutter analyze` exits 0.
- `flutter build linux --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=dummy` succeeds (dummy values are fine because Supabase.initialize doesn't network-validate until the first call).
- `flutter test` still exits 0 (zero tests, or the one-liner smoke test if added early - Phase 3 owns the test set).

#### Manual Verification

- `flutter run -d linux --dart-define-from-file=env.json` (after creating a real `env.json` from the example) boots into the placeholder sign-in page with the localized title in the app bar.
- Switching the OS language between English and Polish and restarting the app changes the visible string accordingly.
- Switching the OS theme between light and dark and reloading the app changes the visible colors accordingly.
- Removing one `--dart-define` and restarting shows the `ErrorApp` with a clear message naming the missing var, the `--dart-define` example, and the SETUP.md §5 reference.
- The same `flutter run -d <android-device>` invocation produces a comparable result on Android (modulo whatever locale/theme the device is on).

**Implementation Note**: After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to Phase 3. Manual gates here include cross-platform boot (Linux + Android), so plan to plug in or boot an Android device.

---

## Phase 3: Auth-aware router & tests

### Overview

Replace the temporary Phase 2 router with the real go_router config: a session-driven redirect, a Riverpod `StreamProvider` over `supabase.auth.onAuthStateChange`, and `GoRouterRefreshStream` re-evaluation on auth-state events. Add two widget tests - one smoke test for cold-boot routing and one for redirect on session emission - to lock in the contract S-01 will plug auth screens into.

### Changes Required

#### 1. `lib/core/supabase/auth_providers.dart`

**File**: `lib/core/supabase/auth_providers.dart`

**Intent**: Riverpod providers that expose Supabase's auth state to the rest of the app. Three providers: the raw client (`Provider<SupabaseClient>`), the auth state stream (`StreamProvider<AuthState>` over `supabase.auth.onAuthStateChange`), and a convenience derived provider for the current `Session?` that reads from `currentSession` for the initial value and updates from the stream.

**Contract**:
- `supabaseClientProvider` - `Provider<SupabaseClient>` returning `Supabase.instance.client`.
- `authStateChangesProvider` - `StreamProvider<AuthState>` reading `supabase.auth.onAuthStateChange`.
- `currentSessionProvider` - `Provider<Session?>` returning the latest known session: initial value from `currentSession`, replaced by the stream's `data.session` on each event.

#### 2. `lib/app/router.dart`

**File**: `lib/app/router.dart`

**Intent**: Build the real `GoRouter`. Two named routes (`/sign-in` and `/home`), a `redirect` callback that consults `Supabase.instance.client.auth.currentSession`, and `refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange)` so redirects re-run when the session changes.

**Contract**:
- Constants for the two route paths: `routeSignIn = '/sign-in'`, `routeHome = '/home'`.
- A factory `GoRouter buildRouter()` returning the configured router.
- The router's `redirect` callback:
  - Returns `routeSignIn` when `currentSession` is null and the target is not already `routeSignIn`.
  - Returns `routeHome` when `currentSession` is non-null and the target is `routeSignIn`.
  - Otherwise returns `null` (no redirect).
- The router's `refreshListenable` is `GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange)`.
- `initialLocation` is `routeSignIn` - the redirect handles the signed-in case from there.

**Contract - non-obvious code**: `GoRouterRefreshStream` is not exported from `go_router` itself in recent versions; the canonical implementation is to write a small `ChangeNotifier` that subscribes to the stream and calls `notifyListeners()` on each event. The implementer should write this `GoRouterRefreshStream` helper inline in `router.dart` rather than depending on an extra package.

#### 3. `lib/main.dart` updated to use the real router

**File**: `lib/main.dart`

**Intent**: Replace the Phase 2 temporary one-route router with `buildRouter()` from `lib/app/router.dart`.

**Contract**: The `main()` body's router construction becomes `final router = buildRouter();`, passed to `MainApp(router: router)` as before.

#### 4. Widget test: cold boot lands on sign-in when signed out

**File**: `test/app/router_test.dart`

**Intent**: With no Supabase session present, pumping `MainApp` should land on the `SignInPage`. The test mocks `currentSessionProvider` to override the Supabase-backed reads.

**Contract**:
- Test setup overrides `currentSessionProvider` with `Provider<Session?>((ref) => null)` via a `ProviderContainer.override`.
- Pumps `MainApp(router: buildRouter())` inside a `ProviderScope(overrides: …)`.
- Asserts `find.byType(SignInPage)` finds exactly one widget.
- Does NOT touch real `Supabase.instance` - the test must avoid initializing Supabase by mocking the provider that reads it.

#### 5. Widget test: redirect to home when session emits

**File**: `test/app/router_test.dart` (second test in the same file)

**Intent**: When the auth-state provider emits a session, the router should redirect away from `/sign-in` to `/home`. The test drives the session through a controllable provider override.

**Contract**:
- Test uses a `StateProvider<Session?>` override that starts null and is set to a mock `Session` mid-test.
- Pumps the app, asserts `SignInPage` is shown, mutates the state-provider value to a non-null `Session`, pumps again, asserts `HomePage` is shown.
- Mock `Session` can be a minimal hand-constructed instance (`Session` is a plain Dart class in `supabase_flutter`) - only the non-null-ness matters for the redirect; field values can be empty strings.

### Success Criteria

#### Automated Verification

- `flutter analyze` exits 0.
- `flutter test test/app/router_test.dart` passes both tests.
- `flutter test` (all tests) exits 0.

#### Manual Verification

- `flutter run -d linux --dart-define-from-file=env.json` still boots into `SignInPage` on a fresh session-less launch.
- Forcing a signed-in state for ad-hoc verification (e.g., temporarily call `Supabase.instance.client.auth.signInWithPassword` from a debug button - code thrown away after testing) causes the app to navigate to `HomePage` within one frame without manual navigation.
- `flutter run -d <android-device>` produces the same behavior on Android.

**Implementation Note**: After this phase, F-01 is feature-complete. Final cross-phase sanity: re-run `flutter analyze` and `flutter test` from a clean state, and verify the change folder's `change.md` status is updated to `implemented` (or `completed`) for the `/10x-archive` step.

---

## Testing Strategy

### Unit / widget tests in this change

- **`test/app/router_test.dart`** - two tests as detailed in Phase 3: cold-boot routing and redirect-on-session.

### Integration tests

- None in F-01. The first integration-level test ("signed-in `Session` is restored on cold start") is scoped to S-01 per the roadmap risk callout - F-01 lays the testable hooks, S-01 adds the integration scenario.

### Manual testing steps

After all three phases land, run through the cross-platform smoke list once:

1. `flutter run -d linux --dart-define-from-file=env.json` boots into `SignInPage`. App-bar title is localized to OS language.
2. Switch OS theme (Linux: GNOME Settings → Appearance) to dark; restart the app. Colors invert appropriately.
3. Switch OS language (Polish ⇄ English); restart the app. Title and placeholder strings flip.
4. Remove one `--dart-define`; restart. `ErrorApp` appears with the missing-var message.
5. `flutter run -d <android-device>` produces equivalent behavior on Android.

## Performance Considerations

No performance work in F-01. `Supabase.initialize` is a one-shot startup cost (well under the PRD's 500 ms NFR). The router redirect is pure local state - no network. Tests run in seconds.

## Migration Notes

No data migration. The Supabase schema already exists in `landing/supabase/migrations/20260522170000_initial_schema.sql` and is consumed by the future slices (S-02 onward), not by F-01.

## References

- Roadmap entry: `context/foundation/roadmap.md` F-01 section (lines 69-83).
- PRD i18n resolution: `context/foundation/prd.md` Open Question #4 (line 193).
- SETUP env-var contract: `SETUP.md` §5 (lines 92-129).
- Tech-stack Flutter↔Supabase contract: `context/foundation/tech-stack.md` "Component boundaries" section.
- Existing Supabase schema (consumed by S-02+, not F-01): `landing/supabase/migrations/20260522170000_initial_schema.sql`.
- Project-level Flutter conventions: `CLAUDE.md` `## Flutter commands` + `## Conventions that aren't in landing/CLAUDE.md`.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` - <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Project structure & dependencies

#### Automated

- [x] 1.1 `flutter pub get` succeeds with the new deps
- [x] 1.2 `lib/l10n/app_localizations.dart` is generated and present after `flutter pub get`
- [x] 1.3 `flutter analyze` exits 0 with no warnings or info-level lints
- [x] 1.4 `flutter test` exits 0

#### Manual

- [x] 1.5 `lib/` directory matches the planned layout exactly
- [x] 1.6 `env.json.example` exists at repo root and is not in `.gitignore`
- [x] 1.7 `pubspec.yaml` shows `flutter.generate: true`
- [x] 1.8 Both ARB files render valid JSON with matching key sets

### Phase 2: App initialization & visual baseline

#### Automated

- [ ] 2.1 `flutter analyze` exits 0
- [ ] 2.2 `flutter build linux --dart-define=…` succeeds with dummy env values
- [ ] 2.3 `flutter test` exits 0

#### Manual

- [ ] 2.4 `flutter run -d linux --dart-define-from-file=env.json` boots into the placeholder sign-in page with localized title
- [ ] 2.5 OS language switch (en ⇄ pl) changes visible strings on next launch
- [ ] 2.6 OS theme switch (light ⇄ dark) changes visible colors on next launch
- [ ] 2.7 Removing a `--dart-define` triggers `ErrorApp` with actionable message
- [ ] 2.8 `flutter run -d <android-device>` produces equivalent result on Android

### Phase 3: Auth-aware router & tests

#### Automated

- [ ] 3.1 `flutter analyze` exits 0
- [ ] 3.2 `flutter test test/app/router_test.dart` passes both tests
- [ ] 3.3 `flutter test` (full suite) exits 0

#### Manual

- [ ] 3.4 `flutter run -d linux` boots into `SignInPage` on a session-less launch
- [ ] 3.5 Ad-hoc forced sign-in causes redirect to `HomePage` within one frame
- [ ] 3.6 `flutter run -d <android-device>` produces equivalent behavior on Android
