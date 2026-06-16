# Pomohabits

A desktop Pomodoro timer that turns the break into a productive habit window. User accounts, hosted backend, per-user task sync. Desktop only for v1; other clients are v2.

Traditional Pomodoro apps treat the break as a passive countdown. Pomohabits replaces that with a full-screen break presentation: every time a focus session ends, the app shows the user's always-shown habits plus one randomized habit drawn from their personal pool (falling back to a built-in suggestion when the pool is empty). The randomization rule, eligibility filtering, and daily-reset behaviour are the product's domain decisions; the break presentation is the user-visible payoff. The app is vendor-neutral by design: it owns the break-task pool and exposes a hosted integration endpoint so external clients (agents, scripts, bridges) can push tasks into the pool from whatever system the user already uses. No third-party task manager is privileged inside the app. 3-week after-hours MVP target.

## Project status

Pre-code. The shaping phase is complete (including a Fork B shape change: user accounts and a hosted backend are now in scope for v1). The PRD is drafted and ready for tech-stack selection. No `src/` directory exists yet. Framework and language are deliberately open pending tech-stack selection.

What is here now:
- `context/foundation/shape-notes.md` (discovery output from `/10x-shape`, updated for Fork B)
- `context/foundation/prd.md` (schema-conformant PRD from `/10x-prd`, updated for Fork B)
- `CLAUDE.md` (task router and workflow guide for the shaping chain)

## Repository layout

```
pomohabits/
  CLAUDE.md                         task router for the /10x-* shaping chain
  context/
    foundation/                     living documents that span the whole project
      shape-notes.md                vision, persona, FRs, business logic
      prd.md                        schema-conformant product requirements
      README.md                     foundation-docs conventions
    changes/                        per-change plans, research, and review notes
      README.md
    archive/                        superseded foundation docs (immutable)
      README.md
```

## Workflow chain

```
/10x-init  ->  /10x-shape  ->  /10x-prd  ->  (10x-tech-stack-selector)  ->  (bootstrapper)
   done           done           done               NEXT                       not started
```

Tech-stack selection is the current blocker. It reads `prd.md` (specifically the `product_type` and `tech_preferences` frontmatter fields) and outputs a locked stack decision. Until that runs, no implementation should begin.

## Working with foundation docs

Foundation docs evolve in place. When something changes incrementally, edit the existing file directly. Do not create dated copies.

When a foundation doc is fully superseded by a new approach (not merely refined), move it to `context/archive/YYYY-MM-DD-<doc>.md` and write the replacement at the original path.

`context/archive/` is immutable. Nothing in the workflow reads from it routinely; it is a historical record only. Do not edit files there. If a change would target an archived file, stop and open a new change instead.

Change-scoped artifacts (plans, research, review notes) go under `context/changes/<change-id>/`, not in `context/foundation/`.

## Open questions (from prd.md)

Six questions are unresolved and should be addressed before or during tech-stack selection:

1. **Integration surface protocol**: the hosted integration endpoint speaks a single protocol; the specific protocol shape is parked for tech-stack selection.
2. **External importer in v1**: ship one concrete importer alongside the app, or leave bridging entirely to external clients?
3. **Credential rotation UX**: silent disconnect of all clients on credential invalidation, or selective revocation per client?
4. **Localization scaffolding**: set up i18n scaffolding in v1 (cheap second-locale later), or skip it entirely (rework later)?
5. **Multi-monitor break presentation**: full-screen on the active monitor only, or on every connected monitor?
6. **v1 budget cut needed**: the 3-week after-hours budget did not assume a hosted backend, user accounts, and sync. Identify which one or two must-have FRs to demote (candidates: FR-005, FR-009, FR-014, multi-monitor NFR) before implementation begins.

Question 6 is blocking and must be resolved before implementation starts. Question 1 is resolved in direction (hosted endpoint, single protocol) but the protocol shape itself waits for tech-stack selection.

## Non-goals (load-bearing)

The following are settled non-goals that constrain the integration surface and architecture. See `prd.md` for the full list.

- No offline-first or local-cache mode in v1. The desktop client is online-first; offline operation is a v2 capability.
- No vendor-specific integrations baked into the app. External clients handle bridging; the app exposes the surface.
- No focus-task linking or external time recording in v1. The integration surface is for break-task data only.
- No non-English locales in v1.
- No rich task details (description, image, links, notes) in v1.

## Contributing

The project is pre-code. The most useful contribution right now is reviewing `context/foundation/prd.md` before tech-stack selection locks implementation decisions. In particular, the budget-cut question (open question 6 above) must be resolved with the product owner before any code is written.
