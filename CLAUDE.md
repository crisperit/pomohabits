# CLAUDE.md

Guidance for working in this repository.

## What this repo is

Pomohabits is a desktop-first Pomodoro app whose break screen surfaces the user's
habits. The repo holds two apps that share one Supabase backend:

- **Flutter client** (repo root) - `lib/`, `linux/`, `android/`. Targets Linux
  desktop and Android from one Dart codebase. `supabase_flutter` talks to the
  shared backend.
- **Astro landing + admin** (`landing/`) - Astro 6 SSR on Cloudflare Workers,
  React 19 islands, Supabase SSR auth. Owns the Supabase migrations under
  `landing/supabase/migrations/` (the source of truth for schema).

## Flutter commands

Run from the repo root.

- `flutter run -d linux` - desktop dev loop.
- `flutter run -d <android-device-id>` - Android dev loop.
- `flutter analyze` - static analysis (uses `flutter_lints` via `analysis_options.yaml`).
- `flutter test` - unit + widget tests.
- `flutter test test/path/to_test.dart` - single file.
- `flutter pub get` - after editing `pubspec.yaml`.

Supabase credentials are passed at the command line via `--dart-define`, not a
`.env` file. See `SETUP.md` for the exact invocation and the one-time Supabase
project link + migration push.

## Conventions

- The Flutter app uses compile-time `--dart-define` flags (see `SETUP.md`); do not
  introduce `flutter_dotenv` without revisiting that choice.
- Supabase schema changes go through `landing/supabase/migrations/` using the
  `YYYYMMDDHHmmss_short_description.sql` naming convention. The Flutter client
  consumes the schema via PostgREST RPC (`list_habits`, `add_habit`, `complete_habit`).
