# F-01: Flutter App Shell - Plan Brief

> Full plan: `context/changes/f-01-app-shell/plan.md`

## What & Why

Replace the 20-line Hello World scaffold in `lib/main.dart` with the real Flutter app shell every later slice plugs into. The shell wires Supabase via compile-time env vars, fixes the project-wide choices (state management, routing, layout, theming, i18n) that would otherwise force rework across S-01 through S-09, and locks down the auth-redirect contract S-01 will build sign-in screens on top of.

## Starting Point

`lib/main.dart` is the bootstrap Hello World, no `test/` directory exists, and `supabase_flutter ^2.12.4` is declared in `pubspec.yaml` but unused. The Supabase backend (`tasks`/`task_completions` schema + `list_tasks`/`add_task`/`complete_task` RPCs) already exists in `landing/supabase/migrations/`. The MCP Edge Function exists in `landing/supabase/functions/mcp/`. The native scaffolds under `linux/` and `android/` are configured. SETUP.md already pins the env-var contract (`--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`).

## Desired End State

`flutter run -d linux --dart-define-from-file=env.json` boots into a themed, localized placeholder `/sign-in` page. When the Riverpod auth-state provider emits a `Session`, the router redirects to a placeholder `/home` page. Missing `--dart-define` triggers a clear full-screen error widget that names the missing var and quotes the SETUP.md fix. `flutter test` runs two widget tests that prove the redirect contract. The same build works on Android.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| State management | flutter_riverpod | Pairs cleanly with `supabase_flutter`'s auth-state stream and scales from this shell to the full app without rewrites | Plan |
| Routing library | go_router | First-party support, official auth-redirect example, plays cleanly with the landing's email-confirm deep-link handoff | Plan |
| Directory layout | Feature-first (`lib/{app,core,features}` with `presentation/` under each feature) | Each later slice (S-01 auth, S-02 add-task, S-03 timer + break) becomes a self-contained feature folder | Plan |
| Theming | Material 3 light + dark, follows system | Dark mode is cheap at theme-genesis and painful to retrofit; required for the full-screen break presentation in S-03 | Plan |
| Auth-aware router scope | Working session listener + redirect, placeholder destination pages | S-01 only writes auth screens; the plumbing already works and is testable | Plan |
| Init failure handling | Full-screen `ErrorApp` widget with actionable text | Env vars are compile-time, so failure is always a dev mistake; clear text shortcuts the SETUP.md troubleshooting loop | Plan |
| Testing baseline | One widget test + one redirect-logic test (mocked provider) | Locks in the auth-redirect contract S-01 plugs into while the code is fresh | Plan |
| Locale detection in F-01 | Device-locale only; override surface ships with S-09 | Matches the PRD resolution and avoids creating a settings route S-09 may restructure | PRD |
| i18n locales | `pl` + `en` ARB files | PRD Open Question #4 resolution (2026-05-26) | PRD |
| Env-var contract | `--dart-define=SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY`; no `flutter_dotenv` | SETUP.md §5; CLAUDE.md `## Conventions that aren't in landing/CLAUDE.md` | SETUP/CLAUDE |

## Scope

**In scope:**
- pubspec deps: `flutter_riverpod`, `go_router`, `flutter_localizations`, `intl`
- `lib/` directory layout: `app/`, `core/{supabase,theme}/`, `features/{auth,home}/presentation/`, `l10n/`
- `Supabase.initialize` from `--dart-define` env vars + `ErrorApp` on missing env
- Material 3 light + dark theme from a single seed color, `themeMode: system`
- i18n scaffolding: `l10n.yaml`, `app_en.arb`, `app_pl.arb`, two seed strings
- Auth-aware go_router with `/sign-in` and `/home` placeholders + session-driven redirect
- Two widget tests locking the redirect contract
- `env.json.example` at repo root
- `analysis_options.yaml` tightening (single quotes, relative imports, exclude generated i18n)

**Out of scope:**
- Real sign-in / sign-up / sign-out UI (S-01)
- Task CRUD UI (S-02, S-06)
- Focus timer + break presentation + randomization (S-03)
- Realtime `tasks` subscription (S-08)
- Account settings UI and locale override picker (S-09)
- Android `USE_FULL_SCREEN_INTENT` plumbing (sub-task of S-03)
- Actual `env.json` (only the `.example`)
- Dart code-gen from the Postgres schema

## Architecture / Approach

```
                    main()
                      |
       WidgetsFlutterBinding.ensureInitialized()
                      |
                initializeSupabase()  --SupabaseEnvException--> runApp(ErrorApp)
                      |
                runApp(ProviderScope(MainApp(router: buildRouter())))
                      |
            MaterialApp.router
                /  |  |  \
        theme   l10n  router (go_router)
                            |
                redirect <-- currentSession (sync) + refreshListenable (auth-state stream)
                            |
        signed-out -> SignInPage     signed-in -> HomePage   (both placeholders)
```

Supabase initialization is sync-on-entry: `Supabase.initialize` runs before `runApp`, so `Supabase.instance.client.auth.currentSession` is available synchronously inside the router's `redirect` callback. The Riverpod `currentSessionProvider` mirrors the same value for widgets that prefer the provider API, but the router itself reads the source of truth directly to keep the redirect callback sync.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Project structure & dependencies | pubspec deps, `lib/` layout, `l10n.yaml` + ARB files, `env.json.example`, tightened analysis_options | Dep version drift; mitigated by `flutter pub add` resolving at install time |
| 2. App initialization & visual baseline | `Supabase.initialize` + `ErrorApp`, Material 3 light/dark themes, `MaterialApp.router` with i18n delegates, placeholder pages rendering localized strings | Cross-platform boot differences (Linux vs Android) for theme/locale - mitigated by manual gate on both |
| 3. Auth-aware router & tests | Riverpod auth providers, go_router with redirect + `GoRouterRefreshStream`, two widget tests | go_router `redirect` callback ordering vs `refreshListenable` - addressed in `## Critical Implementation Details` |

**Prerequisites:**
- Flutter SDK installed and `flutter doctor` green on Linux toolchain (SETUP.md §0)
- Supabase project linked and `env.json` created locally from `env.json.example` (SETUP.md §1-2, §5)
- Android device or emulator available for the Phase 2 / Phase 3 cross-platform gate (optional but recommended)

**Estimated effort:** ~2-3 evening sessions across the three phases (small, well-scoped slices; the bulk of the time is i18n round-trip verification and the cross-platform boot check).

## Open Risks & Assumptions

- The change-id used here (`f-01-app-shell`) diverges from the roadmap's canonical `flutter-app-shell`. `/10x-archive` matches by change-id; either rename the change folder before archiving or patch the roadmap's Change ID column to match. Not blocking for implementation.
- The dependency pins are deliberately deferred to the implementer (`flutter pub add` resolves at install time). If a major version of `flutter_riverpod` or `go_router` shipped with breaking API changes between plan and implementation, the API names used in the plan (`StreamProvider`, `redirect`, `refreshListenable`) may need minor adjustment. Risk is low for the 2026 plan date.
- `GoRouterRefreshStream` is not exported from `go_router` itself in recent versions and is written inline in `lib/app/router.dart`. If a future `go_router` version exports a built-in equivalent, the inline helper can be deleted.

## Success Criteria (Summary)

- `flutter run -d linux --dart-define-from-file=env.json` boots into a themed, localized `/sign-in` placeholder; switching OS theme and OS language flip the visible UI on next launch.
- Removing a `--dart-define` triggers `ErrorApp` with a message naming the missing var and the SETUP.md fix.
- `flutter test` passes two widget tests that prove the auth-redirect contract S-01 will plug into.
- The same `flutter run` on Android produces equivalent behavior.
