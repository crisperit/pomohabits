---
bootstrapped_at: 2026-05-22T16:27:00Z
starter_id: flutter
starter_name: Flutter
project_name: taskodoro
language_family: multi
package_manager: pub
cwd_strategy: subdir-then-move
bootstrapper_confidence: verified
phase_3_status: ok
audit_command: "null"
---

## Hand-off

```yaml
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
```

Taskodoro targets Linux desktop and Android from a single codebase, the exact fit Flutter was designed for. Flutter passes all four agent-friendly gates: Dart is statically typed, the widget tree is convention-based, Flutter is well-represented in training data, and docs are current and version-pinned. Flutter ships via GitHub Releases (Linux AppImage, sideloaded Android APK), the self-host channel. The landing page pairs with 10x-astro-starter, which also pins the Supabase project scaffold and keeps the JS surface co-located with Cloudflare Pages. Supabase handles the entire backend without a custom server: Postgres stores the per-user task pool, Auth covers register, login, and credential rotation, and Realtime subscriptions on the tasks table handle sync. The integration endpoint exposes list_tasks, add_task, and complete_task as three PL/pgSQL functions via PostgREST RPC: named operations contract, no cold start, row-level security enforces per-user scoping via JWT, and schema changes hide behind function bodies. The Android USE_FULL_SCREEN_INTENT flag (Open Question #7) is not resolved by Flutter but is not worsened by it; a platform channel handles it.

## Pre-scaffold verification

| Signal          | Value                                                                          | Severity | Notes                                                                                                               |
| --------------- | ------------------------------------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------- |
| GitHub repo     | not run                                                                        | n/a      | No GitHub recency signal available in the registry card (docs_url points at flutter.dev/docs, not a github.com URL). |
| Local toolchain | Flutter 3.41.9 framework committed 2026-04-29 (~3 weeks ago at scaffold time) | fresh    | Bonus signal from `flutter --version`. Framework is actively maintained; no staleness concern.                      |

## Scaffold log

**Resolved invocation**: `flutter create -e bootstrap_scaffold --org com.example --platforms android,linux`

> Note: The card's `cmd_template` substitutes `{name}` with `.bootstrap-scaffold` per the `subdir-then-move` strategy. Flutter's CLI rejects names with leading dots and hyphens as invalid Dart package names (validation rule: `[a-z0-9_]`, no leading digit, no reserved word). The temp dir name was adapted to `bootstrap_scaffold`: a valid Dart identifier that satisfies the same subdir-then-move purpose. The in-session `--platforms` override (android,linux instead of the card default android,ios,web) was applied as instructed.

**Strategy**: subdir-then-move
**Exit code**: 0
**Files moved**: 37 (31 moved silently, 1 append-merged gitignore, 1 .scaffold sibling for README.md, 1 .scaffold sibling for .idea/, 41 files written by flutter create minus scaffold-internal .gitignore handled separately)
**Conflicts (.scaffold siblings)**: README.md.scaffold, .idea.scaffold/
**.gitignore handling**: append-merged: cwd's 23 lines preserved in full; Flutter scaffold's 35 lines appended after separator `# --- appended by 10x-bootstrapper from flutter scaffold ---`. All Flutter lines were new (zero deduped).
**.bootstrap-scaffold cleanup**: deleted (scaffold ran as `bootstrap_scaffold/`; temp dir removed after all files moved)

### Per-file move log

| Path (relative to scaffold root)  | Action                   | Notes                                                                                          |
| --------------------------------- | ------------------------ | ---------------------------------------------------------------------------------------------- |
| `.gitignore`                      | append-merge-gitignore   | cwd had existing .gitignore; Flutter lines appended after separator; scaffold copy removed     |
| `README.md`                       | existing-wins-sideline   | cwd had README.md (5476 bytes); scaffold copy saved as README.md.scaffold (45 bytes)          |
| `analysis_options.yaml`           | moved                    | no conflict in cwd                                                                             |
| `android/` (entire subtree)       | moved                    | no conflict in cwd                                                                             |
| `bootstrap_scaffold.iml`          | moved                    | no conflict in cwd                                                                             |
| `.dart_tool/` (entire subtree)    | moved                    | no conflict in cwd                                                                             |
| `.idea/`                          | sidelined as .idea.scaffold/ | cwd `.idea` entry exists as a sandbox char-device shim; conflict rule applied; scaffold copy saved as .idea.scaffold/ |
| `lib/main.dart`                   | moved                    | no conflict in cwd                                                                             |
| `linux/` (entire subtree)         | moved                    | no conflict in cwd                                                                             |
| `.metadata`                       | moved                    | no conflict in cwd                                                                             |
| `pubspec.lock`                    | moved                    | no conflict in cwd                                                                             |
| `pubspec.yaml`                    | moved                    | no conflict in cwd                                                                             |

## Post-scaffold audit

**Tool**: skipped: no built-in audit tool for `multi`
**Recommended external tool**: `language_family: multi` has no single audit tool that covers the full stack. For Dart specifically, the user can later run `flutter pub outdated` or `dart pub deps` as informal checks. No fake "0 findings" record is produced; this skip is a structured note, not a clean-bill report.

## Post-scaffold corrections

The `flutter create` invocation used the temp directory name `bootstrap_scaffold` as the package name (Flutter derives the package name from the target directory unless `--project-name` is passed; the registry card's `cmd_template` does not pass that flag). A post-scaffold rename pass updated 7 files plus the Kotlin package directory and the IntelliJ module descriptor to use `taskodoro` instead:

- `pubspec.yaml`: top-level `name:` field
- `android/app/build.gradle.kts`: namespace and applicationId
- `android/app/src/main/AndroidManifest.xml`: package and label references
- `android/app/src/main/kotlin/com/example/bootstrap_scaffold/` directory renamed to `com/example/taskodoro/`
- `android/app/src/main/kotlin/com/example/taskodoro/MainActivity.kt`: package declaration
- `linux/CMakeLists.txt`: BINARY_NAME and APPLICATION_ID
- `linux/runner/my_application.cc`: window-title literal
- `bootstrap_scaffold.iml` renamed to `taskodoro.iml`

`flutter pub get` was run to refresh `pubspec.lock` and `.dart_tool/` with the new package name. The scaffold log section above preserves the original `bootstrap_scaffold` command exactly as it was executed; this section records the divergence and its resolution.

A future improvement for the bootstrapper registry: the Flutter card's `cmd_template` should pass `--project-name {project_name}` so the package name matches the hand-off intent regardless of the temp directory.

## Hints recorded but not acted on

| Hint                    | Value              |
| ----------------------- | ------------------ |
| bootstrapper_confidence | verified           |
| quality_override        | false              |
| path_taken              | standard           |
| self_check_answers      | null               |
| team_size               | solo               |
| deployment_target       | self-host          |
| ci_provider             | github-actions     |
| ci_default_flow         | manual-promotion   |
| has_auth                | true               |
| has_payments            | false              |
| has_realtime            | true               |
| has_ai                  | false              |
| has_background_jobs     | false              |

## Next steps

Next: a future skill will set up agent context (CLAUDE.md, AGENTS.md), M1L4: Memory Architecture. For now, your project is scaffolded and verified. Happy hacking.

Useful manual steps in the meantime:
- `git init` (if you have not already) to start your own repo history.
- Review any `.scaffold` siblings the conflict policy created and decide which version to keep: `README.md.scaffold`, `.idea.scaffold/`.
- Address audit findings per your project's risk tolerance; the full breakdown is in this log (audit skipped for `multi`; run `flutter pub outdated` manually as an informal check).

**Open carry-overs from the PRD that affect this scaffold's usefulness:**

- **PRD Open Question #6 (block: yes)**: v1 budget cut still unresolved. The 3-week after-hours budget did not assume a hosted backend plus accounts plus sync plus cross-platform client. Identify which FRs to demote before starting implementation.
- **PRD Open Question #7**: Android `USE_FULL_SCREEN_INTENT` plumbing is an implementation task once you start FR-007. Flutter does not solve it; a platform channel handles it.
- **Paired 10x-astro-starter (landing page + Supabase scaffold) is NOT scaffolded by this run**: bootstrapper consumes one starter_id and Flutter was the primary. Scaffold the Astro side separately when you are ready (the registry's `cmd_template` for 10x-astro-starter is `git clone https://github.com/przeprogramowani/10x-astro-starter {name} && cd {name} && {pm} install`).
