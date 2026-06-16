-- =============================================================================
-- Pomohabits: rename task surface to habit
--
-- Hard cutover: renames all "task"-named Postgres objects to "habit" names.
-- No forwarding aliases are created (production is empty and unused).
--
-- Objects renamed:
--   Enums:   task_category -> habit_category
--            task_break_window -> habit_break_window
--   Tables:  public.tasks -> public.habits
--            public.task_completions -> public.habit_completions
--   Column:  public.habit_completions.task_id -> habit_id
--   Indexes: tasks_user_id_idx -> habits_user_id_idx
--            task_completions_task_id_completed_at_idx ->
--              habit_completions_habit_id_completed_at_idx
--            task_completions_user_id_idx -> habit_completions_user_id_idx
--   Trigger: tasks_set_updated_at -> habits_set_updated_at
--   Policies: four tasks: + two task_completions: -> habits: / habit_completions:
--   RPCs:    list_tasks -> list_habits
--            add_task   -> add_habit
--            complete_task -> complete_habit
--
-- Ordering: DROP old RPCs first (while old type names still exist in their
-- signatures), THEN rename types/tables/etc., THEN CREATE new RPCs.
-- Idempotency guards are applied throughout so a re-run does not error.
-- =============================================================================

-- Drop old RPCs first (current live signatures, after the icon migration) ----
-- Must drop before renaming enums: the old signatures reference task_category
-- and task_break_window by name; renaming those types first would make a later
-- DROP FUNCTION fail with "type does not exist".

drop function if exists public.list_tasks(text);
drop function if exists public.add_task(text, task_category, task_break_window, boolean, text);
drop function if exists public.complete_task(uuid);

-- Rename enums ----------------------------------------------------------------

do $$ begin
  if exists (
    select 1 from pg_type where typname = 'task_category'
  ) and not exists (
    select 1 from pg_type where typname = 'habit_category'
  ) then
    alter type task_category rename to habit_category;
  end if;
end $$;

do $$ begin
  if exists (
    select 1 from pg_type where typname = 'task_break_window'
  ) and not exists (
    select 1 from pg_type where typname = 'habit_break_window'
  ) then
    alter type task_break_window rename to habit_break_window;
  end if;
end $$;

-- Rename tables ---------------------------------------------------------------

do $$ begin
  if to_regclass('public.tasks') is not null then
    alter table public.tasks rename to habits;
  end if;
end $$;

do $$ begin
  if to_regclass('public.task_completions') is not null then
    alter table public.task_completions rename to habit_completions;
  end if;
end $$;

-- Rename column on habit_completions ------------------------------------------

do $$ begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'habit_completions'
      and column_name  = 'task_id'
  ) then
    alter table public.habit_completions rename column task_id to habit_id;
  end if;
end $$;

-- Rename indexes --------------------------------------------------------------

do $$ begin
  if exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'tasks_user_id_idx'
  ) then
    alter index public.tasks_user_id_idx rename to habits_user_id_idx;
  end if;
end $$;

do $$ begin
  if exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and indexname = 'task_completions_task_id_completed_at_idx'
  ) then
    alter index public.task_completions_task_id_completed_at_idx
      rename to habit_completions_habit_id_completed_at_idx;
  end if;
end $$;

do $$ begin
  if exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'task_completions_user_id_idx'
  ) then
    alter index public.task_completions_user_id_idx
      rename to habit_completions_user_id_idx;
  end if;
end $$;

-- Rename trigger on habits ----------------------------------------------------

drop trigger if exists tasks_set_updated_at on public.habits;
drop trigger if exists habits_set_updated_at on public.habits;
create trigger habits_set_updated_at
  before update on public.habits
  for each row execute function public.set_updated_at();

-- Rename RLS policies ---------------------------------------------------------
-- Drop + recreate pattern (matches the existing migration style).

-- habits (was tasks) ----------------------------------------------------------

drop policy if exists "tasks: owner can select" on public.habits;
drop policy if exists "habits: owner can select" on public.habits;
create policy "habits: owner can select" on public.habits
  for select using (auth.uid() = user_id);

drop policy if exists "tasks: owner can insert" on public.habits;
drop policy if exists "habits: owner can insert" on public.habits;
create policy "habits: owner can insert" on public.habits
  for insert with check (auth.uid() = user_id);

drop policy if exists "tasks: owner can update" on public.habits;
drop policy if exists "habits: owner can update" on public.habits;
create policy "habits: owner can update" on public.habits
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "tasks: owner can delete" on public.habits;
drop policy if exists "habits: owner can delete" on public.habits;
create policy "habits: owner can delete" on public.habits
  for delete using (auth.uid() = user_id);

-- habit_completions (was task_completions) ------------------------------------

drop policy if exists "task_completions: owner can select" on public.habit_completions;
drop policy if exists "habit_completions: owner can select" on public.habit_completions;
create policy "habit_completions: owner can select" on public.habit_completions
  for select using (auth.uid() = user_id);

drop policy if exists "task_completions: owner can insert" on public.habit_completions;
drop policy if exists "habit_completions: owner can insert" on public.habit_completions;
create policy "habit_completions: owner can insert" on public.habit_completions
  for insert with check (auth.uid() = user_id);

-- Create new RPCs -------------------------------------------------------------

drop function if exists public.list_habits(text);

-- list_habits: returns the caller's habits with "completed_today" computed in
-- the caller-supplied IANA timezone (default UTC). Clients pass their local
-- zone so the daily reset boundary matches the user's wall clock.
create function public.list_habits(p_timezone text default 'UTC')
returns table (
  id uuid,
  name text,
  category habit_category,
  applicable_break_window habit_break_window,
  always_shown boolean,
  icon text,
  created_at timestamptz,
  updated_at timestamptz,
  completed_today boolean,
  completed_ever boolean
)
language sql
security invoker
set search_path = public
as $$
  select
    h.id,
    h.name,
    h.category,
    h.applicable_break_window,
    h.always_shown,
    h.icon,
    h.created_at,
    h.updated_at,
    exists (
      select 1 from public.habit_completions c
      where c.habit_id = h.id
        and c.user_id = auth.uid()
        and c.completed_at >= (date_trunc('day', now() at time zone p_timezone) at time zone p_timezone)
        and c.completed_at <  (date_trunc('day', now() at time zone p_timezone) at time zone p_timezone) + interval '1 day'
    ) as completed_today,
    exists (
      select 1 from public.habit_completions c
      where c.habit_id = h.id and c.user_id = auth.uid()
    ) as completed_ever
  from public.habits h
  where h.user_id = auth.uid()
  order by h.always_shown desc, h.created_at asc;
$$;

drop function if exists public.add_habit(text, habit_category, habit_break_window, boolean, text);

-- add_habit: inserts a new habit scoped to the caller. Returns the inserted row.
create function public.add_habit(
  p_name text,
  p_category habit_category,
  p_applicable_break_window habit_break_window,
  p_always_shown boolean,
  p_icon text default null
)
returns public.habits
language plpgsql
security invoker
set search_path = public
as $$
declare
  inserted public.habits;
begin
  if auth.uid() is null then
    raise exception 'add_habit requires an authenticated session';
  end if;
  insert into public.habits (user_id, name, category, applicable_break_window, always_shown, icon)
  values (auth.uid(), p_name, p_category, p_applicable_break_window, coalesce(p_always_shown, false), p_icon)
  returning * into inserted;
  return inserted;
end;
$$;

drop function if exists public.complete_habit(uuid);

-- complete_habit: records a completion event for the given habit, scoped to caller.
create function public.complete_habit(p_habit_id uuid)
returns public.habit_completions
language plpgsql
security invoker
set search_path = public
as $$
declare
  habit_owner uuid;
  inserted public.habit_completions;
begin
  if auth.uid() is null then
    raise exception 'complete_habit requires an authenticated session';
  end if;
  select user_id into habit_owner from public.habits where id = p_habit_id;
  if habit_owner is null then
    raise exception 'habit not found' using errcode = 'P0002';
  end if;
  if habit_owner <> auth.uid() then
    raise exception 'habit does not belong to caller' using errcode = '42501';
  end if;
  insert into public.habit_completions (habit_id, user_id)
  values (p_habit_id, auth.uid())
  returning * into inserted;
  return inserted;
end;
$$;

-- Grants ----------------------------------------------------------------------

grant execute on function public.list_habits(text) to authenticated;
grant execute on function public.add_habit(text, habit_category, habit_break_window, boolean, text) to authenticated;
grant execute on function public.complete_habit(uuid) to authenticated;
