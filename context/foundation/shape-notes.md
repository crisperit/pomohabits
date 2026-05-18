---
project: "Taskodoro"
context_type: greenfield
created: 2026-05-18
updated: 2026-05-18
product_type: desktop
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
      decision: "no direct integration with a single task manager. Taskodoro exposes an external integration surface (MCP-compatible and/or local HTTP API) so any external client can push tasks INTO the break pool."
    - topic: "access control"
      decision: "single-user local profile on desktop; integration surface gated by a generated access token the user pastes into external clients."
    - topic: "MVP scope"
      decision: "3-week after-hours MVP. Scope is deliberately tight: timer + break overlay + task CRUD + randomization rule + token-gated MCP/API with 3-4 tools + at least one user-flow test + CI/CD. Polish localization, focus-task linking, sound, system tray, task details, tag/project sources, manual selection UI all deferred to v2."
    - topic: "hosted sync service"
      decision: "no hosted sync, no app-level user accounts, no outbound network from the app itself. Multi-device sync is a v2+ concern at earliest. Users who want multi-device today can run a personal bridge against the MCP/API surface. Settled non-goal."
  frs_drafted: 14
  quality_check_status: accepted
---

# Taskodoro: Shape Notes

## Vision & Problem Statement

Traditional Pomodoro apps treat the break as a passive countdown: a 5-minute gap the user fills by reaching for their phone, doomscrolling, and losing the momentum the focus session just built. The pain lands on a focus-driven knowledge worker or hobbyist who runs Pomodoros to protect deep work but watches their breaks turn into productivity-killing distractions: forgotten hydration, neglected stretches, no eye rest, no real recovery. Existing Pomodoro apps assume the user fills the break themselves, which is precisely the problem.

The insight is that the break is a *recurring forced-interrupt window*, a perfect substrate for nudging tiny productive habits (hydration, stretching, eye rest, micro-tasks) into the user's day. A fullscreen break overlay surfaces a small set of habits when willpower is at its lowest: one or more *fixed* habits the user always does, a *randomized* one drawn from a personal pool, and a built-in suggestion when the pool is empty. The randomization rule (filter by break-type and habit-type, exclude already-done dailies, fall back to a suggestion) is the product's domain decision; the overlay is the user-visible payoff.

Taskodoro is fully usable on its own: the user defines their own break habits inside the app and the randomization rule does the rest. For power users who want their break pool to draw from elsewhere, the app exposes an external integration surface (MCP-compatible and/or local HTTP API) gated by a generated access token, so external clients (scripts, AI agents, bridges) can push tasks INTO the pool. The app has no built-in vendor integrations; that bridging is the external client's job, not Taskodoro's.

## User & Persona

Primary persona: a focus-driven knowledge worker or hobbyist who runs Pomodoros to structure deep work and wants their breaks to do something useful instead of evaporating into a phone. They define a small set of break habits inside the app, the randomization rule decides what to surface on each break, and the fullscreen overlay nudges them into doing it. They work on desktop (Windows or Linux first), tolerate the app being offline-only, and prefer a well-randomized handful of habits over a long checklist they would ignore.

A subset of these users are agent-fluent or scripting-comfortable: they may additionally wire up an external client (an AI agent, a personal script, a vendor bridge they build themselves) that pushes tasks into the break pool through the MCP/API surface. This is a power-user capability, not a persona-defining trait. The primary persona is satisfied by the app alone.

## Access Control

Single-user desktop application with a **local profile**: all data lives on-device, no cloud, no app-level user accounts. State and ownership are unambiguous because there is exactly one local user per install. The Settings tab is the boundary for changing app behaviour; non-Settings tabs are read/write surfaces over the same local profile.

The external integration surface (MCP server and/or local HTTP API) is gated by a **generated access token**. The app produces a token on first launch, the user copies it into whichever external client they want to authorize, and the token can be rotated or revoked from the Settings tab. Any client that wants to read or modify the break-task pool through the integration surface must present a valid token; unauthenticated clients are rejected at the boundary. This makes the app non-anonymous at its integration edge without inventing app-level user accounts that have no second user to justify them.

## Success Criteria

### Primary

The first-launch end-to-end loop runs without manual intervention:

1. User opens Taskodoro. Run-mode window shows a 25-minute timer.
2. User clicks Start. Timer counts down.
3. User opens the Settings tab in a separate window and adds two break tasks (one fixed "Drink water" daily/both, one randomized "10 pushups" unlimited/short). Both persist on-disk and reappear after app restart.
4. After 25 minutes (or a configurable shorter value for demoability), the fullscreen break overlay appears. It shows the fixed task, one randomized task drawn from the user's pool, a Roll-again button, and an End-break-early button.
5. User clicks the [✓] on the fixed task. The check persists for the rest of the day. User clicks End-break-early. Focus session resumes.
6. From outside the app, an MCP-compatible client (presenting the generated access token) calls `list_tasks`, then `add_task`, then `list_tasks` again. The new task appears in Settings without restart and is eligible for the next break.

Step 6 is the integration-surface acceptance test: without it, the cross-vendor pitch is unproven.

### Secondary

- A built-in suggestion appears when the randomized pool is empty (so the break overlay never goes blank for a new user).
- The Roll-again button picks a *different* randomized task from the eligible pool when one is available.
- Timer durations (work, short, long, sessions-until-long) are user-configurable from Settings and persist across restarts.

### Guardrails

- The integration surface NEVER accepts requests without a valid access token. An unauthenticated client receives a 401-equivalent rejection.
- All user data lives on-device. No outbound network calls are made by the app itself in v1 (external clients may make their own outbound calls, but Taskodoro proper does not phone home).
- The break overlay is dismissable: pressing Escape or clicking End-break-early always returns control to the user within one second. The app never traps the user behind an unkillable fullscreen.

## MVP scope: what stays, what goes

> Three-week after-hours MVP. Cuts are deliberate; the deferred items move to v2 once the loop works.

**Stays in v1:**

- Pomodoro timer (work / short break / long break, configurable durations and sessions-until-long).
- Task CRUD over break tasks: id, name, type (one_time / daily / unlimited), break_type (short / long / both), is_fixed (bool). No task-details rich content in v1.
- Fullscreen break overlay with fixed list + one randomized task + Roll-again button + End-break-early.
- Randomization rule (the domain decision): filter the pool by break_type and exclude already-completed daily/one_time tasks; pick uniformly from the remainder; fall back to a built-in suggestion when the pool is empty.
- Built-in suggestions list (read-only in v1; editable in v2).
- Settings UI: timer config, task CRUD list, integration token reveal/rotate.
- Token-gated MCP server with 3-4 tools (at minimum: `list_tasks`, `add_task`, `complete_task`; plus optionally `delete_task` or `health`).
- At least one automated test covering the primary user flow (start session, break appears, randomized task is visible).
- CI/CD pipeline that builds the app and runs the test on every push to main.

**Deferred to v2 (or later):**

- TickTick OAuth + sync. Replaced by the generic integration surface; external clients can bridge any vendor.
- Focus-task selection during work sessions and focus-time recording to any external system.
- Polish localization (v1 ships English-only; the i18n scaffolding is welcome but the second locale is not in scope).
- System tray / always-on-top window mode.
- Sound effects (system notification at session end is acceptable but not required for v1).
- Task details (description, image, links, estimated time, notes).
- Dynamic sources (tag-based or project-based) inside the app itself. External clients can replicate this pattern by maintaining their own filters and pushing the right tasks in.
- Manual-pick UI on the break overlay (after multiple Roll-agains). v1 has Roll-again only.
- Export / import configuration.
- Local HTTP REST API alongside MCP (if MCP alone is enough for v1, REST can wait; the integration surface is a single protocol in v1).

## Functional Requirements

> 14 FRs, all `must-have` for the 3-week MVP. Each carries a `> Socratic:` blockquote recording the strongest counter-argument considered and its resolution.

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

- FR-012: The app exposes an MCP server on a local interface; on first launch a unique access token is generated and visible in Settings. Priority: must-have
  > Socratic: Counter considered: a local-loopback service does not need a token; the loopback boundary is enough. Resolution: kept; loopback is shared across processes on the same machine, and the token is what makes the app non-anonymous at the integration edge per the access-control floor.

- FR-013: An MCP client presenting a valid token can call at least three tools: list_tasks, add_task, complete_task. Priority: must-have
  > Socratic: Counter considered: tool surface is too small; should also expose update, delete, settings, and timer state. Resolution: kept tight for v1; three verbs prove the inversion pattern. Update/delete are v2; settings/timer are out of scope for the integration surface (it is for task data, not app config).

- FR-014: User can rotate the access token from Settings; the previous token is invalidated immediately and any client using it must re-authorize with the new token before further calls succeed. Priority: must-have
  > Socratic: Counter considered: rotation is a v2 feature; v1 can ship with one immutable token. Resolution: kept; "no way to rotate a leaked token" is a visible access-control weakness, and rotation is a small feature once the token-check path exists.

## User Stories

### US-01: First-launch standalone loop

- **Given** a freshly installed Taskodoro on a desktop with no break tasks defined
- **When** the user starts a focus session and, from Settings during the session, adds two break tasks: one fixed daily "Drink water" applicable to both break types, and one randomized unlimited "10 pushups" applicable to short breaks
- **Then** at the end of the work session the fullscreen break overlay appears showing the fixed task plus one randomized task drawn from the pool, with working Roll-again and End-break-early controls

#### Acceptance Criteria

- The fixed task appears on every break overlay whose break_type matches.
- The randomized slot picks uniformly from eligible tasks.
- Marking the daily fixed task complete prevents it from being checkable again until the next local midnight.
- Closing and reopening the app preserves both tasks and the day's completion state.

### US-02: External MCP client adds a task

- **Given** Taskodoro is running with a generated access token visible in Settings
- **When** an external MCP client connects with that token and calls add_task with a new task name, type, break_type, and is_fixed value
- **Then** the task appears in the Settings task list within one second and is eligible for the next break overlay matching its break_type

#### Acceptance Criteria

- A client presenting an invalid token is rejected and no task is created.
- A follow-up list_tasks call from the same authorized client returns the new task with the same field values the client supplied.
- Rotating the token in Settings causes the original client to be rejected on its next call until it re-authorizes with the new token.

## Business Logic

**One-sentence rule**: when a break starts, the app shows every fixed task whose break_type matches the current break, plus exactly one randomized task drawn uniformly from the pool of currently eligible (not-already-done-today) tasks, falling back to one built-in suggestion only when the eligible pool is empty.

The rule consumes three inputs as the user encounters them: the user's break-task pool (built through Settings or pushed in through the integration surface), the current break type (short for the 5-minute breaks between focus sessions, long for the longer break after every fourth session), and the shipped built-in-suggestions list (consulted only as a last-resort fallback). It outputs two visual slots on the break overlay: the fixed list (zero or more tasks shown together) and exactly one variable slot (a randomized task, or a suggestion if no task is eligible). The user encounters the rule every time a break begins; the Roll-again button re-runs the variable-slot selection without re-running the fixed-list filter.

Eligibility is type-aware. one_time tasks become permanently ineligible after their first completion. daily tasks become ineligible until the next local midnight after each completion. unlimited tasks remain perpetually eligible. The randomization is uniform over the eligible set: no preference weighting, no recency penalty, no streak boost in v1. Weighting is a v2 candidate if "the same task keeps appearing three breaks in a row" turns out to be a real complaint.

## Non-Functional Requirements

- The break overlay appears within 500 ms of the focus-session timer reaching zero on a typical desktop (consumer laptop or desktop, not low-end ARM single-board computers).
- The break overlay returns control to the user within 1 s of pressing End-break-early or the Escape key; this guarantee holds even under sustained background-process CPU load.
- The app remains fully functional when the host machine is offline; no feature in v1 depends on internet access initiated by the app itself.
- An invalid or missing access token presented at the integration boundary is rejected before any tool handler runs, and the rejection latency is indistinguishable from a valid-but-empty call (no timing-side-channel on token presence).
- Task and completion state survive a normal app close and a host-machine reboot; data loss requires explicit user action (delete a task, rotate the token while discarding its data, or filesystem-level intervention).
- The Settings task list remains responsive (operations under 200 ms) for pools up to 500 tasks. Larger pools are out of scope.
- The fullscreen overlay does not consume more than one display unless the user has explicitly opted into multi-monitor mode (default behaviour parked in Open Question 5).

## Non-Goals

- **Hosted sync service, cloud accounts, or any server-side state.** Settled in Phase 3. Users who want multi-device sync wire it up themselves through the MCP/API surface.
- **Vendor-specific integrations baked into the app** (TickTick, Todoist, Notion, Google Tasks, and similar). The whole point of the integration surface is that external clients handle bridging; building one inside the app re-creates the coupling just removed.
- **Focus-task linking and external time recording.** Deferred to v2. The integration surface in v1 reads and writes break-task data only, not focus-session state.
- **Polish localization (and any non-English locale) in v1.** English-only ship. i18n scaffolding is parked as Open Question 4.
- **System tray, always-on-top window mode, custom themes.** Window-management nice-to-haves; not on the path to the cert floor.
- **Sound effects on session boundaries.** Standard OS notifications are sufficient for v1; in-app audio is a v2 candidate.
- **Rich task details (description, image, links, estimated time, notes).** v1 tasks carry name, type, break_type, and is_fixed; nothing else. Details are a v2 capability.
- **Dynamic sources (filter-based task pools by tag or project) inside the app.** External clients can replicate this pattern themselves by maintaining their own filters and pushing the matching tasks in.
- **Manual-pick UI on the break overlay** (for example "after three rerolls, show a chooser"). Roll-again only in v1.
- **Export / import configuration files.** v1 uses a single on-disk profile; users who want backup can take it through the integration surface or filesystem.
- **Sub-100 ms randomization for pools larger than 500 tasks.** Performance non-goal; the target persona does not maintain 500 break habits.

## Quality cross-check

All required elements are present for a greenfield shape-notes:

| Element | Status |
| --- | --- |
| Access Control | present (local profile, token at the integration edge) |
| Business Logic (one-sentence rule) | present (randomization rule with eligibility filter and suggestion fallback) |
| Project artifacts | present (this shape-notes.md with full checkpoint) |
| Timeline-cost acknowledged | present (mvp_weeks: 3, at the 3-week target; no acknowledgment block required) |
| Non-Goals | present (11 entries) |

`quality_check_status: accepted`. The Open Questions below are forward-looking design choices, not gaps; they do not need to be mirrored into the PRD as blocking concerns.

## Open Questions

> Populated by subsequent phases and the Step 7 cross-check.

1. **Integration surface protocol for v1**: MCP server only, or MCP plus local HTTP API? Default proposed: MCP only, since one protocol is enough to prove the inversion pattern and a second doubles surface area without doubling value. Owner: user. Block: partial (touches FR-012 to FR-014).
2. **One concrete external importer ships with v1, or not?** Default proposed: no. The integration surface exists so external clients handle bridging; shipping a vendor importer inside the app re-creates the coupling we just removed. A demo client can live in a separate repo. Owner: user. Block: partial.
3. **Token rotation UX (Settings affordance)**: silent disconnect of all clients on rotate, or a list of recently-authenticated clients to revoke selectively? Default proposed: silent disconnect, single token model. Owner: user. Block: no (UX detail, deferable past v1).
4. **i18n scaffolding in v1, or no i18n at all?** Setting up i18n early means a second locale is cheap later; skipping it means rework when Polish ships. Owner: user. Block: no.
5. **Multi-monitor overlay behaviour**: fullscreen on the active monitor only, or fullscreen on every connected monitor? Owner: user. Block: no (NFR/UX detail).
