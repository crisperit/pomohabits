-- =============================================================================
-- Taskodoro: add optional icon column to tasks
--
-- Adds a nullable icon text column (max 16 chars) to public.tasks.
-- Widens list_tasks return type and add_task signature to include icon.
-- DROP + CREATE is required because Postgres CREATE OR REPLACE cannot change
-- a function's return-table shape or argument list.
-- =============================================================================

-- Column -----------------------------------------------------------------------

alter table public.tasks
  add column if not exists icon text check (icon is null or char_length(icon) <= 16);

-- list_tasks -------------------------------------------------------------------

drop function if exists public.list_tasks(text);

-- list_tasks: returns the caller's tasks with "completed_today" computed in
-- the caller-supplied IANA timezone (default UTC). Clients pass their local
-- zone so the daily reset boundary matches the user's wall clock.
create function public.list_tasks(p_timezone text default 'UTC')
returns table (
  id uuid,
  name text,
  category task_category,
  applicable_break_window task_break_window,
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
    t.id,
    t.name,
    t.category,
    t.applicable_break_window,
    t.always_shown,
    t.icon,
    t.created_at,
    t.updated_at,
    exists (
      select 1 from public.task_completions c
      where c.task_id = t.id
        and c.user_id = auth.uid()
        and c.completed_at >= (date_trunc('day', now() at time zone p_timezone) at time zone p_timezone)
        and c.completed_at <  (date_trunc('day', now() at time zone p_timezone) at time zone p_timezone) + interval '1 day'
    ) as completed_today,
    exists (
      select 1 from public.task_completions c
      where c.task_id = t.id and c.user_id = auth.uid()
    ) as completed_ever
  from public.tasks t
  where t.user_id = auth.uid()
  order by t.always_shown desc, t.created_at asc;
$$;

-- add_task ---------------------------------------------------------------------

drop function if exists public.add_task(text, task_category, task_break_window, boolean);

-- add_task: inserts a new task scoped to the caller. Returns the inserted row.
create function public.add_task(
  p_name text,
  p_category task_category,
  p_applicable_break_window task_break_window,
  p_always_shown boolean,
  p_icon text default null
)
returns public.tasks
language plpgsql
security invoker
set search_path = public
as $$
declare
  inserted public.tasks;
begin
  if auth.uid() is null then
    raise exception 'add_task requires an authenticated session';
  end if;
  insert into public.tasks (user_id, name, category, applicable_break_window, always_shown, icon)
  values (auth.uid(), p_name, p_category, p_applicable_break_window, coalesce(p_always_shown, false), p_icon)
  returning * into inserted;
  return inserted;
end;
$$;

-- Grants -----------------------------------------------------------------------

grant execute on function public.list_tasks(text) to authenticated;
grant execute on function public.add_task(text, task_category, task_break_window, boolean, text) to authenticated;
