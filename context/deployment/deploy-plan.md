---
project: taskodoro
plan_date: 2026-05-24
artifacts:
  - mcp-edge-function
  - astro-landing
sources:
  - context/foundation/infrastructure.md
  - context/foundation/tech-stack.md
  - landing/SETUP.md
context_type: deployment-plan
status: approved-for-execution
---

# Taskodoro First Production Deploy: Plan

This is a **Plan Mode deploy** artifact per the project's CLAUDE.md workflow.
It is the audit trail of "what was supposed to happen" for the first production
deploy. Downstream milestone planning consumes it as ground truth for what is
already deployed and which secrets are wired.

No platform-mutating commands were run while authoring this plan. The plan
describes commands; executing section 4 happens in a separate session, against
the developer machine, with the human at the keyboard for the manual gates in
section 3.

## 1. Scope and order of operations

Two artifacts ship in this first deploy, in this order:

1. **MCP Edge Function** (`mcp`) on Supabase Edge Functions. Primary
   `infrastructure.md` recommendation; FR-012 / FR-013 surface.
2. **Astro landing page** on Cloudflare Workers + Static Assets. Needed in
   production so auth flows have a hosted callback URL; depends on Supabase
   being live first.

Out of scope for this first deploy (deferred):

- Flutter client app distribution (GitHub Releases, AppImage/APK).
- Staging Supabase project (`taskodoro-staging`).
- Automated GitHub Actions deploy. CI today is lint + build only; keep that
  until the first manual prod deploy succeeds.
- LLM-calling endpoints (v2 in `tech-stack.md`).

## 2. Pre-deploy gap fixes (must land before any production command)

These are commits the developer or implementer makes locally, on a branch,
**before** running any platform-mutating command. They resolve the gaps found
when checking `infrastructure.md`'s "Getting Started" section against the
current repo state.

1. **Resolve Supabase-project location.** Standardize on `landing/supabase/`
   (where migrations already live). Update `SETUP.md` section 7 and
   `infrastructure.md` "Getting Started" step 2 to say
   `cd landing && npx supabase functions new mcp`. The function source lives
   at `landing/supabase/functions/mcp/index.ts` (NOT repo-root
   `supabase/functions/`). The shared auth helper lives at
   `landing/supabase/functions/_shared/auth.ts`. All `supabase` CLI commands
   run from `landing/`.

2. **Add `[functions.mcp]` block to `landing/supabase/config.toml`:**
   - `verify_jwt = false` (auth runs in handler code, not at the platform
     gate, so the function can return MCP-style errors instead of opaque 401s).
   - `region = "<region-matching-prod-project>"`. Value pulled from the
     Supabase dashboard after step 3.1 below; placeholder until then.

3. **Rename Workers app.** Edit `landing/wrangler.jsonc` `"name"` from
   `10x-astro-starter` to `taskodoro-landing` so the deploy URL is
   `https://taskodoro-landing.<account>.workers.dev`. One-line change; verify
   with `npx wrangler deploy --dry-run` before committing.

4. **Create the rollback script.** `scripts/rollback-function.sh` at repo
   root, exactly as `SETUP.md` section 8 specifies. `chmod +x`. The script
   `cd`s into `landing/` before running `supabase`.

5. **Update `landing/CLAUDE.md`** to replace any remaining Cloudflare Pages
   references with Workers + Static Assets. Risk register item in
   `infrastructure.md`.

6. **Address `npm audit` high-severity findings.** Run
   `cd landing && npm audit` to refresh the report. Either add `overrides`
   to `landing/package.json` pinning the affected transitive deps to patched
   versions, OR explicitly accept the risk in a one-line note in
   `landing/CLAUDE.md` "Known constraints" citing today's date and the
   upstream Astro issue. Do not proceed to landing-page production deploy
   with un-triaged highs.

**Verification gate before proceeding:**
`cd landing && npm run lint && npm run build` must pass with the renamed app
and updated config.

## 3. Manual setup gates (human-only, not agent-executable)

These are intentionally not scripted. The cost of a click is 30 seconds; the
cost of a wrong scripted mutation is hours.

1. **Create production Supabase project** (if not already present).
   Dashboard → New project, name `taskodoro`, region matching expected user
   base (recommendation: `eu-central-1` or `eu-west-1` for EU latency;
   document the chosen region back into step 2.2 above). Note: project URL,
   anon key, project ref, DB password.

2. **Set Supabase auth provider.** Authentication → Providers → Email
   enabled. Email confirmations: **enabled** for production (different from
   local dev). The production Site URL is set in step 4.h below, after the
   landing URL exists.

3. **Create Cloudflare account** (or confirm existing). Note the account ID.
   No DNS record changes yet; the default `*.workers.dev` URL is the
   first-deploy target. Custom domain is a follow-up.

4. **Generate Cloudflare API token** scoped to "Edit Cloudflare Workers" on
   the relevant account only. Save in 1Password / equivalent secret store.
   This credential stays human-managed for first deploy. CI wiring is a
   follow-up; first deploy is local-`wrangler` from the developer machine.

5. **Confirm prod Supabase project ref, URL, and anon key** are recorded in
   the developer's secret store (NOT committed). Needed for `.env`,
   `--dart-define`, and `wrangler secret put` in the steps below.

Schema drops, auth provider changes, and Cloudflare DNS edits remain
manual-only beyond this first deploy.

## 4. Deploy steps (exact commands, in order)

All commands run from `/home/crispy/dev/private/taskodoro` unless noted.
Replace `<PROD_REF>`, `<URL>`, `<ANON_KEY>`, `<REGION>` with values captured
in section 3.

### a. Link local repo to prod Supabase project

```bash
cd landing
npx supabase login                                   # one-time, browser
npx supabase link --project-ref <PROD_REF>           # prompts for DB password
```

### b. Push schema migration to production

```bash
# Still in landing/
npx supabase db push                                 # applies 20260522170000_initial_schema.sql
```

Verify in dashboard → Database → Tables: `tasks` and `task_completions` exist
under `public`, both with RLS enabled, and `list_tasks` / `add_task` /
`complete_task` appear under Functions.

### c. Pin the function region

```toml
# landing/supabase/config.toml
[functions.mcp]
verify_jwt = false
region = "<REGION>"
```

Commit this change before deploying the function.

### d. Scaffold and implement the MCP function

```bash
# In landing/
npx supabase functions new mcp
# Edit landing/supabase/functions/mcp/index.ts following
# https://supabase.com/docs/guides/getting-started/byo-mcp
# (MCP TypeScript SDK + Hono + WebStandardStreamableHTTPServerTransport)
# Create landing/supabase/functions/_shared/auth.ts with the
# supabase.auth.getUser(token) helper.
```

Local smoke test:

```bash
npx supabase functions serve mcp --env-file ./supabase/functions/.env.local
# In another shell: curl with a real session JWT to
# http://127.0.0.1:54321/functions/v1/mcp
```

### e. Deploy the MCP function to production

```bash
# In landing/
npx supabase functions deploy mcp --project-ref <PROD_REF>
```

Tag the deploy (from repo root):

```bash
git tag prod-mcp-$(date +%Y%m%d-%H%M)
git push --tags
```

### f. Configure landing-page production secrets

```bash
cd landing
npx wrangler login                                   # one-time, browser
npx wrangler secret put SUPABASE_URL                 # paste <URL>
npx wrangler secret put SUPABASE_KEY                 # paste <ANON_KEY>
```

### g. Deploy the landing page

```bash
# In landing/
npx wrangler deploy
```

Output prints the live URL. Capture it as `<LANDING_URL>` (e.g.
`https://taskodoro-landing.<account>.workers.dev`).

### h. Wire the landing URL back into Supabase auth

Dashboard → Authentication → URL Configuration:

- Site URL = `<LANDING_URL>`
- Redirect URLs += `<LANDING_URL>/auth/callback`,
  `<LANDING_URL>/auth/confirm-email`

This step is manual on purpose (auth config touches user-facing flows).

## 5. Verification (end-to-end)

The deploy is "done" when **all** of the following pass against production:

1. **Schema reachable.** Dashboard SQL editor:
   `select count(*) from public.tasks;` returns `0` (table exists; RLS denies
   via service-role context, which is expected).
2. **MCP function alive (unauth).**
   `curl -sS https://<PROD_REF>.supabase.co/functions/v1/mcp -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"initialize"}'`
   returns `401` (auth helper rejects missing Bearer token; proves the
   handler is running).
3. **MCP function works (auth).** Log into the landing page in a browser,
   copy the session JWT from devtools, then `curl` the same endpoint with
   `Authorization: Bearer <jwt>` and `method: tools/list`. Expect
   `list_tasks`, `add_task`, `complete_task` in the response.
4. **Landing page loads.**
   `curl -sS -o /dev/null -w '%{http_code}' <LANDING_URL>` returns `200`.
   Browser smoke: signup, confirm-email, signin, dashboard renders.
5. **Logs flow.**
   `cd landing && npx supabase functions logs mcp --project-ref <PROD_REF> --follow`
   shows entries from the curl above.
6. **Rollback works.** Dry-run the rollback script against the deploy tag
   from step e:
   `./scripts/rollback-function.sh mcp prod-mcp-<TS>` (then redeploy current
   to restore). Do this once on first deploy to prove the recipe runs;
   future rollbacks are real.

If any of steps 1 to 5 fail, do **not** proceed to wire CI deploy automation or
distribute the Flutter client. Triage; the deploy is not "done".

## 6. Rollback procedure (if a step in section 4 goes sideways)

- **Failed `supabase db push`.** Do NOT auto-revert. Postgres migrations are
  forward-only by convention. Inspect the error, fix the migration file,
  re-push. If a partial schema change landed, the recovery is to write a
  forward migration that brings the schema to the intended state, NOT a
  `down` migration.
- **Failed `supabase functions deploy mcp`.** The previous version is still
  live (deploy is atomic). Fix the source, redeploy. No rollback needed.
- **Bad MCP function reached prod** (verification step 3 fails):
  `./scripts/rollback-function.sh mcp <prior-prod-tag-sha>`.
- **Failed `wrangler deploy`.** The previous version is still live (Workers
  deploys are atomic). Fix the source, redeploy. Use
  `npx wrangler deployments list` to confirm the active version.
- **Bad landing reached prod.**
  `cd landing && npx wrangler rollback` (Workers has native rollback,
  unlike Edge Functions).
- **Wrong auth Site URL set.** Revert in dashboard immediately; no code
  change needed.

## 7. Risk register pull-through

Explicit mapping from `infrastructure.md` risk-register rows to the section
of this plan that addresses each, so the audit trail is traceable.

| `infrastructure.md` risk | Addressed by this plan |
|---|---|
| No native rollback; ad-hoc git redeploy fails under pressure | Section 2.4 creates the script; section 5.6 dry-runs it on first deploy. |
| Hand-rolled JWT verification breaks when native MCP-auth ships | Section 4.d puts auth in `_shared/auth.ts` (single file to swap). |
| Cloudflare Pages deprecation affects landing-page host | Section 1 explicitly deploys to Workers + Static Assets, not Pages; section 2.5 fixes lingering doc references. |
| FR-014 secret rotation requires Flutter rebuild | Section 3.5 records secrets in a developer secret store; rotation procedure stays in `SETUP.md` (out of scope for first deploy, flagged here for future). |
| Split-surface (PostgREST + Edge Function) signature drift | Section 4.d implements MCP tools as thin wrappers over the three RPC functions; no signature divergence on first deploy. |
| Astro 6 + adapter bug churn | Section 2.6 triages `npm audit`; adapter version pinning is a follow-up (file an issue, not a blocker for first deploy). |

**Risks explicitly accepted** (not mitigated by this plan; tracked for
revisit, not addressed now):

- Single-vendor blast radius (Supabase outage takes everything).
- 2s CPU cap / 20MB ESZip cap (v1 budget is comfortable).
- Deno ecosystem narrowing.

## 8. Out of scope for this plan (deferred to later changes)

- **Staging Supabase project** (`taskodoro-staging`). Convention noted in
  `infrastructure.md` "Operational Story" but not required for first deploy.
  Add when the team starts merging without manual prod smoke.
- **GitHub Actions auto-deploy** on push to `main`. Current CI is lint +
  build only; keep it that way until first manual deploy succeeds.
- **Custom domain on Cloudflare.** First deploy uses `*.workers.dev`; custom
  domain is a follow-up that needs DNS + Supabase auth-URL updates together.
- **Flutter client distribution** (Linux AppImage, Android APK via GitHub
  Releases). Separate change.
- **Dart codegen from Supabase schema** (`supabase_codegen`). `SETUP.md`
  flags as optional.
- **LLM-calling endpoints** (v2 in `tech-stack.md`).
