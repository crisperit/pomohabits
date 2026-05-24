---
project: Taskodoro
researched_at: 2026-05-23
recommended_platform: Supabase Edge Functions
runner_up: Cloudflare Workers
context_type: mvp
tech_stack:
  language: TypeScript (Deno) for the MCP endpoint; Dart/Flutter for clients; TypeScript/Astro 6 for landing
  framework: MCP (Streamable HTTP), Supabase (Postgres + Auth + Realtime), Astro 6 SSR
  runtime: Deno (Edge Functions); Flutter (clients); Cloudflare Workers (landing - see Note on Pages deprecation)
---

## Recommendation

**Deploy the MCP integration endpoint on Supabase Edge Functions.**

The endpoint is a small TypeScript MCP server (Streamable HTTP) exposing `list_tasks` / `add_task` / `complete_task` to external clients, gated by Supabase Auth JWTs. Hosting it on Supabase Edge Functions keeps the integration endpoint in the same vendor and same region as Postgres and Auth - `supabase.auth.getUser(token)` is a one-line check because the function shares Auth context; DB round-trip is single-digit ms; and the operational surface is one CLI (`supabase`), one dashboard, one set of credentials. This matches the existing `context/foundation/tech-stack.md` pin; the research confirmed it against current 2025-2026 capability data.

## Platform Comparison

Scoring against the five criteria in `references/agent-friendly-criteria.md` (Pass / Partial / Fail), after applying the persistent-connections hard filter (none - Q1 = stateless) and soft weights from the interview (Q3 Cloudflare familiarity, Q5 co-location preferred).

| Platform | CLI-first | Managed | Agent-readable docs | Stable deploy API | MCP integration | Notes |
|---|---|---|---|---|---|---|
| **Supabase Edge Functions** | Pass | Pass | Pass | Partial | Partial | One vendor with DB/Auth/Realtime; no native rollback (`git checkout && redeploy`); native JWT-for-MCP integration in "coming soon" status (2026-05-23) |
| **Cloudflare Workers** | Pass | Pass | Pass | Pass | Pass | `wrangler rollback` GA; `@cloudflare/workers-oauth-provider` GA v0.7.0; cross-region hop to Supabase; $5/mo Paid tier needed (Free 10ms CPU cap) |
| **Vercel** | Pass | Pass | Pass | Pass | Partial | `withMcpAuth` callback fits Supabase JWT verify; Vercel MCP server Public Beta; Hobby tier hard-caps without overage |
| **Netlify** | Pass | Pass | Fail | Pass | Pass | Netlify MCP server GA; docs not open-source markdown; SSR routes need `middlewareMode: 'edge'` for headers/redirects |
| **Fly.io** | Pass | Partial | Pass | Partial | Partial | Container-based (Dockerfile required); `fly mcp` experimental; multi-second cold starts on auto-stop; no PR previews |
| **Railway** | Pass | Pass | Pass | Partial | Pass | Persistent Node.js process; first-party MCP server GA; Hobby $5/mo covers both services; recurring reliability incidents reported |
| **Render** | Pass | Pass | Partial | Pass | Pass | $14/mo minimum for two services on Starter (Free spins down after 15 min); docs not open-source markdown |

### Shortlisted Platforms

#### 1. Supabase Edge Functions (Recommended)

Wins on co-location (Q5) and the operational simplicity that the existing tech-stack.md already calls out: one CLI, one dashboard, one Auth context. After the 2025 blocking-pool / persistent-storage improvement, cold starts are P95 86 ms / P99 460 ms - production-fine. The official "BYO MCP" guide (`https://supabase.com/docs/guides/getting-started/byo-mcp`) gives a working template with the MCP TypeScript SDK + Hono + Streamable HTTP. Pricing fits MVP well within free tier (500k invocations/mo). The two real limits - 2s CPU per request and 20MB ESZip post-bundle - are not constraints for the v1 surface but are surfaced as risks below.

#### 2. Cloudflare Workers (Runner-up; held as future migration target)

The strongest agent-ops story across the candidate pool: real `wrangler rollback` against versioned deployments, scoped `llms.txt` / `llms-full.txt` per product, 16 first-party MCP servers (docs, observability, AI Gateway, etc.), and `@cloudflare/workers-oauth-provider` GA v0.7.0 for spec-compliant MCP OAuth if Taskodoro ever exposes the endpoint to third-party agents. The user is hands-on familiar (Q3). Reasons it loses to Supabase Edge Functions at MVP: a second vendor adds a deployment surface, the Worker→Supabase call is a cross-region hop, and the Free tier 10ms CPU cap means the $5/mo Paid tier is required from day one. The migration triggers already listed in tech-stack.md (AI Gateway, Workers AI, Vectorize, spec-compliant MCP OAuth) remain the right reasons to revisit.

#### 3. Vercel

Clean fit for the actual workloads - `@astrojs/vercel` GA for Astro 6, `mcp-handler` package GA with `withMcpAuth` callback that wires Supabase JWT verification in a few lines, and Hobby tier (100 GB bandwidth, 1M edge requests, 4h active CPU) covers MVP traffic. The reasons it doesn't win: it doesn't co-locate with Supabase, the user is not familiar with it, and the Hobby tier hard-caps without overage (which is either a cost-safety feature or an availability risk depending on perspective). Strong third place; not a current pick.

## Anti-Bias Cross-Check - Supabase Edge Functions

### Devil's advocate - weaknesses

1. **No native rollback.** "git checkout <sha> && supabase functions deploy mcp" is the documented path. Fine, until a Friday outage where the script doesn't exist yet.
2. **Native JWT-for-MCP integration is "coming soon" as of 2026-05-23.** Hand-rolled `supabase.auth.getUser(token)` works today but becomes legacy code once the native integration ships; the migration carries cutover risk.
3. **2-second CPU cap is hard.** Not wall-clock. Fine for three Postgres RPCs; squeezes once structured logging + retry + tracing are added.
4. **20MB ESZip deployment limit.** Today's bundle fits comfortably; one observability library can erode the margin.
5. **Single-vendor blast radius.** A Supabase regional outage takes DB, Auth, Realtime, and the MCP endpoint together. Cloudflare-on-top-of-Supabase would split the blast radius.
6. **Deno-only narrows the ecosystem.** Most TypeScript MCP tooling assumes Node; `npm:` specifiers bridge it but native bindings and a few popular libs do not run.

### Pre-mortem - how this could fail

Six months in, the MCP server grew: structured logging, an OTel exporter, a retry helper for Postgres, and the function pushed against the 20MB ESZip limit. Supabase shipped native MCP auth in beta and the API changed three times, breaking the hand-rolled auth path each cycle. During a Friday production incident a broken deploy needed rollback - there was no `wrangler rollback` equivalent and the team git-bisected the functions directory under pressure. The 2s CPU cap bit during a traffic spike when a stalled Postgres query burned the budget, returning 500s instead of timing out gracefully. The "held as future migration" Cloudflare path turned out to take three weeks because the auth code had drifted from being portable. The cross-region latency they had worried about was never measurable at MVP scale.

### Unknown unknowns

1. **Cloudflare Pages is in maintenance-only mode for new projects (deprecated April 2025).** The landing-page side of tech-stack.md references Cloudflare Pages, but Cloudflare's official guidance is **Workers + Static Assets** for new projects. Worth a tech-stack note even though Edge Functions stays for the MCP endpoint.
2. **Supabase 2s CPU cap ≠ Workers 10ms/30s CPU cap.** Different mental model. There is no Edge-Functions equivalent of "queue heavy work to a Durable Object." Plan accordingly.
3. **Astro 6 adapter GA wave (March 2026) is ~3 months old across Vercel/Netlify/Cloudflare.** Bug-fix curves are still rising. Vercel's adapter has the largest user base and likely surfaces gotchas fastest.
4. **Secret rotation is not silent (FR-014 implications).** Rotating Supabase keys requires both an Edge Function redeploy and a new Flutter build; there is no out-of-band rotation that skips a client release. Flag during FR-014 implementation.
5. **Free-tier Workers CPU cap (10ms) will bite a future migration if attempted on Free.** Plan on $5/mo Paid from day one if Cloudflare becomes the host.
6. **Split-surface lockstep.** Per tech-stack.md, Flutter calls PostgREST RPC directly; the Edge Function exposes the same three SQL functions to external clients. A signature change to `list_tasks` / `add_task` / `complete_task` must update both surfaces in the same migration.

## Operational Story

How Supabase Edge Functions actually operates day to day for the MCP endpoint.

- **Preview deploys**: No platform-native PR previews. Convention is a separate Supabase project for staging (`taskodoro-staging`) with its own URL/keys; CI deploys feature branches to staging. Production deploys happen from main only.
- **Secrets**: Stored as Supabase function secrets (`supabase secrets set NAME=value`) and as GitHub Actions repository secrets for CI. The Flutter client receives the public anon URL/key at compile time via `--dart-define` (see `SETUP.md`); rotation requires a Flutter rebuild.
- **Rollback**: No native rollback. Scripted git path: `git checkout <prior-sha> -- supabase/functions/mcp && supabase functions deploy mcp`. Add a one-line wrapper script to `package.json` or a Makefile target before first production deploy so the recipe is not invented under pressure. Postgres migrations do not auto-roll back; treat schema changes as forward-only and design migrations to be backwards-compatible across at least one Edge Function revision.
- **Approval**: Edge Function deploys to production require a human-merged main commit. Database migrations (`landing/supabase/migrations/`) and secret rotations require an explicit run; not unattended. Schema drops or auth provider changes always require user confirmation. An agent may run `supabase functions deploy` against staging unattended.
- **Logs**: Agent reads via `supabase functions logs <name> --project-ref <ref>` (streaming with `--follow`) or the management API. The Supabase MCP server (v0.8.1, beta - `supabase-community/supabase-mcp`) exposes function logs as a structured tool, but is explicitly "designed for development and testing purposes only" - do not wire it into production agent flows yet.

## Risk Register

| Risk | Source | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| No native rollback; ad-hoc git redeploy fails under pressure | Devil's advocate / Pre-mortem | M | H | Script the git-based rollback before first prod deploy: `scripts/rollback-function.sh <name> <sha>`. Document in `SETUP.md`. Tag every prod deploy with `git tag prod-mcp-YYYYMMDD-HHmm`. |
| Hand-rolled JWT verification breaks when native MCP-auth integration ships | Devil's advocate / Pre-mortem | M | M | Keep the auth check in a single helper module (`_shared/auth.ts`) so the cutover is one file. Subscribe to Supabase release notes / changelog; reassess when native MCP auth leaves "coming soon" status. |
| 2s CPU cap hit by accumulated middleware (logging, retries, tracing) | Devil's advocate | L (v1) / M (v2) | M | Budget CPU on each handler. Avoid synchronous JSON-walking in middleware. If observability bloats CPU, offload to fire-and-forget HTTP POST to an external collector, not in-process processing. |
| 20MB ESZip deployment limit reached after adding observability | Devil's advocate | L (v1) / M (v2) | M | Track post-bundle size in CI as a soft gate (`du -h .supabase/functions/mcp.eszip`). Pin a 16MB warning threshold. Prefer thin libraries (mcp-lite over full SDK) when feasible. |
| Single-vendor outage takes DB + Auth + Realtime + MCP together | Devil's advocate / Pre-mortem | L (Supabase has solid uptime) | H | Accept for v1 - splitting the blast radius means adopting Cloudflare Workers, which is held as a known migration target. Set an SLO of 99.5% and revisit only if breached. |
| Deno ecosystem limitation blocks a future library choice | Devil's advocate | L | L | Surface during library selection. If a Node-only lib is genuinely load-bearing, that becomes a CF Workers migration trigger. |
| Astro 6 + adapter bug churn in Apr-Jul 2026 affects landing-page deploys | Unknown unknowns | M | L (landing-only) | Pin `@astrojs/cloudflare` (or whichever adapter survives the Pages → Workers transition) to a specific minor version. Read changelog before bumping. |
| Cloudflare Pages deprecation affects landing-page host before MVP ships | Unknown unknowns | M | M | Switch the landing-page deploy target from Cloudflare Pages to **Workers + Static Assets** before standing up the landing CI. Update `landing/CLAUDE.md` and `context/foundation/tech-stack.md` to reflect this. |
| FR-014 secret rotation requires Flutter rebuild | Unknown unknowns | M (when rotation happens) | M | Document the rotation procedure in `SETUP.md`. Treat key rotation as a release event, not a runtime operation. Plan a "kill switch" approach that uses Supabase Auth's session-invalidation rather than rotating the anon key. |
| Split-surface (PostgREST + Edge Function) signature drift | Unknown unknowns | M | M | Keep the three SQL function signatures defined in a single migration file. Add a CI check that grepping the Edge Function source for `list_tasks` / `add_task` / `complete_task` finds matching parameter shapes. |

## Getting Started

Validated against `supabase` CLI v2 docs and the official BYO-MCP guide as of 2026-05-23.

1. **Confirm the Supabase project exists and is linked.** `SETUP.md` should already document `supabase link --project-ref <ref>`. If not, run `supabase login` then `supabase link --project-ref <ref>` from the repo root.
2. **Scaffold the Edge Function.** From repo root: `supabase functions new mcp` - creates `supabase/functions/mcp/index.ts`.
3. **Implement the MCP server from the official template.** Follow `https://supabase.com/docs/guides/getting-started/byo-mcp` for the MCP TypeScript SDK + Hono + `WebStandardStreamableHTTPServerTransport` skeleton, OR `https://supabase.com/docs/guides/functions/examples/mcp-server-mcp-lite` for the lighter mcp-lite alternative. Wire `list_tasks` / `add_task` / `complete_task` as MCP tools, each delegating to the existing PostgREST RPC. Implement Bearer-token extraction + `supabase.auth.getUser(token)` in a single `_shared/auth.ts` helper. Set `verify_jwt = false` for the `mcp` function in `supabase/config.toml` (auth is handled in handler code, not the platform gate).
4. **Pin the function region to the Postgres region.** In `supabase/config.toml` set `[functions.mcp] region = "<region-matching-project>"` to keep DB round-trips in single-digit ms.
5. **Add the rollback script.** Create `scripts/rollback-function.sh` that takes `<name> <sha>` and runs `git checkout <sha> -- supabase/functions/<name> && supabase functions deploy <name> && git checkout HEAD -- supabase/functions/<name>`. Document in `SETUP.md`.
6. **First production deploy.** `supabase functions deploy mcp --project-ref <prod-ref>`. Tag the commit: `git tag prod-mcp-<YYYYMMDD-HHmm> && git push --tags`.

## Out of Scope

The following were not evaluated in this research:
- Docker image configuration (Edge Functions are not container-based; Fly/Railway/Render were evaluated but not chosen).
- CI/CD pipeline setup (GitHub Actions wiring for `supabase functions deploy` is implementation work, not infra selection).
- Production-scale architecture (multi-region failover, dedicated Postgres pooler tuning, SLA commitments, HA / DR plans).
- LLM-calling endpoints (parked as a v2 capability in tech-stack.md; would land as additional Edge Functions or trigger a Cloudflare Workers migration depending on AI Gateway / Workers AI fit).
- The landing-page Astro host migration from Cloudflare Pages to Cloudflare Workers + Static Assets (surfaced in the risk register; full evaluation belongs in a tech-stack.md update).
