---
starter_id: flutter
package_manager: pub
project_name: taskodoro
hints:
  language_family: multi
  team_size: solo
  deployment_target: self-host
  ci_provider: github-actions
  ci_default_flow: manual-promotion
  bootstrapper_confidence: verified
  path_taken: standard
  quality_override: false
  self_check_answers: null
  has_auth: true
  has_payments: false
  has_realtime: true
  has_ai: false
  has_background_jobs: false
---

## Why this stack

Taskodoro targets Linux desktop and Android from a single codebase, the exact fit Flutter was designed for. Flutter passes all four agent-friendly gates: Dart is statically typed, the widget tree is convention-based, Flutter is well-represented in training data, and docs are current and version-pinned. Flutter ships via GitHub Releases (Linux AppImage, sideloaded Android APK), the self-host channel. The landing page pairs with 10x-astro-starter, which also pins the Supabase project scaffold and keeps the JS surface co-located with Cloudflare Pages. Supabase handles the entire backend without a custom server: Postgres stores the per-user task pool, Auth covers register, login, and credential rotation, and Realtime subscriptions on the tasks table handle sync. The integration endpoint exposes list_tasks, add_task, and complete_task as three PL/pgSQL functions via PostgREST RPC: named operations contract, no cold start, row-level security enforces per-user scoping via JWT, and schema changes hide behind function bodies. The Android USE_FULL_SCREEN_INTENT flag (Open Question #7) is not resolved by Flutter but is not worsened by it; a platform channel handles it.

## Component boundaries (added 2026-05-23)

The Supabase decision above stands for data, auth, RLS, and realtime.
This section adds a small wrapper for the public integration surface and
any future LLM-calling endpoints, keeping the whole stack on Supabase for
v1 to minimise deployment surfaces.

The hosted integration endpoint (FR-012, FR-013) runs as a Supabase Edge
Function, not as PostgREST RPC exposed directly to external clients. The
protocol is MCP (resolving PRD Open Question #1): the function hosts a
remote MCP server exposing `list_tasks`, `add_task`, `complete_task` as
MCP tools, authenticated via Supabase Auth (the function calls
`supabase.auth.getUser(token)` on the Bearer JWT in the request).

Layout:

- Flutter clients (Linux desktop, Android) talk to Supabase directly via
  `supabase_flutter`: auth flows, realtime subscriptions on the `tasks`
  table, and `list_tasks` / `add_task` / `complete_task` RPC calls. No
  function hop. The `supabase-rpc-only-contract` convention in
  `.claude/skills/conventions/SKILL.md` still applies unchanged.
- The Astro app in `landing/` talks to Supabase directly via
  `@supabase/ssr` for admin and marketing pages.
- A new Supabase Edge Function (Deno, TypeScript, deployed via
  `supabase functions deploy`) hosts the MCP server and is the only
  surface external integration clients see. Future LLM-calling endpoints
  (parked as a v2 capability) land alongside it as additional Edge
  Functions.

What this buys: one deployment surface, one CLI, one dashboard. JWT
validation is one line (`supabase.auth.getUser(token)`) because the
function shares Auth context with the rest of the stack. The function is
co-located with Postgres in the same region, so no connection pooling
gymnastics and no cross-region latency on DB calls. The `pg_cron`
extension covers any scheduled jobs.

Cloudflare Workers is held as a known future migration target. If
specific CF features become load-bearing, the migration is "rewrite the
function in TypeScript on Wrangler", a few days at most, and the Flutter
and Astro sides do not change. Concrete triggers worth migrating for:

- Heavy LLM traffic that benefits from AI Gateway's caching, observability,
  and provider fallback.
- Spec-compliant MCP OAuth where `@cloudflare/workers-oauth-provider`
  would save real implementation time.
- Edge inference workloads where Workers AI is materially better-suited
  than calling out to a hosted LLM provider.
- Vector workloads where Vectorize at the edge beats `pgvector` in
  Postgres.

None of these are v1 concerns. Defer until concrete need shows up.

What stays unchanged: `pubspec.yaml`, the `landing/` app, the Supabase
schema in `landing/supabase/migrations/`, the RLS policies, and the
function names `list_tasks` / `add_task` / `complete_task`. Supabase
Realtime continues to handle FR-017 sync; the Flutter clients subscribe
directly.
