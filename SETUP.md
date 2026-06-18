# Pomohabits Setup

After scaffolding the project and completing the Supabase setup, this file is what stands between you and a working dev loop. Run through it once.

## 0. Install prerequisites

You need four tools on PATH and three free cloud accounts.

### Tools (Linux)

**git**: `sudo apt install git` (Debian/Ubuntu) or `sudo dnf install git` (Fedora). Verify with `git --version`.

**Node 24** (matches `landing/.nvmrc`). Easiest path is `nvm`:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# restart your shell, then:
nvm install 24
cd landing && nvm use   # reads .nvmrc
```

Verify with `node --version` (should report `v24.x`).

**Flutter SDK**. Two options:

- Tarball (official, recommended): https://docs.flutter.dev/get-started/install/linux . Unpack to `~/development/flutter`, then add `~/development/flutter/bin` to PATH.
- Snap: `sudo snap install flutter --classic`.

Linux desktop build deps:

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
```

Verify with `flutter doctor`. The "Linux toolchain" entry should be green and "Connected device" should list "Linux (desktop)".

**Android (optional)** for `flutter run -d <android-id>`: install Android Studio from https://developer.android.com/studio, then open the SDK Manager and install the SDK platform matching your device API level. Accept licenses once:

```bash
flutter doctor --android-licenses
```

Plug in a device with USB debugging on (or start an emulator) and confirm with `flutter devices`.

### Accounts (all free)

- **Supabase**: https://supabase.com . Hosts Postgres, Auth, Realtime, and the MCP Edge Function.
- **Cloudflare**: https://dash.cloudflare.com/sign-up . Hosts the landing page via `wrangler`.
- **GitHub** (if you do not already have one): https://github.com/join . Source hosting and CI.

## 1. Create the cloud Supabase project

In the Supabase dashboard:

1. New project -> name `pomohabits`, choose a region close to you, set a strong DB password.
2. Wait for provisioning to finish (~1 minute).
3. From Project Settings -> API, copy the **Project URL** and the **publishable key** (from the API Keys page; older dashboards label this `anon`/public). You will paste these into env files below.
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

This applies the migrations under `landing/supabase/migrations/` to your cloud database: the `habits` and `habit_completions` tables, the enums, RLS policies, and the three RPC functions (`list_habits`, `add_habit`, `complete_habit`).

Verify in the dashboard -> Database -> Tables: you should see `habits` and `habit_completions` under the `public` schema, both with RLS enabled.

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
SUPABASE_KEY=<your-publishable-key>
```

Restart `npm run dev` after creating the file.

For Cloudflare local dev (`npm run dev` with the workerd runtime), use `landing/.dev.vars` instead -- same key=value format, also gitignored.

> Note on naming: Astro's `landing/src/lib/supabase.ts` reads `SUPABASE_KEY`; the Flutter side uses `SUPABASE_PUBLISHABLE_KEY`. Both hold the same value -- the project's publishable key from the dashboard's API Keys page (or the legacy `anon` JWT from `npx supabase status` locally; both work). The two names exist only because each app's conventions differ.

### Flutter (repo root)

Flutter does not have a single canonical env-file convention. The two common patterns:

- **Compile-time defines** (recommended for v1): pass at every run/build invocation.

  ```bash
  flutter run -d linux \
    --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
  ```

  Read them in Dart with `String.fromEnvironment('SUPABASE_URL')`.

- **Runtime .env via the `flutter_dotenv` package**: more flexible, less secure (the .env ships with the app bundle if not handled carefully). Add later if the compile-time approach becomes annoying.

Pick one and wire `Supabase.initialize(url: ..., anonKey: <publishable-key>)` in `lib/main.dart` before `runApp`.

> VS Code shortcut: copy `env.json.example` to `env.json` (gitignored), fill in your values, then use "Run and Debug" -> "Pomohabits (Linux, --dart-define-from-file)". The Flutter extension reads `--dart-define-from-file=env.json` from `.vscode/launch.json`.

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

## 7. Create the MCP Edge Function (Supabase)

Goal: scaffold a TypeScript MCP server that runs on a Supabase Edge Function, talks to Postgres via the three RPC functions, and validates Supabase Auth JWTs in the handler.

All `supabase` CLI commands in this section run from `landing/`.

- Scaffold the function: `cd landing && npx supabase functions new mcp`. This creates `landing/supabase/functions/mcp/index.ts`.
- Implement the handler following Supabase's official BYO MCP guide (https://supabase.com/docs/guides/getting-started/byo-mcp): MCP TypeScript SDK + Hono + `WebStandardStreamableHTTPServerTransport`. Register `list_habits` / `add_habit` / `complete_habit` as MCP tools; each delegates to the matching PostgREST RPC.
- Put the JWT check in a shared helper at `landing/supabase/functions/_shared/auth.ts`. It extracts the Bearer token from the request, calls `supabase.auth.getUser(token)`, and returns the user (or rejects with 401). The MCP handler calls this helper before dispatching any tool call.
- In `landing/supabase/config.toml`, set the `mcp` function's `verify_jwt = false` (auth runs in handler code, not at the platform gate). Edge Functions automatically run in the project's region, so the function and Postgres share a region with no extra config.
- Local dev (already `cd`'d into `landing/`): `npx supabase functions serve mcp --env-file ./supabase/functions/.env.local`. The function will be available at `http://127.0.0.1:54321/functions/v1/mcp`.
- Deploy to your linked project (from `landing/`): `npx supabase functions deploy mcp`.
- Tag every production deploy (from repo root, since git is repo-wide): `git tag prod-mcp-$(date +%Y%m%d-%H%M) && git push --tags`.

Why this shape: the function shares Auth context with the rest of the Supabase stack, so the JWT check is one line; the function and Postgres are in the same region, so DB round-trip is single-digit ms; the operational surface stays on one CLI.

## 8. Set up rollback (scripted, not native)

Supabase Edge Functions do not have a native rollback command (unlike `wrangler rollback`). Add this once, before your first production deploy.

Create `scripts/rollback-function.sh` at the repo root:

```bash
#!/usr/bin/env bash
set -euo pipefail

name="${1:?usage: rollback-function.sh <function-name> <git-sha-or-tag>}"
sha="${2:?usage: rollback-function.sh <function-name> <git-sha-or-tag>}"

repo_root="$(git rev-parse --show-toplevel)"
func_path="landing/supabase/functions/${name}"

trap 'git -C "$repo_root" checkout HEAD -- "$func_path" 2>/dev/null || true' EXIT

git -C "$repo_root" checkout "$sha" -- "$func_path"
(cd "$repo_root/landing" && npx supabase functions deploy "$name")
echo "Rolled $name back to $sha and restored working tree."
```

Make it executable: `chmod +x scripts/rollback-function.sh`. Recover from a bad deploy with `./scripts/rollback-function.sh mcp <prior-prod-tag-sha>`.

## 9. Deploy the landing page (Cloudflare Workers)

The Astro landing in `landing/` is configured for `@astrojs/cloudflare` and uses `wrangler` to deploy. New Cloudflare projects target Workers (with Static Assets), not Pages.

- One-time auth: `cd landing && npx wrangler login` (opens a browser, asks you to authorize the CLI to your Cloudflare account).
- Production secrets (replace section 5's `.dev.vars` for cloud builds):

  ```bash
  cd landing
  npx wrangler secret put SUPABASE_URL    # paste the project URL when prompted
  npx wrangler secret put SUPABASE_KEY    # paste the publishable key when prompted
  ```

- Build and deploy: `npx wrangler deploy`. Output prints the live URL (something like `https://pomohabits-landing.<account>.workers.dev`).
- Back in the Supabase dashboard, add the live URL to Authentication -> URL Configuration -> Redirect URLs so signin/signup flows work in production.

CI (`.github/workflows/ci.yml`) handles lint + build on push. Add a `CLOUDFLARE_API_TOKEN` GitHub Actions secret (Cloudflare dashboard -> My Profile -> API Tokens, scoped to "Edit Cloudflare Workers" on the relevant account) when you wire automated deploys.

## Optional: generate Dart types from the schema

Supabase's CLI does not officially target Dart, but the community tool `supabase_codegen` reads the auto-generated OpenAPI doc and emits Dart classes. Add it later if hand-writing model classes becomes painful.

## Known constraints

- **PRD Open Question #6**: all 17 must-have FRs kept in v1 scope. Over-scope risk on the 3-week budget is acknowledged.
- **PRD Open Question #7**: Android `USE_FULL_SCREEN_INTENT` plumbing for FR-007 is an implementation task, not a stack-level fix. A platform channel handles it once the break-presentation feature is wired.
- **npm audit on `landing/`**: 4 high-severity transitive vulnerabilities through Astro (`devalue` DoS, etc.). Local dev is unaffected; address before any production deploy via npm `overrides` or wait for an upstream Astro patch.
- **Supabase Free tier** suffices for v1 scale (small users, low QPS). No usage knobs to tune in this setup.

## Troubleshooting

- **`flutter doctor` shows red on "Linux toolchain"**: re-run the `sudo apt install` line from section 0 and check that `clang --version` and `cmake --version` resolve.
- **`flutter doctor` shows red on "Android toolchain"**: open Android Studio, install the SDK Platform and Command-line Tools, then re-run `flutter doctor --android-licenses` and answer `y` to every prompt.
- **`supabase login` opens a browser but nothing happens**: copy the verification code printed in the terminal, paste it into the browser tab manually.
- **`supabase db push` fails with "permission denied for schema public"**: confirm the DB password you set in section 1 matches the one in `~/.supabase/access-token`; re-run `npx supabase link --project-ref <ref>` if unsure.
- **Astro dev server exits with `SUPABASE_URL is missing`**: confirm you created `landing/.env` (or `landing/.dev.vars` for the workerd runtime) and restarted `npm run dev` afterwards.
- **`flutter run` cannot find the Supabase URL at runtime**: you forgot `--dart-define`. The values do not persist between invocations; either include them every run or wire a `scripts/run-linux.sh` wrapper.
- **`npx wrangler deploy` fails with "no account_id"**: the first run after `wrangler login` writes the account ID to `landing/wrangler.jsonc`; if you have multiple Cloudflare accounts, pass `--account-id <id>` explicitly.
- **MCP function returns 401 on every call**: confirm the client sends `Authorization: Bearer <jwt>` and that the JWT was issued by the same Supabase project the function is deployed to. The project API key (anon or publishable) is NOT a valid bearer token; you need a session token from `supabase.auth.signIn*`.
- **MCP function returns 500 with no log line**: tail logs with `npx supabase functions logs mcp --follow`. Empty logs usually mean the function crashed during startup; check the deploy output for syntax errors.
- **`npm audit` reports high-severity findings in `landing/`**: known. Already documented in "Known constraints" above. Address with npm `overrides` or wait for an upstream Astro patch before production deploy.
