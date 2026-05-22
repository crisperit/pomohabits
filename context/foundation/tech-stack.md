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
