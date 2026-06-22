-- =============================================================================
-- Pomohabits: enable realtime for public.habits
--
-- Two changes needed before Supabase Realtime can deliver habit row changes
-- to Flutter subscribers:
--
-- 1. Publication membership.
--    Supabase Realtime only delivers Postgres WAL events for tables that are
--    members of the `supabase_realtime` publication. No prior migration adds
--    `public.habits` to that publication (verified: no migration contains
--    "publication"). Until this step, every INSERT/UPDATE/DELETE on `habits`
--    is silently invisible to any realtime subscriber.
--    Guard: check pg_publication_tables before adding so re-running the
--    migration is safe.
--
-- 2. Replica identity full.
--    RLS policies on `habits` guard access with `auth.uid() = user_id`.
--    Supabase Realtime evaluates those policies against the old record when
--    authorizing UPDATE and DELETE events. With the default replica identity
--    (primary key only), the old record on UPDATE/DELETE carries only `id`;
--    `user_id` is null, so the policy returns false and the event is silently
--    dropped before it reaches the client. Setting REPLICA IDENTITY FULL
--    exposes the complete old row (including `user_id`), so RLS authorization
--    and the Flutter client's `user_id` filter work correctly for all three
--    event types.
--
-- No change to habit_completions (realtime for completions is out of scope).
-- =============================================================================

-- Publication membership (guarded against double-add) -------------------------

do $$
begin
  if not exists (
    select 1
    from   pg_publication_tables
    where  pubname   = 'supabase_realtime'
      and  schemaname = 'public'
      and  tablename  = 'habits'
  ) then
    alter publication supabase_realtime add table public.habits;
  end if;
end $$;

-- Replica identity ------------------------------------------------------------

alter table public.habits replica identity full;
