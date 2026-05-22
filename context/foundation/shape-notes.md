---
project: "Taskodoro"
context_type: greenfield
created: 2026-05-18
updated: 2026-05-21
product_type: cross-platform     # desktop (Linux) + mobile (Android), single codebase
target_scale:
  users: small
  qps: low
  data_volume: small
timeline_budget:
  mvp_weeks: 3
  hard_deadline: null
  after_hours_only: true
tech_preferences:
  language_family: null
checkpoint:
  current_phase: 8
  phases_completed: [1, 2, 3, 4, 5, 6, 7]
  gray_areas_resolved:
    - topic: "vendor lock"
      decision: "no direct integration with a single task manager. Taskodoro exposes a hosted integration endpoint authenticated by the user's session, so any external client can push tasks INTO the break pool."
    - topic: "access control"
      decision: "user accounts on a hosted backend; the integration surface is gated by the user's authenticated session, so external clients act on behalf of an identified user rather than presenting a machine-local token."
    - topic: "MVP scope"
      decision: "3-week after-hours MVP. Scope is deliberately tight: timer + break overlay + task CRUD + randomization rule + user registration/login + hosted backend with per-user task store + authenticated hosted integration endpoint with 3 operations + at least one user-flow test + CI/CD. Polish localization, focus-task linking, sound, system tray, task details, tag/project sources, manual selection UI, offline cache all deferred to v2."
    - topic: "hosted sync service"
      decision: "Reversed: v1 now includes a hosted backend with user accounts and per-user task sync. Multi-device sync follows from this for free. The original 'no hosted sync' decision was overturned during scope review when access control was upgraded from a per-install token to user accounts. Offline-first behaviour is deferred to v2 as a local-cache concern; the v1 app is online-first."
    - topic: "target platforms"
      decision: "v1 ships on Linux desktop + Android mobile from a single cross-platform UI codebase. iOS, macOS, Windows, and web are deferred to v2. The full-screen break presentation behaves the same on both platforms; Android background-to-foreground constraints (foreground services / notification flow) are an Open Question for the stack-selection step."
  frs_drafted: 17
  quality_check_status: accepted
---

# Taskodoro: Shape Notes

## Vision & Problem Statement

Traditional Pomodoro apps treat the break as a passive countdown: a 5-minute gap the user fills by reaching for their phone, doomscrolling, and losing the momentum the focus session just built. The pain lands on a focus-driven knowledge worker or hobbyist who runs Pomodoros to protect deep work but watches their breaks turn into productivity-killing distractions: forgotten hydration, neglected stretches, no eye rest, no real recovery. Existing Pomodoro apps assume the user fills the break themselves, which is precisely the problem.

The insight is that the break is a *recurring forced-interrupt window*, a perfect substrate for nudging tiny productive habits (hydration, stretching, eye rest, micro-tasks) into the user's day. A fullscreen break overlay surfaces a small set of habits when willpower is at its lowest: one or more *fixed* habits the user always does, a *randomized* one drawn from a personal pool, and a built-in suggestion when the pool is empty. The randomization rule (filter by break-type and habit-type, exclude already-done dailies, fall back to a suggestion) is the product's domain decision; the overlay is the user-visible payoff.

Taskodoro is fully usable on its own: the user defines their own break habits inside the app and the randomization rule does the rest. For power users who want their break pool to draw from elsewhere, the app exposes a hosted integration endpoint authenticated by the user's session, so external clients (scripts, AI agents, bridges) can push tasks INTO the pool. The app has no built-in vendor integrations; that bridging is the external client's job, not Taskodoro's.

## User & Persona

Primary persona: a focus-driven knowledge worker or hobbyist who runs Pomodoros to structure deep work and wants their breaks to do something useful instead of evaporating into a phone. They define a small set of break habits inside the app, the randomization rule decides what to surface on each break, and the full-screen break presentation nudges them into doing it. They work on Linux desktop and Android mobile from a single shared client, tolerate the app requiring a network connection for task data, and prefer a well-randomized handful of habits over a long checklist they would ignore.

A subset of these users are agent-fluent or scripting-comfortable: they may additionally wire up an external client (an AI agent, a personal script, a vendor bridge they build themselves) that pushes tasks into the break pool through the hosted integration endpoint. This is a power-user capability, not a persona-defining trait. The primary persona is satisfied by the app alone.

## Access Control

User accounts on a hosted backend, with registration and login required for v1. Identity is per-user, not per-install: the same account opens the same task pool from any device or client. The configuration surface is the boundary for changing app behaviour; other surfaces are read/write over the same user's profile.

The hosted integration endpoint is gated by the user's authenticated session. External clients that want to read or modify the break-task pool through the integration endpoint must present a valid session credential issued after authentication; unauthenticated clients are rejected at the boundary. Account credentials are managed by the hosted authentication service; the user never holds a raw machine-local token. This design makes the integration edge non-anonymous by construction and removes the need for a generated per-install token entirely.

## Success Criteria

### Primary

The first-launch end-to-end loop runs without manual intervention:

1. User opens Taskodoro. Run-mode window shows a 25-minute timer.
2. User clicks Start. Timer counts down.
3. User opens the Settings tab in a separate window and adds two break tasks (one fixed "Drink water" daily/both, one randomized "10 pushups" unlimited/short). Both persist and reappear after app restart.
4. After 25 minutes (or a configurable shorter value for demoability), the fullscreen break overlay appears. It shows the fixed task, one randomized task drawn from the user's pool, a Roll-again button, and an End-break-early button.
5. User clicks the [v] on the fixed task. The check persists for the rest of the day. User clicks End-break-early. Focus session resumes.
6. From outside the app, an external client authenticated as the user calls `list_tasks`, then `add_task`, then `list_tasks` again. The new task appears in Settings without restart and is eligible for the next break.

Step 6 is the integration-surface acceptance test: without it, the cross-vendor pitch is unproven.

### Secondary

- A built-in suggestion appears when the randomized pool is empty (so the break overlay never goes blank for a new user).
- The Roll-again button picks a *different* randomized task from the eligible pool when one is available.
- Timer durations (work, short, long, sessions-until-long) are user-configurable from Settings and persist across restarts.

### Guardrails

- The integration surface NEVER accepts requests without a valid authenticated session. An unauthenticated client receives a 401-equivalent rejection.
- User data is protected by transport security and authenticated session credentials. No task data is transmitted without an active authenticated session.
- The break overlay is dismissable: pressing Escape or clicking End-break-early always returns control to the user within one second. The app never traps the user behind an unkillable fullscreen.

## MVP scope: what stays, what goes

> Three-week after-hours MVP. Cuts are deliberate; the deferred items move to v2 once the loop works.

**Stays in v1:**

- Pomodoro timer (work / short break / long break, configurable durations and sessions-until-long).
- Task CRUD over break tasks: id, name, type (one_time / daily / unlimited), break_type (short / long / both), is_fixed (bool). No task-details rich content in v1.
- Fullscreen break overlay with fixed list + one randomized task + Roll-again button + End-break-early.
- Randomization rule (the domain decision): filter the pool by break_type and exclude already-completed daily/one_time tasks; pick uniformly from the remainder; fall back to a built-in suggestion when the pool is empty.
- Built-in suggestions list (read-only in v1; editable in v2).
- User registration, login, and session management via a managed authentication service.
- Hosted backend that stores tasks per-user and serves both the desktop client and the hosted integration endpoint.
- Settings UI: timer config, task CRUD list, account settings.
- Authenticated hosted integration endpoint exposing at minimum three operations: list tasks, add task, complete task.
- At least one automated test covering the primary user flow (start session, break appears, randomized task is visible).
- CI/CD pipeline that builds the app and runs the test on every push to main.
- Cross-platform single-codebase client targeting Linux desktop and Android mobile in v1. Same full-screen break presentation behavior on both platforms.
- Note: neither the desktop nor mobile client has a local offline cache in v1. Network access is required for the core read/write loop.

**Deferred to v2 (or later):**

- TickTick direct integration and sync. Replaced by the generic integration surface; external clients can bridge any vendor.
- Focus-task selection during work sessions and focus-time recording to any external system.
- Polish localization (v1 ships English-only; the i18n scaffolding is welcome but the second locale is not in scope).
- System tray / always-on-top window mode.
- Sound effects (system notification at session end is acceptable but not required for v1).
- Task details (description, image, links, estimated time, notes).
- Dynamic sources (tag-based or project-based) inside the app itself. External clients can replicate this pattern by maintaining their own filters and pushing the right tasks in.
- Manual-pick UI on the break overlay (after multiple Roll-agains). v1 has Roll-again only.
- Export / import configuration.
- Offline-first or local-cache mode for the desktop client (v1 is online-first).
- iOS, macOS, Windows, and web clients (v1 ships Linux desktop + Android mobile only). Other platforms are v2.
- Stats and analytics surfaces.

## Functional Requirements

> 17 FRs, all `must-have` for the 3-week MVP. Each carries a `> Socratic:` blockquote recording the strongest counter-argument considered and its resolution.

### Timer & Focus Cycle

- FR-001: User can start, pause, and resume a focus session timer at the configured work duration. Priority: must-have
  > Socratic: Counter considered: pause/resume invites users to game the Pomodoro discipline. Resolution: kept; pausing is the user-trusted escape hatch, and removing it would push users to abuse the close button instead.

- FR-002: User can configure work duration, short-break duration, long-break duration, and the number of work sessions before a long break. Priority: must-have
  > Socratic: Counter considered: configurability is feature bloat; ship one canonical 25/5/15/4 set and skip the settings page. Resolution: kept; the cert floor requires real CRUD on user-meaningful data, and timer config is the second-most-edited surface after tasks. Cutting it would force tasks to carry the CRUD burden alone.

### Break Tasks (CRUD)

- FR-003: User can create a break task with name, type (one_time / daily / unlimited), break_type (short / long / both), and is_fixed flag. Priority: must-have
  > Socratic: Counter considered: four type axes is too much for v1; collapse to "task" plus a "fixed" bool. Resolution: kept; without break_type the overlay cannot filter, and without task type the daily-reset behaviour collapses. Each axis pulls weight.

- FR-004: User can list every break task grouped by fixed and randomized buckets, with type and break_type visible at a glance. Priority: must-have
  > Socratic: Counter considered: a flat list is simpler. Resolution: kept; the fixed/randomized distinction is the user's primary mental model and must be reflected in the UI.

- FR-005: User can edit any field of an existing break task. Priority: must-have
  > Socratic: Counter considered: editing is a v2 nicety; users can delete and re-add. Resolution: kept; the cert floor requires a real Update operation, and delete-and-re-add loses today's completion state.

- FR-006: User can delete a break task. Priority: must-have
  > Socratic: Counter considered: soft-delete is safer. Resolution: kept as hard delete; v1 has no global undo and adding one is its own feature. Soft-delete is a v2 candidate if data-loss complaints surface.

### Break Overlay

- FR-007: When a break starts, the app shows a fullscreen overlay listing every fixed task eligible for the current break_type plus one randomized task drawn from the eligible pool, or one built-in suggestion if the pool is empty. Priority: must-have
  > Socratic: Counter considered: fullscreen is hostile on multi-monitor setups; a focused window is friendlier. Resolution: kept; the premise is that breaks must beat the phone, and a non-fullscreen overlay loses the willpower battle on day one. Multi-monitor refinement (which monitor? all?) is a Phase-5/NFR question, not an FR change.

- FR-008: User can mark a task on the overlay as completed; the completion persists per the task's type rules: daily resets at next local midnight, one_time becomes permanently inert, unlimited remains immediately re-eligible. Priority: must-have
  > Socratic: Counter considered: unlimited tasks should also lock for the current break so the user does not feel pressured to do them repeatedly. Resolution: kept as-written; the user controls whether to repeat, and unlimited's value is exactly that flexibility. Per-break lock is a nice-to-have, not a must-have.

- FR-009: User can click Roll-again to swap the randomized task for a different eligible one; the rolled-out task stays in the pool. Priority: must-have
  > Socratic: Counter considered: Roll-again invites rerolling until something trivial comes up, defeating the discipline. Resolution: kept; the user owns their own breaks. If reroll-spam becomes a real complaint, add a per-break reroll cap in v2.

- FR-010: User can end the break early via End-break-early button or the Escape key; the focus cycle advances to the next session. Priority: must-have
  > Socratic: Counter considered: skipping breaks is the bad behaviour the app exists to prevent. Resolution: kept; trapping users behind a fullscreen overlay is unacceptable. The guardrail "dismissable in under one second" holds.

- FR-011: When the randomized pool is empty for the current break_type, the overlay shows one built-in suggestion from a shipped read-only list. Priority: must-have
  > Socratic: Counter considered: empty pool should leave the overlay empty so the user notices they need to add tasks. Resolution: kept; "the overlay never goes blank for a new user" is the first-launch acceptance gate. Empty-state UX is a separate question, not the absence-of-suggestion default.

### Integration Surface

- FR-012: The app exposes a hosted integration endpoint; the endpoint is accessible over the network and requires an authenticated session to accept any request. Priority: must-have
  > Socratic: Counter considered: a hosted endpoint is over-engineering for a desktop tool; a local interface was enough. Resolution: kept; the shift to user accounts and a hosted backend makes a hosted integration endpoint the natural home for the same capability. The local-only surface is no longer coherent with the online-first architecture.

- FR-013: An external client with a valid authenticated session can call at least three operations on the hosted integration endpoint: list tasks, add task, complete task. Priority: must-have
  > Socratic: Counter considered: tool surface is too small; should also expose update, delete, settings, and timer state. Resolution: kept tight for v1; three operations prove the inversion pattern. Update/delete are v2; settings/timer are out of scope for the integration surface (it is for task data, not app config).

- FR-014: User can rotate or invalidate their session credentials from the account settings; any active client session using the old credentials is rejected immediately and must re-authenticate before further calls succeed. Priority: must-have
  > Socratic: Counter considered: credential rotation is a v2 feature; v1 can rely on the managed authentication service's own session expiry. Resolution: kept; user-initiated credential invalidation is the basic security floor, and the managed authentication service is assumed to support it.

- FR-015: User can register a new account by supplying a name and credential; the account is created on the hosted backend and the user is logged in. Priority: must-have
  > Socratic: Counter considered: accounts are bloat for what is essentially a single-user desktop tool; the original per-install token was simpler. Resolution: kept; accounts are the prerequisite for the hosted backend, cross-device sync, and the authenticated hosted integration endpoint. Without accounts, the access-control floor collapses back to a machine-local token, and all three of those capabilities are lost.

- FR-016: Registered users can log in with their credentials; the hosted authentication service issues a session credential that the desktop client and external clients use to authorize subsequent requests. Priority: must-have
  > Socratic: Counter considered: accounts are bloat for what is essentially a single-user desktop tool. Resolution: same as FR-015; login is the other half of the account capability. The managed authentication service handles credential validation so the app does not need to implement it from scratch.

- FR-017: Task and completion changes made through any authenticated client (desktop or integration endpoint) for the same user account are reflected in the desktop client within a few seconds, without a manual restart or reload. Priority: must-have
  > Socratic: Counter considered: real-time sync is a v2 concern; v1 can show a refresh button. Resolution: kept; sync falls out naturally from the hosted-backend decision (all clients read from the same per-user store), and it is the primary motivation for reversing the no-hosted-backend non-goal. Deferring sync to v2 would mean v1 ships a hosted backend that the desktop client barely uses.

## User Stories

### US-01: First-launch standalone loop

- **Given** a freshly installed Taskodoro on a desktop with no break tasks defined
- **When** the user registers, logs in, starts a focus session and, from Settings during the session, adds two break tasks: one fixed daily "Drink water" applicable to both break types, and one randomized unlimited "10 pushups" applicable to short breaks
- **Then** at the end of the work session the fullscreen break overlay appears showing the fixed task plus one randomized task drawn from the pool, with working Roll-again and End-break-early controls

#### Acceptance Criteria

- The fixed task appears on every break overlay whose break_type matches.
- The randomized slot picks uniformly from eligible tasks.
- Marking the daily fixed task complete prevents it from being checkable again until the next local midnight.
- Closing and reopening the app (with a valid session) preserves both tasks and the day's completion state.

### US-02: External client adds a task

- **Given** Taskodoro is running and the user has an authenticated session
- **When** an external client authenticated as the user calls add_task with a new task name, type, break_type, and is_fixed value through the hosted integration endpoint
- **Then** the task appears in the Settings task list within one second and is eligible for the next break overlay matching its break_type

#### Acceptance Criteria

- A client without a valid authenticated session is rejected and no task is created.
- A follow-up list_tasks call from the same authenticated client returns the new task with the same field values the client supplied.
- Signing out or rotating session credentials causes the original client to be rejected on its next call until it re-authenticates.

## Business Logic

**One-sentence rule**: when a break starts, the app shows every fixed task whose break_type matches the current break, plus exactly one randomized task drawn uniformly from the pool of currently eligible (not-already-done-today) tasks, falling back to one built-in suggestion only when the eligible pool is empty.

The rule consumes three inputs as the user encounters them: the user's break-task pool (built through Settings or pushed in through the hosted integration endpoint), the current break type (short for the 5-minute breaks between focus sessions, long for the longer break after every fourth session), and the shipped built-in-suggestions list (consulted only as a last-resort fallback). It outputs two visual slots on the break overlay: the fixed list (zero or more tasks shown together) and exactly one variable slot (a randomized task, or a suggestion if no task is eligible). The user encounters the rule every time a break begins; the Roll-again button re-runs the variable-slot selection without re-running the fixed-list filter.

Eligibility is type-aware. one_time tasks become permanently ineligible after their first completion. daily tasks become ineligible until the next local midnight after each completion. unlimited tasks remain perpetually eligible. The randomization is uniform over the eligible set: no preference weighting, no recency penalty, no streak boost in v1. Weighting is a v2 candidate if "the same task keeps appearing three breaks in a row" turns out to be a real complaint.

## Non-Functional Requirements

- The break overlay appears within 500 ms of the focus-session timer reaching zero on a typical desktop (consumer laptop or desktop, not low-end ARM single-board computers), assuming a healthy connection to the hosted backend.
- The break overlay returns control to the user within 1 s of pressing End-break-early or the Escape key; this guarantee holds even under sustained background-process CPU load.
- The desktop client requires network connectivity to read or write tasks in v1; offline operation is a v2 capability.
- An invalid or missing session credential presented at the integration boundary is rejected before any tool handler runs, and the rejection latency is indistinguishable from a valid-but-empty call (no timing-side-channel on session validity).
- Task and completion state survive a normal app close and a host-machine or device restart; data lives on the hosted backend and is available on next login.
- The Settings task list remains responsive (operations under 200 ms) for pools up to 500 tasks. Larger pools are out of scope.
- The fullscreen overlay does not consume more than one display unless the user has explicitly opted into multi-monitor mode (default behaviour parked in Open Question 5).

## Non-Goals

- **Offline-first desktop client / local cache.** v1 is online-first; offline operation is a v2 capability.
- **iOS, macOS, Windows, and web clients in v1.** v1 ships Linux desktop + Android mobile from a single shared codebase. Other platforms are v2.
- **Stats and analytics surfaces.** Deferred to v2.
- **Vendor-specific integrations baked into the app** (TickTick, Todoist, Notion, Google Tasks, and similar). The whole point of the integration surface is that external clients handle bridging; building one inside the app re-creates the coupling just removed.
- **Focus-task linking and external time recording.** Deferred to v2. The integration surface in v1 reads and writes break-task data only, not focus-session state.
- **Polish localization (and any non-English locale) in v1.** English-only ship. i18n scaffolding is parked as Open Question 4.
- **System tray, always-on-top window mode, custom themes.** Window-management nice-to-haves; not on the path to the cert floor.
- **Sound effects on session boundaries.** Standard OS notifications are sufficient for v1; in-app audio is a v2 candidate.
- **Rich task details (description, image, links, estimated time, notes).** v1 tasks carry name, type, break_type, and is_fixed; nothing else. Details are a v2 capability.
- **Dynamic sources (filter-based task pools by tag or project) inside the app.** External clients can replicate this pattern themselves by maintaining their own filters and pushing the matching tasks in.
- **Manual-pick UI on the break overlay** (for example "after three rerolls, show a chooser"). Roll-again only in v1.
- **Export / import configuration files.** v1 uses a hosted profile per user; users who want backup can take it through the integration surface or account-level export.
- **Sub-100 ms randomization for pools larger than 500 tasks.** Performance non-goal; the target persona does not maintain 500 break habits.

## Quality cross-check

All required elements are present for a greenfield shape-notes:

| Element | Status |
| --- | --- |
| Access Control | present (user accounts on hosted backend, authenticated session at the integration edge) |
| Business Logic (one-sentence rule) | present (randomization rule with eligibility filter and suggestion fallback) |
| Project artifacts | present (this shape-notes.md with full checkpoint) |
| Timeline-cost acknowledged | present (mvp_weeks: 3, at the 3-week target; no acknowledgment block required) |
| Non-Goals | present (13 entries) |

`quality_check_status: accepted`. The Open Questions below are forward-looking design choices, not gaps; they do not need to be mirrored into the PRD as blocking concerns.

## Open Questions

> Populated by subsequent phases and the Step 7 cross-check.

1. **Integration surface protocol for v1**: the hosted integration endpoint speaks a single protocol; the specific protocol shape is deferred to tech-stack selection. Owner: user. Block: partial (touches FR-012 to FR-014).
2. **One concrete external importer ships with v1, or not?** Default proposed: no. The integration surface exists so external clients handle bridging; shipping a vendor importer inside the app re-creates the coupling we just removed. A demo client can live in a separate repo. Owner: user. Block: partial.
3. **Token rotation UX (Settings affordance)**: silent disconnect of all clients on credential invalidation, or a list of recently-authenticated clients to revoke selectively? Default proposed: silent disconnect. Owner: user. Block: no (UX detail, deferable past v1).
4. **i18n scaffolding in v1, or no i18n at all?** Setting up i18n early means a second locale is cheap later; skipping it means rework when Polish ships. Owner: user. Block: no.
5. **Multi-monitor overlay behaviour**: fullscreen on the active monitor only, or fullscreen on every connected monitor? Owner: user. Block: no (NFR/UX detail).
6. **v1 budget cut needed.** The 3-week after-hours budget did not assume a hosted backend, user accounts, and sync. Identify which one or two of the existing must-have FRs to demote (candidates: FR-005 edit-in-place, FR-009 Roll-again, FR-014 credential rotation, multi-monitor NFR) before implementation begins. Owner: user. Block: yes (must resolve before implementation starts).
7. **Android background-to-foreground constraint for the full-screen break presentation.** Android cannot freely force a full-screen overlay from a backgrounded app; the standard path is a high-priority notification that opens a full-screen activity, gated by `USE_FULL_SCREEN_INTENT` permission and Android version. Owner: user. Resolution path: downstream tech-stack-selection step (which cross-platform toolkit and which Android API surface together satisfy FR-007 on Android).
