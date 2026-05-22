# Taskodoro Setup

After scaffolding the project and completing the Supabase setup, this file is what stands between you and a working dev loop. Run through it once.

## Prerequisites

- Flutter SDK on PATH (verify with `flutter --version`)
- Node 20+ and npm (verify with `node --version`)
- A free Supabase account at https://supabase.com

## 1. Create the cloud Supabase project

In the Supabase dashboard:

1. New project -> name `taskodoro`, choose a region close to you, set a strong DB password.
2. Wait for provisioning to finish (~1 minute).
3. From Project Settings -> API, copy the **Project URL** and the **anon (public) key**. You will paste these into env files below.
4. From Project Settings -> API -> Project ref, copy the **project ref** (the slug, not the full URL).

## 2. Link the local repo to the cloud project

From the repo root:

```bash
cd landing
npx supabase login              # one-time, opens a browser
npx supabase link --project-ref <YOUR_PROJECT_REF>
```

`link` prompts for the DB password you set in step 1.

## 3. Push the initial migration

Still inside `landing/`:

```bash
npx supabase db push
```

This applies `landing/supabase/migrations/20260522170000_initial_schema.sql` to your cloud database: creates the `tasks` and `task_completions` tables, the enums, RLS policies, and the three RPC functions (`list_tasks`, `add_task`, `complete_task`).

Verify in the dashboard -> Database -> Tables: you should see `tasks` and `task_completions` under the `public` schema, both with RLS enabled.

## 4. Configure auth

In the Supabase dashboard -> Authentication -> Providers:

1. Enable **Email** (default; allow email confirmations as you prefer for local dev -- disable confirmation for a faster loop).
2. Authentication -> URL Configuration -> set **Site URL** to your local Astro dev URL (typically `http://localhost:4321`).
3. Add redirect URLs as needed when you deploy.

## 5. Wire env vars

### Astro (landing/)

The Astro app reads `SUPABASE_URL` and `SUPABASE_KEY` from `astro:env/server` (declared in `astro.config.mjs`).

Create `landing/.env` (gitignored already):

```
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_KEY=<your-anon-key>
```

Restart `npm run dev` after creating the file.

For Cloudflare local dev (`npm run dev` with the workerd runtime), use `landing/.dev.vars` instead -- same key=value format, also gitignored.

> Note on naming: Astro's `landing/src/lib/supabase.ts` reads `SUPABASE_KEY`; the Flutter examples below use `SUPABASE_ANON_KEY`. Both refer to the same Supabase **anon (public) key** value from the dashboard. The two names exist only because each app's conventions differ; nothing forces them to match.

### Flutter (repo root)

Flutter does not have a single canonical env-file convention. The two common patterns:

- **Compile-time defines** (recommended for v1): pass at every run/build invocation.

  ```bash
  flutter run -d linux \
    --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=<anon-key>
  ```

  Read them in Dart with `String.fromEnvironment('SUPABASE_URL')`.

- **Runtime .env via the `flutter_dotenv` package**: more flexible, less secure (the .env ships with the app bundle if not handled carefully). Add later if the compile-time approach becomes annoying.

Pick one and wire `Supabase.initialize(url: ..., anonKey: ...)` in `lib/main.dart` before `runApp`.

## 6. Run the loop

Two terminal panes:

```bash
# Pane 1: Astro landing page
cd landing
npm run dev

# Pane 2: Flutter app
flutter run -d linux
# or for Android:
flutter run -d <device-id>
```

## Optional: generate Dart types from the schema

Supabase's CLI does not officially target Dart, but the community tool `supabase_codegen` reads the auto-generated OpenAPI doc and emits Dart classes. Add it later if hand-writing model classes becomes painful.

## Known constraints

- **PRD Open Question #6**: all 17 must-have FRs kept in v1 scope. Over-scope risk on the 3-week budget is acknowledged.
- **PRD Open Question #7**: Android `USE_FULL_SCREEN_INTENT` plumbing for FR-007 is an implementation task, not a stack-level fix. A platform channel handles it once the break-presentation feature is wired.
- **npm audit on `landing/`**: 4 high-severity transitive vulnerabilities through Astro (`devalue` DoS, etc.). Local dev is unaffected; address before any production deploy via npm `overrides` or wait for an upstream Astro patch.
- **Supabase Free tier** suffices for v1 scale (small users, low QPS). No usage knobs to tune in this setup.
