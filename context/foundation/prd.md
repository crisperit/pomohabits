---
project: "Taskodoro"
version: 1
status: draft
created: 2026-05-18
context_type: greenfield
product_type: desktop
target_scale:
  users: small
  qps: low
  data_volume: small
timeline_budget:
  mvp_weeks: 3
  hard_deadline: null
  after_hours_only: true
---

# Taskodoro: Product Requirements

## Vision & Problem Statement

Traditional Pomodoro apps treat the break as a passive countdown: a 5-minute gap the user fills by reaching for their phone, doomscrolling, and losing the momentum the focus session just built. The pain lands on a focus-driven knowledge worker or hobbyist who runs Pomodoros to protect deep work but watches their breaks turn into productivity-killing distractions: forgotten hydration, neglected stretches, no eye rest, no real recovery. Existing Pomodoro apps assume the user fills the break themselves, which is precisely the problem.

The insight is that the break is a recurring forced-interrupt window, a perfect substrate for nudging tiny productive habits into the user's day. A full-screen break presentation surfaces a small set of habits when willpower is at its lowest: one or more always-shown habits the user does every relevant break, a randomized one drawn from a personal pool, and a built-in suggestion when the pool is empty. The randomization rule (filter by which break window is active, exclude already-done daily habits, fall back to a built-in suggestion) is the product's domain decision; the break presentation is the user-visible payoff. Taskodoro stays vendor-neutral by inverting the typical import-from-X pattern: the app owns the break-task pool and exposes an external integration surface so any agent-friendly external client can push tasks INTO the pool from whichever task-tracking system the user already uses. No third-party task manager is privileged inside the app itself.

## User & Persona

Primary persona: a focus-driven knowledge worker or hobbyist who runs Pomodoros to structure deep work and wants their breaks to do something useful instead of evaporating into a phone. They define a small set of break habits inside the app, the randomization rule decides what to surface on each break, and the full-screen break presentation nudges them into doing it. They work on desktop (Windows or Linux first), tolerate the app being offline-only, and prefer a well-randomized handful of habits over a long checklist they would ignore.

A subset of these users are agent-fluent or scripting-comfortable: they may additionally wire up an external client (an AI agent, a personal script, a bridge to whichever task system they keep) that pushes tasks into the break pool through the integration surface. This is a power-user capability, not a persona-defining trait. The primary persona is satisfied by the app alone.

## Success Criteria

### Primary

The first-launch end-to-end loop runs without manual intervention:

1. User opens Taskodoro. The run-mode window shows a 25-minute timer.
2. User clicks Start. The timer counts down.
3. User adds two break tasks from the configuration surface (one always-shown daily "Drink water" applicable to both break windows, one randomized unlimited "10 pushups" applicable to short breaks). Both persist on-disk and reappear after restart.
4. After the configured work duration, the full-screen break presentation appears showing the always-shown task, one randomized task drawn from the pool, a Roll-again action, and an End-break-early action.
5. User marks the always-shown task complete. The check persists for the rest of the day. User ends the break early. The focus cycle resumes.
6. From outside the app, an external client presenting the generated access token calls list, then create, then list again. The new task appears in the configuration surface without restart and is eligible for the next break.

Step 6 is the integration-surface acceptance test; without it, the cross-vendor pitch is unproven.

### Secondary

- A built-in suggestion appears when the randomized pool is empty, so the break presentation never goes blank for a new user.
- The Roll-again action picks a different randomized task from the eligible pool when one is available.
- Timer durations (work, short break, long break, work-sessions-until-long-break) are user-configurable and persist across restarts.

### Guardrails

- The integration surface NEVER accepts requests without a valid access token. An unauthenticated client is rejected at the boundary.
- All user data lives on-device. No outbound network calls are made by the app itself in v1; external clients may make their own outbound calls, but the app does not phone home.
- The break presentation is dismissable. Pressing End-break-early or the Escape key always returns control to the user within one second. The app never traps the user behind an unkillable full-screen surface.

## User Stories

### US-01: First-launch standalone loop

- **Given** a freshly installed Taskodoro on a desktop with no break tasks defined
- **When** the user starts a focus session and, from the task-configuration surface during the session, adds two break tasks: one always-shown daily "Drink water" applicable to both break windows, and one randomized unlimited "10 pushups" applicable to short breaks
- **Then** at the end of the work session the full-screen break presentation appears showing the always-shown task plus one randomized task drawn from the pool, with working Roll-again and End-break-early actions

#### Acceptance Criteria

- The always-shown task appears on every break presentation whose break window matches.
- The randomized slot picks uniformly from eligible tasks.
- Marking the always-shown daily task complete prevents it from being checkable again until the next local midnight.
- Closing and reopening the app preserves both tasks and the day's completion state.

### US-02: External client adds a task

- **Given** Taskodoro is running with a generated access token visible to the user
- **When** an external client connects with that token and creates a new break task by supplying name, category, applicable break window, and the always-shown flag
- **Then** the task appears in the task-configuration surface within one second and is eligible for the next break presentation matching its break window

#### Acceptance Criteria

- A client presenting an invalid token is rejected and no task is created.
- A follow-up list call from the same authorized client returns the new task with the same field values the client supplied.
- Rotating the token causes the original client to be rejected on its next call until it re-authorizes with the new token.

## Functional Requirements

> 14 requirements, all `must-have` for the 3-week MVP. Each carries a `> Socratic:` blockquote capturing the strongest counter-argument considered during shaping and its resolution.

### Timer & Focus Cycle

- FR-001: User can start, pause, and resume a focus session timer at the configured work duration. Priority: must-have
  > Socratic: Counter considered: pause/resume invites users to game the Pomodoro discipline. Resolution: kept; pausing is the user-trusted escape hatch, and removing it would push users to abuse the close affordance instead.

- FR-002: User can configure work duration, short-break duration, long-break duration, and the number of work sessions before a long break. Priority: must-have
  > Socratic: Counter considered: configurability is feature bloat; ship one canonical 25/5/15/4 set and skip the configuration surface. Resolution: kept; meaningful user-data CRUD is a deliverable floor, and timer config is the second-most-edited surface after tasks.

### Break Tasks (CRUD)

- FR-003: User can create a break task with a name, a category (one-time, daily, unlimited), an applicable break window (short, long, both), and an always-shown flag. Priority: must-have
  > Socratic: Counter considered: four type axes is too much for v1; collapse to "task" plus an "always-shown" bool. Resolution: kept; without the break-window axis the break presentation cannot filter, and without the category the daily-reset behaviour collapses.

- FR-004: User can list every break task grouped by always-shown vs randomized buckets, with category and applicable break window visible at a glance. Priority: must-have
  > Socratic: Counter considered: a flat list is simpler. Resolution: kept; the always-shown vs randomized distinction is the user's primary mental model and must be reflected.

- FR-005: User can edit any field of an existing break task. Priority: must-have
  > Socratic: Counter considered: editing is a v2 nicety; users can delete and re-add. Resolution: kept; a real Update operation is part of the deliverable floor, and delete-and-re-add loses today's completion state.

- FR-006: User can delete a break task. Priority: must-have
  > Socratic: Counter considered: keep deleted tasks recoverable for some period. Resolution: kept as immediate removal; v1 has no undo affordance and adding one is its own feature. Recoverable deletion is a v2 candidate if data-loss complaints surface.

### Break Presentation

- FR-007: When a break starts, the app shows a full-screen presentation listing every always-shown task eligible for the current break window plus one randomized task drawn from the eligible pool, or one built-in suggestion if the pool is empty. Priority: must-have
  > Socratic: Counter considered: full-screen is hostile on multi-monitor setups; a focused window is friendlier. Resolution: kept; the premise is that breaks must beat the phone, and a non-full-screen presentation loses the willpower battle on day one. Multi-monitor refinement is parked in Open Questions, not an FR change.

- FR-008: User can mark a task on the break presentation as completed; the completion persists per the task's category rules: daily resets at next local midnight, one-time becomes permanently inert, unlimited remains immediately re-eligible. Priority: must-have
  > Socratic: Counter considered: unlimited tasks should also lock for the current break so the user does not feel pressured to repeat them. Resolution: kept as-written; the user controls whether to repeat, and unlimited's value is exactly that flexibility.

- FR-009: User can invoke Roll-again to swap the randomized task for a different eligible one; the rolled-out task stays in the pool. Priority: must-have
  > Socratic: Counter considered: Roll-again invites rerolling until something trivial comes up, defeating the discipline. Resolution: kept; the user owns their own breaks. If reroll-spam becomes a real complaint, add a per-break reroll cap in v2.

- FR-010: User can end the break early via the End-break-early action or the Escape key; the focus cycle advances to the next session. Priority: must-have
  > Socratic: Counter considered: skipping breaks is the bad behaviour the app exists to prevent. Resolution: kept; trapping users behind a full-screen surface is unacceptable.

- FR-011: When the randomized pool is empty for the current break window, the break presentation shows one built-in suggestion from a shipped read-only list. Priority: must-have
  > Socratic: Counter considered: an empty pool should leave the presentation empty so the user notices they need to add tasks. Resolution: kept; "the presentation never goes blank for a new user" is the first-launch acceptance gate.

### Integration Surface

- FR-012: The app exposes an external integration surface available to clients on the same machine; on first launch a unique access token is generated and visible to the user. Priority: must-have
  > Socratic: Counter considered: a local-only surface does not need a token; the same-machine boundary is enough. Resolution: kept; multiple processes share the same machine, and the token is what makes the app non-anonymous at the integration edge.

- FR-013: An external client presenting a valid token can list tasks, create a task, and mark a task complete. Priority: must-have
  > Socratic: Counter considered: the surface is too small; should also expose update, delete, configuration, and timer state. Resolution: kept tight for v1; three operations prove the inversion pattern. Update/delete are v2 candidates; configuration and timer are out of scope for the integration surface, which is for task data only.

- FR-014: User can rotate the access token; the previous token is invalidated immediately and any client using it must re-authorize with the new token before further calls succeed. Priority: must-have
  > Socratic: Counter considered: rotation is a v2 feature; v1 can ship with one immutable token. Resolution: kept; "no way to rotate a leaked token" is a visible access-control weakness.

## Non-Functional Requirements

- The break presentation appears within 500 ms of the focus-session timer reaching zero on a typical consumer desktop (laptop or tower; low-end single-board computers are out of scope).
- The break presentation returns control to the user within 1 s of an end-break action; this guarantee holds under sustained background CPU load.
- The app remains fully functional when the host machine is offline; no feature in v1 depends on internet access initiated by the app itself.
- An invalid or missing access token presented at the integration boundary is rejected before any task-data operation runs, and the rejection latency is indistinguishable from a valid-but-empty call (no observable timing difference reveals token presence to an outside probe).
- Task and completion state survive a normal app close and a host-machine reboot; data loss requires explicit user action.
- The task-configuration surface remains responsive (operations completing under 200 ms) for pools up to 500 tasks. Larger pools are out of scope.
- The full-screen break presentation does not occupy more than one display unless the user has explicitly opted into a multi-monitor mode (default behaviour is parked in Open Questions).

## Business Logic

**One-sentence rule**: when a break starts, the app shows every always-shown task whose applicable break window matches the current break, plus exactly one randomized task drawn uniformly from the pool of currently eligible (not-already-done-today) tasks, falling back to one built-in suggestion only when the eligible pool is empty.

The rule consumes three user-facing inputs: the user's break-task pool (built by the user inside the app, or pushed in from outside through the integration surface), the current break window (short for breaks between focus sessions, long for the longer break after every fourth session), and a shipped built-in-suggestion list (consulted only as a last-resort fallback). It produces two visual slots in the break presentation: the always-shown list (zero or more tasks shown together) and exactly one variable slot (a randomized task, or one suggestion if no task is eligible). The user encounters the rule every time a break begins; the Roll-again action re-runs the variable-slot selection without re-running the always-shown filter.

Eligibility depends on category. One-time tasks become permanently ineligible after their first completion. Daily tasks become ineligible until the next local midnight after each completion. Unlimited tasks remain perpetually eligible. The randomization is uniform over the eligible set: no preference weighting, no recency penalty, no streak boost in v1. Weighting is a v2 candidate if "the same task keeps appearing three breaks in a row" turns out to be a real complaint.

## Access Control

Single-user desktop application with a local profile: all data lives on-device, no cloud, no app-level user accounts. State and ownership are unambiguous because there is exactly one local user per install. The configuration surface is the boundary for changing app behaviour; other surfaces are read/write over the same local profile.

The external integration surface is gated by a generated access token. The app produces a token on first launch, the user copies it into whichever external client they want to authorize, and the token can be rotated from the configuration surface. Any client that wants to read or modify the break-task pool through the integration surface must present a valid token; unauthenticated clients are rejected at the boundary. This makes the app non-anonymous at its integration edge without inventing app-level user accounts that have no second user to justify them.

## Non-Goals

- **Hosted sync service, cloud accounts, or any state living outside the user's machine.** Settled during shaping. Users who want multi-device sync wire it up themselves through the integration surface.
- **Vendor-specific integrations baked into the app** (named third-party task managers as concrete examples). The integration surface exists so external clients handle bridging; building one inside the app re-creates the coupling just removed.
- **Focus-task linking and external time recording.** Deferred to v2. The integration surface in v1 reads and writes break-task data only, not focus-session state.
- **Non-English locales in v1.** English-only ship. Localization scaffolding is parked as an Open Question.
- **System tray, always-on-top window mode, custom themes.** Window-management nice-to-haves; not on the path to the deliverable floor.
- **Sound effects on session boundaries.** Standard OS notifications are sufficient for v1; in-app audio is a v2 candidate.
- **Rich task details** (description, image, links, estimated time, notes). v1 tasks carry name, category, applicable break window, and the always-shown flag; nothing else. Details are a v2 capability.
- **Dynamic source pools** (filter-based task pools by tag or project) inside the app. External clients can replicate this pattern themselves by maintaining their own filters and pushing the matching tasks in.
- **Manual-pick UI on the break presentation** (for example "after three rerolls, show a chooser"). Roll-again only in v1.
- **Export and import of configuration files.** v1 uses a single on-disk profile; users who want backup can take it through the integration surface or the filesystem.
- **Sub-100 ms randomization for pools larger than 500 tasks.** Performance non-goal; the target persona does not maintain 500 break habits.

## Open Questions

1. **Integration surface protocol choice for v1**: which specific protocol shape does the integration surface speak (agent-integration protocol, local web-API protocol, both)? Owner: user. Resolution path: downstream tech-stack-selection step.
2. **One concrete external importer in v1, or not?** Default proposed during shaping: no, since the integration surface exists so external clients handle bridging. Owner: user. Resolution before v1 implementation begins.
3. **Token rotation UX**: silent disconnect of all clients on rotate, or a list of recently-authenticated clients to revoke selectively? Default proposed: silent disconnect, single token model. Owner: user. Block: no.
4. **Localization scaffolding in v1, or none at all?** Setting up localization early means a second locale is cheap later; skipping it means rework when a second locale ships. Owner: user. Block: no.
5. **Multi-monitor break-presentation default**: full-screen on the active monitor only, or full-screen on every connected monitor? Owner: user. Block: no.
