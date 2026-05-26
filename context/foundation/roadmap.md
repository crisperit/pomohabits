---
project: Taskodoro
version: 1
status: draft
created: 2026-05-26
updated: 2026-05-26
prd_version: 4
main_goal: market-feedback
top_blocker: time
---

# Roadmap: Taskodoro

> Derived from `context/foundation/prd.md` (v4) + auto-researched codebase baseline (2026-05-26).
> Edit-in-place; archive when superseded.
> Slices below are listed in dependency order. The "At a glance" table is the index.

## Vision recap

Taskodoro turns the Pomodoro break, normally a passive five-minute drift into the phone, into a recurring forced-interrupt window that surfaces the user's own habits: a small set of always-shown items plus one randomized pick from their pool, with a built-in suggestion when the pool is empty. The break-presentation behaviour is the product wedge: the one trait that, if removed, makes Taskodoro indistinguishable from a generic Pomodoro app. v1 ships Linux desktop + Android mobile from a single Flutter client against a hosted Supabase backend, and exposes a Supabase Edge Function MCP endpoint so external clients can push tasks into the break pool.

## North star

**S-03: User signs in, adds a break task, runs a focus session, and sees the break presentation showing their task**: this slice is the validation milestone (the smallest end-to-end flow that proves the core product hypothesis, sequenced as early as Prerequisites allow). After it ships, the wedge: "breaks that aren't passive," is validated end-to-end against the user (the primary persona). Everything past S-03 sharpens the loop; nothing before S-03 proves it.

## At a glance

| ID   | Change ID                              | Outcome (user can …)                                                                              | Prerequisites    | PRD refs                              | Status   |
| ---- | -------------------------------------- | ------------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------- | -------- |
| F-01 | flutter-app-shell                      | (foundation) Flutter app boots past Hello World with Supabase client, auth-aware routing, theming, i18n (pl+en) | none             | FR-015, FR-016                        | ready    |
| F-02 | first-prod-deploy                      | (foundation) Production Supabase project + MCP function + landing live; Site URL wired           | none             | deploy-plan.md                        | ready    |
| S-01 | flutter-auth-signup-signin             | register, sign in, sign out from Flutter; session persists across restart                         | F-01             | FR-015, FR-016, US-01                 | proposed |
| S-02 | flutter-add-task                       | add a break task from the Flutter task-configuration surface                                      | S-01             | FR-003, US-01                         | proposed |
| S-03 | focus-timer-and-break-presentation     | start a focus session, watch the timer hit zero, see the full-screen break presentation          | F-01, S-02       | FR-001, FR-007, FR-011, US-01         | proposed |
| S-04 | mark-task-complete-with-category-rules | mark a task done on the break presentation; daily resets at midnight, one-time inert, unlimited re-eligible | S-03   | FR-008, US-01                         | proposed |
| S-05 | end-break-early-and-roll-again         | press End-break-early or Escape to resume focus; press Roll-again to swap the randomized slot     | S-03             | FR-009, FR-010, US-01                 | proposed |
| S-06 | flutter-task-crud-list-edit-delete     | list every task grouped by always-shown vs randomized, edit any field, delete a task              | S-02             | FR-004, FR-005, FR-006                | proposed |
| S-07 | flutter-timer-configuration            | configure work / short / long / sessions-until-long durations; persist across restart             | S-03             | FR-002                                | proposed |
| S-08 | flutter-realtime-task-sync             | see task changes from any authenticated client reflected in the Flutter UI within seconds         | S-02             | FR-017                                | proposed |
| S-09 | account-credential-rotation            | rotate or invalidate session credentials from account settings; old session rejected immediately  | S-01             | FR-014                                | proposed |
| S-10 | mcp-integration-acceptance-test        | external MCP client lists tasks, adds one, lists again, with the new task appearing in Flutter    | F-02, S-02       | FR-012, FR-013, US-02                 | proposed |

## Streams

Navigation aid: groups items that share a Prerequisites chain. Canonical ordering still lives in the dependency graph below; this table is the proposed reading order across parallel tracks.

| Stream | Theme                                | Chain                                          | Note                                                                          |
| ------ | ------------------------------------ | ---------------------------------------------- | ----------------------------------------------------------------------------- |
| A      | Foundation & north star              | `F-01` → `S-01` → `S-02` → `S-03`              | Validates the product wedge end-to-end. Everything else only matters if A lands. |
| B      | Break-loop polish                    | `S-04` / `S-05`                                | Parallel siblings; both join Stream A at `S-03`. Together they complete US-01. |
| C      | Task & timer management              | `S-06` / `S-07`                                | Parallel siblings; `S-06` joins at `S-02`, `S-07` joins at `S-03`.            |
| D      | Cross-device sync & account lifecycle| `S-08` / `S-09`                                | Parallel siblings; `S-08` joins at `S-02`, `S-09` joins at `S-01`.            |
| E      | Production deploy & integration test | `F-02` → `S-10`                                | `F-02` is independent of A; `S-10` also joins Stream A at `S-02`.             |

## Baseline

What's already in place in the codebase as of 2026-05-26 (auto-researched + user-confirmed).
Foundations below assume these are present and do NOT re-scaffold them.

- **Frontend (Flutter):** absent: `lib/main.dart` is still the scaffold Hello World; `supabase_flutter ^2.12.4` declared in `pubspec.yaml` but unused. F-01 builds the shell.
- **Backend / API (MCP Edge Function):** present: `landing/supabase/functions/mcp/index.ts` (141 lines, MCP SDK + Hono + zod + supabase-js) and `_shared/auth.ts` exist; `[functions.mcp] verify_jwt=false` in `config.toml`.
- **Data (Postgres):** present: `landing/supabase/migrations/20260522170000_initial_schema.sql` defines `tasks`, `task_completions`, RLS policies, and `list_tasks` / `add_task` / `complete_task` RPCs. Note: `update_task` / `delete_task` RPCs and timer-config persistence are NOT in the initial migration; S-06 and S-07 add them.
- **Auth:** partial: landing has full signin/signup/confirm-email/callback + middleware + protected `dashboard.astro`. Flutter side has zero auth code despite `supabase_flutter` being on the dep list; S-01 builds it.
- **Deploy / infra:** partial: `landing/wrangler.jsonc` renamed to `taskodoro-landing`; `scripts/rollback-function.sh` exists. `deploy-plan.md` is `approved-for-execution` but not yet executed in production; F-02 executes it. No `.github/workflows/` on disk yet.
- **Observability:** absent: no logging library, no OTel, no Sentry/Datadog in either app. Out of scope for v1 per the "go simple" investment posture.

## Foundations

### F-01: Flutter app shell

- **Outcome:** (foundation) Flutter app boots past Hello World with Supabase client initialised (via `--dart-define`), auth-aware routing scaffold, a consistent theme/layout, Flutter i18n scaffolded with Polish (pl) and English (en) locales via flutter_localizations + intl + ARB files, and the directory structure that subsequent slices will hang features off.
- **Change ID:** flutter-app-shell
- **PRD refs:** FR-015, FR-016 (prerequisite for auth slice)
- **Unlocks:** S-01 (auth), S-03 (timer + break presentation), and every other Flutter-side slice (S-02 / S-04 / S-05 / S-06 / S-07 / S-08 / S-09 indirectly via S-01).
- **Prerequisites:** none
- **Parallel with:** F-02
- **Blockers:** none
- **Unknowns:**
  - State-management approach (Riverpod / Bloc / vanilla `ChangeNotifier`). Owner: implementer. Block: no.
  - Routing library (go_router / Navigator 2.0 / hand-rolled). Owner: implementer. Block: no.
  - Locale-detection strategy: device locale on first launch with a settings override, or always show a picker on first launch. Default proposed: device-locale-then-override. Owner: implementer. Block: no.
- **Risk:** Sequenced first because every user-visible slice needs it. Getting the directory layout / state-management choice wrong here causes follow-on rework across every later slice; the implementation plan should converge on conventions before opening multiple slice plans in parallel.
- **Status:** ready

### F-02: First production deploy executed

- **Outcome:** (foundation) Production Supabase project linked, schema migration pushed, MCP Edge Function deployed, landing page deployed to Cloudflare Workers, Supabase auth Site URL wired to the live landing URL, and `scripts/rollback-function.sh` smoke-tested. The deploy-plan.md verification checklist (section 5) passes end-to-end.
- **Change ID:** first-prod-deploy
- **PRD refs:** None directly (operational; supports FR-012 / FR-017 in production). Execution of `context/deployment/deploy-plan.md` (status: `approved-for-execution`).
- **Unlocks:** S-10 (integration acceptance test runs against prod by definition); dogfood phase for every other slice (Flutter clients can authenticate against the real auth surface and the breaks are actually meaningful day-to-day).
- **Prerequisites:** none
- **Parallel with:** F-01, S-01, S-02 (local dev unblocked regardless)
- **Blockers:** none
- **Unknowns:**
  - Production Supabase region (deploy-plan §2.2: placeholder until §3.1 selection). Owner: user. Block: no.
  - npm audit triage outcome (deploy-plan §2.6: highs must be triaged or accepted). Owner: user. Block: no (planned mitigation).
- **Risk:** Sequenced as a foundation rather than a late slice because main_goal is `market-feedback`: until prod is live the user cannot dogfood, and that's the whole point. The deploy plan is approved and the verification checklist already exists, so this is execute-and-confirm work, not design work. Failure mode: the manual gates in deploy-plan §3 stall (Supabase region pick, Cloudflare API token); mitigate by booking the gates first.
- **Status:** ready

## Slices

### S-01: Flutter sign-up + sign-in + sign-out

- **Outcome:** User can register on the Flutter client by supplying name + credential, log in with the same credential, and sign out from a placeholder account screen. The session persists across app restart so the user does not have to re-authenticate every cold start.
- **Change ID:** flutter-auth-signup-signin
- **PRD refs:** FR-015, FR-016, US-01 (the "registers, logs in" prefix)
- **Prerequisites:** F-01
- **Parallel with:** F-02
- **Blockers:** none
- **Unknowns:**
  - Email-confirmation flow on Flutter (the landing already has `/auth/confirm-email`): does the Flutter client deep-link back, or do we expect the user to confirm via browser and then sign in? Owner: implementer. Block: no.
  - Error-presentation conventions (Snackbar vs inline). Owner: implementer. Block: no.
- **Risk:** First Supabase-touching slice; if the Flutter↔Supabase JWT plumbing is wrong it pollutes every downstream slice. Mitigate by writing one integration test that asserts a signed-in `Session` is restored on cold start.
- **Status:** proposed

### S-02: Add a break task from Flutter

- **Outcome:** User can navigate to the task-configuration surface in the Flutter client, fill in a name + category (one-time / daily / unlimited) + applicable break window (short / long / both) + always-shown flag, and submit. The task lands in Postgres via the existing `add_task` RPC and is visible after a manual refresh.
- **Change ID:** flutter-add-task
- **PRD refs:** FR-003, US-01 (the "adds two break tasks" step)
- **Prerequisites:** S-01
- **Parallel with:** none
- **Blockers:** none
- **Unknowns:**
  - Form-validation strategy (client-side only, or rely on RLS rejection messages). Owner: implementer. Block: no.
- **Risk:** Smallest possible CRUD slice: deliberately excludes list/edit/delete to keep the path to S-03 short. If a flat list is needed for visual confirmation, render a debug-only widget; the real list UI lives in S-06.
- **Status:** proposed

### S-03: Focus timer + break presentation (north star)

- **Outcome:** User can start a focus session at a default 25-minute duration, pause and resume it, and when the timer reaches zero a full-screen break presentation appears listing every always-shown task whose applicable break window matches the current break, plus one randomized task drawn from the eligible pool (or one built-in suggestion if the pool is empty).
- **Change ID:** focus-timer-and-break-presentation
- **PRD refs:** FR-001, FR-007, FR-011, US-01 (the validation milestone)
- **Prerequisites:** F-01, S-02
- **Parallel with:** F-02 (deploy is independent)
- **Blockers:** none
- **Unknowns:**
  - Android USE_FULL_SCREEN_INTENT permission + activity-from-notification flow (PRD §Open Question #7): does v1 require break presentation to fire while Android app is backgrounded, or is the user expected to keep the app foregrounded during focus? Owner: implementer (with user decision on foreground-only acceptance). Block: no (Linux desktop ships independently; Android-backgrounded behaviour is a sub-task of the slice).
  - Multi-monitor default (PRD §Open Question #5): active monitor only, or every connected monitor? Default proposed: active monitor only. Owner: user. Block: no.
  - Randomization implementation locus: client-side from a `list_tasks` result, or a Postgres function that returns one eligible row? Owner: implementer. Block: no.
- **Risk:** The north star: failure here means the wedge is unproven. Highest scope concentration of any single slice (timer + presentation + randomization + always-shown filter + fallback). Resist the temptation to also include mark-complete (that's S-04) or Roll-again (S-05); keep this slice narrow so it ships.
- **Status:** proposed

### S-04: Mark task complete with category rules

- **Outcome:** User can mark any task on the break presentation as completed; the completion persists per the task's category: daily tasks become ineligible until the next local midnight, one-time tasks become permanently ineligible, unlimited tasks remain immediately re-eligible. State survives app close and host restart.
- **Change ID:** mark-task-complete-with-category-rules
- **PRD refs:** FR-008, US-01 (the "marks the always-shown task complete" step)
- **Prerequisites:** S-03
- **Parallel with:** S-05, S-06, S-07
- **Blockers:** none
- **Unknowns:**
  - Where does "local midnight" come from: device timezone, or a user-profile timezone? The existing `list_tasks(p_timezone)` RPC accepts a timezone parameter; the Flutter client must pass one consistently. Owner: implementer. Block: no.
- **Risk:** The eligibility rule is the load-bearing piece of the randomization domain. Bugs here corrupt the break-pool experience silently. Cover daily-reset, one-time-inert, and unlimited-replay with table-driven tests; this is the slice where regression tests earn their keep.
- **Status:** proposed

### S-05: End-break-early and Roll-again

- **Outcome:** User can press End-break-early (button) or Escape (keyboard) to dismiss the break presentation; control returns within 1 s and the focus cycle advances to the next session. User can press Roll-again to swap the randomized slot for a different eligible task (the rolled-out task stays in the pool).
- **Change ID:** end-break-early-and-roll-again
- **PRD refs:** FR-009, FR-010, US-01 (the "ends the break early" step and the Roll-again guarantee)
- **Prerequisites:** S-03
- **Parallel with:** S-04, S-06, S-07
- **Blockers:** none
- **Unknowns:**
  - Behaviour when only one eligible task exists and the user presses Roll-again: re-pick the same task, show a hint, or disable the button? Owner: implementer. Block: no.
- **Risk:** Dismissability is the PRD's hard guardrail ("the app never traps the user behind an unkillable full-screen surface"). Test the 1-second dismiss latency under simulated background CPU load; this NFR is non-negotiable.
- **Status:** proposed

### S-06: Flutter task CRUD: list grouped, edit, delete

- **Outcome:** User can see every break task grouped by always-shown vs randomized buckets (with category and applicable break window visible per row), edit any field on an existing task, and delete a task. Schema extension: new `update_task` and `delete_task` PostgREST RPC functions added in a follow-up migration.
- **Change ID:** flutter-task-crud-list-edit-delete
- **PRD refs:** FR-004, FR-005, FR-006
- **Prerequisites:** S-02
- **Parallel with:** S-04, S-05, S-07, S-08
- **Blockers:** none
- **Unknowns:**
  - `delete_task` semantics with existing completions: cascade-delete `task_completions` rows, or block deletion when completions reference the task? PRD §FR-006 says immediate removal; default proposed: cascade. Owner: user. Block: no.
- **Risk:** Adds two new Postgres functions (`update_task`, `delete_task`): schema work that must keep the MCP Edge Function in lockstep per the `infrastructure.md` "split-surface signature drift" risk. The MCP function does NOT currently expose update/delete (FR-013 explicitly excludes them), so the schema work doesn't force an Edge-Function change today, but any future MCP-side exposure of update/delete must reuse the same RPCs.
- **Status:** proposed

### S-07: Timer configuration UI

- **Outcome:** User can configure work duration, short-break duration, long-break duration, and the number of work sessions before a long break from an account-settings surface. Configuration persists across restart and applies to subsequent focus sessions.
- **Change ID:** flutter-timer-configuration
- **PRD refs:** FR-002
- **Prerequisites:** S-03
- **Parallel with:** S-04, S-05, S-06, S-08
- **Blockers:** none
- **Unknowns:**
  - Where does configuration persist: a new `user_settings` table (clean, cross-device), JSONB on `auth.users.raw_user_meta_data` (no migration, but coupled to auth), or Flutter SharedPreferences (no sync, simpler)? PRD §FR-002 demands restart-persistence but is silent on cross-device. Owner: user (architectural choice). Block: no (default proposed: new `user_settings` table to stay consistent with the per-user backend pattern).
- **Risk:** A new server-side table is the right shape for sync but the wrong shape for "ship in 3 weeks". Sequenced after the north star precisely so a thinner alternative (local-only SharedPreferences) remains available as a budget cut without rolling back the wedge.
- **Status:** proposed

### S-08: Flutter realtime task sync

- **Outcome:** Flutter client subscribes to the `tasks` table via `supabase_flutter` realtime. Changes made through any authenticated client (Flutter on another device, external MCP client) appear in the Flutter UI within a few seconds, without manual restart or reload.
- **Change ID:** flutter-realtime-task-sync
- **PRD refs:** FR-017
- **Prerequisites:** S-02
- **Parallel with:** S-04, S-05, S-06, S-07
- **Blockers:** none
- **Unknowns:**
  - Realtime publication scope: only `tasks`, or `tasks` + `task_completions`? Subscribing to completions too keeps "marked-done" state live across devices but doubles the channel cost. Default proposed: `tasks` only for v1. Owner: implementer. Block: no.
  - Replication-row policy under RLS: the publication must respect RLS; Supabase Realtime supports this since 2024, but verify the configuration is on. Owner: implementer. Block: no.
- **Risk:** Sync is the primary justification for the hosted-backend pivot per FR-017's Socratic note ("deferring sync to v2 would mean v1 ships a hosted backend that the clients barely use"). If subscription plumbing turns out brittle, the slice is a candidate for cut, but doing so re-opens the hosted-backend rationale.
- **Status:** proposed

### S-09: Account credential rotation

- **Outcome:** User can sign out from account settings and (separately) invalidate every active session for their account. Any active client using the old credentials is rejected immediately on its next request and must re-authenticate.
- **Change ID:** account-credential-rotation
- **PRD refs:** FR-014, US-02 acceptance criterion 3 ("signing out or rotating session credentials causes the original client to be rejected")
- **Prerequisites:** S-01
- **Parallel with:** S-02, S-03, F-02
- **Blockers:** none
- **Unknowns:**
  - UX shape (PRD §Open Question #3): silent disconnect of all clients, or a list of recently-authenticated clients to revoke selectively? Default proposed: silent disconnect. Owner: user. Block: no.
- **Risk:** The security floor for the integration surface. Bugs here are the kind that silently leave invalidated tokens live; the slice's verification path must include "old session presented after rotation is rejected" as a hard test, not an inspection.
- **Status:** proposed

### S-10: MCP integration acceptance test

- **Outcome:** An external MCP client (script or curl) authenticated as the user calls `list_tasks` against the production MCP Edge Function, then `add_task`, then `list_tasks` again. The new task appears in the response. The same task appears in the Flutter task-configuration surface within seconds (via S-08 sync). An unauthenticated request to the same endpoint is rejected.
- **Change ID:** mcp-integration-acceptance-test
- **PRD refs:** FR-012, FR-013, US-02
- **Prerequisites:** F-02, S-02
- **Parallel with:** S-04, S-05, S-06, S-07, S-08, S-09
- **Blockers:** none
- **Unknowns:**
  - Whether to ship a thin demo client (PRD §Open Question #2: default proposed: no, the test stays as a curl sequence + recorded transcript). Owner: user. Block: no.
- **Risk:** This is not building the MCP function; the function exists. This slice writes the acceptance test that proves PRD §Success Criteria step 6. Failure mode: the test is treated as "done by inspection"; mitigate by recording the curl transcript in the change's artifacts so the next reader can re-run it against any environment.
- **Status:** proposed

## Backlog Handoff

| Roadmap ID | Change ID                              | Suggested issue title                                          | Ready for `/10x-plan` | Notes                              |
| ---------- | -------------------------------------- | -------------------------------------------------------------- | --------------------- | ---------------------------------- |
| F-01       | flutter-app-shell                      | Flutter app shell with Supabase client and auth-aware routing  | yes                   | Run `/10x-plan flutter-app-shell`  |
| F-02       | first-prod-deploy                      | Execute the approved first production deploy                   | yes                   | Run `/10x-plan first-prod-deploy`  |
| S-01       | flutter-auth-signup-signin             | Flutter sign-up, sign-in, and sign-out                         | no                    | Needs F-01                         |
| S-02       | flutter-add-task                       | Add a break task from the Flutter task-configuration surface   | no                    | Needs S-01                         |
| S-03       | focus-timer-and-break-presentation     | Focus timer + full-screen break presentation (north star)      | no                    | Needs S-02                         |
| S-04       | mark-task-complete-with-category-rules | Mark task complete on break presentation with category rules   | no                    | Needs S-03                         |
| S-05       | end-break-early-and-roll-again         | End-break-early and Roll-again on break presentation           | no                    | Needs S-03                         |
| S-06       | flutter-task-crud-list-edit-delete     | Flutter task CRUD: list grouped, edit, delete                  | no                    | Needs S-02; adds update/delete RPC |
| S-07       | flutter-timer-configuration            | Persisted timer configuration UI                               | no                    | Needs S-03                         |
| S-08       | flutter-realtime-task-sync             | Flutter realtime task sync via supabase_flutter                | no                    | Needs S-02                         |
| S-09       | account-credential-rotation            | Account credential rotation from settings                      | no                    | Needs S-01                         |
| S-10       | mcp-integration-acceptance-test        | MCP integration acceptance test against production             | no                    | Needs F-02 and S-02                |

## Open Roadmap Questions

1. **Concrete external importer for v1?** Default proposed: no: the integration surface exists so external clients handle bridging. Owner: user. Block: no (roadmap-wide; affects S-10 framing only: does the acceptance test ship as a curl transcript or as a tiny demo MCP client?).
2. **Credential rotation UX shape (PRD §Open Question #3):** silent disconnect of all clients on rotation, or list-and-revoke selectively? Default proposed: silent disconnect. Owner: user. Block: no (affects S-09 only).
3. **i18n scaffolding in v1, or none at all (PRD §Open Question #4)?** **Resolution (2026-05-26): yes, scaffold in v1 with `pl` + `en` locales. Implementation folded into F-01 so every later slice writes localized strings from day one.** Owner: user. Block: no.
4. **Multi-monitor break-presentation default (PRD §Open Question #5):** active monitor only, or every connected monitor? Default proposed: active monitor only. Owner: user. Block: no (affects S-03 only).
5. **Android USE_FULL_SCREEN_INTENT (PRD §Open Question #7):** does v1 require the break presentation to surface from a backgrounded Android app, or is foreground-only acceptable? Foreground-only is materially simpler. Owner: user. Block: no (affects S-03 Android implementation only; Linux ships either way).
6. **Timer-configuration storage locus:** server-side `user_settings` table (sync, more migration work), JSON on `auth.users.raw_user_meta_data` (no migration, coupled to auth), or Flutter SharedPreferences (no sync, simpler, no cross-device parity)? Default proposed: server-side `user_settings` table. Owner: user. Block: no (affects S-07 only).

## Parked

- **Offline-first client / local cache**: Why parked: PRD §Non-Goals; v1 is online-first.
- **iOS, macOS, Windows, web clients**: Why parked: PRD §Non-Goals; v1 ships Linux desktop + Android only.
- **Stats and analytics surfaces**: Why parked: PRD §Non-Goals; deferred to v2.
- **Vendor-specific integrations baked into the app** (TickTick, Todoist, etc.): Why parked: PRD §Non-Goals; the integration surface exists so external clients bridge.
- **Focus-task linking and external time recording**: Why parked: PRD §Non-Goals; the integration surface in v1 is for break-task data only.
- **System tray, always-on-top window mode, custom themes**: Why parked: PRD §Non-Goals; window-management nice-to-haves not on the path to the deliverable floor.
- **Sound effects on session boundaries**: Why parked: PRD §Non-Goals; OS notifications sufficient for v1.
- **Rich task details** (description, image, links, estimated time, notes): Why parked: PRD §Non-Goals; v1 tasks carry name + category + break window + always-shown flag only.
- **Dynamic source pools** (filter-based by tag or project): Why parked: PRD §Non-Goals; external clients can replicate by pushing the filtered tasks in.
- **Manual-pick UI on the break presentation**: Why parked: PRD §Non-Goals; Roll-again only in v1.
- **Export / import of configuration files**: Why parked: PRD §Non-Goals; backups can flow through the integration surface or account-level export.
- **Sub-100 ms randomization for pools larger than 500 tasks**: Why parked: PRD §Non-Goals; performance target persona does not maintain 500 break habits.
- **Observability stack** (structured logging, OTel exporter, error tracking): Why parked: no PRD NFR demands it; investment posture is "go simple" outside of Flutter. Revisit when a real incident demands it.
- **Update / delete on the MCP surface** (FR-013 caps at list / add / complete): Why parked: PRD §FR-013 explicitly excludes them; reconsider in v2 when the wedge is proven.
- **Staging Supabase project, GitHub Actions auto-deploy, custom domain on Cloudflare**: Why parked: deploy-plan §8 (out of scope for first deploy); F-02 ships manual prod-from-laptop and CI auto-deploy comes later.
- **Flutter client distribution** (Linux AppImage, Android APK via GitHub Releases): Why parked: deploy-plan §8; a separate change once the cloud half is live.

## Done

<!-- Empty on first generation. /10x-archive appends an entry here when a change whose Change ID matches a roadmap item is archived. Do NOT pre-populate. -->
