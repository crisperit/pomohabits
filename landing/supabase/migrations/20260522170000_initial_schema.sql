-- =============================================================================
-- Taskodoro: initial schema migration
--
-- Tables: tasks, task_completions
-- Enums: task_category, task_break_window
-- RLS: per-user scoping on both tables (auth.uid() matches user_id)
-- RPC: list_tasks, add_task, complete_task (the three operations FR-013 names)
--
-- Hard delete only (PRD FR-006); no soft-delete column.
-- =============================================================================

-- Enums --------------------------------------------------------------------

do $$ begin
  create type task_category as enum ('one_time', 'daily', 'unlimited');
exception when duplicate_object then null; end $$;

do $$ begin
  create type task_break_window as enum ('short', 'long', 'both');
exception when duplicate_object then null; end $$;

-- Tables -------------------------------------------------------------------

create table if not exists public.tasks (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  name            text not null check (length(name) between 1 and 200),
  category        task_category not null,
  applicable_break_window task_break_window not null,
  always_shown    boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists tasks_user_id_idx on public.tasks(user_id);

create table if not exists public.task_completions (
  id              uuid primary key default gen_random_uuid(),
  task_id         uuid not null references public.tasks(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  completed_at    timestamptz not null default now()
);

create index if not exists task_completions_task_id_completed_at_idx
  on public.task_completions(task_id, completed_at desc);
create index if not exists task_completions_user_id_idx
  on public.task_completions(user_id);

-- updated_at trigger on tasks ----------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tasks_set_updated_at on public.tasks;
create trigger tasks_set_updated_at
  before update on public.tasks
  for each row execute function public.set_updated_at();

-- RLS ----------------------------------------------------------------------

alter table public.tasks enable row level security;
alter table public.task_completions enable row level security;

drop policy if exists "tasks: owner can select" on public.tasks;
create policy "tasks: owner can select" on public.tasks
  for select using (auth.uid() = user_id);

drop policy if exists "tasks: owner can insert" on public.tasks;
create policy "tasks: owner can insert" on public.tasks
  for insert with check (auth.uid() = user_id);

drop policy if exists "tasks: owner can update" on public.tasks;
create policy "tasks: owner can update" on public.tasks
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "tasks: owner can delete" on public.tasks;
create policy "tasks: owner can delete" on public.tasks
  for delete using (auth.uid() = user_id);

drop policy if exists "task_completions: owner can select" on public.task_completions;
create policy "task_completions: owner can select" on public.task_completions
  for select using (auth.uid() = user_id);

drop policy if exists "task_completions: owner can insert" on public.task_completions;
create policy "task_completions: owner can insert" on public.task_completions
  for insert with check (auth.uid() = user_id);

-- RPC functions (PRD FR-013) -----------------------------------------------

-- list_tasks: returns the caller's tasks with "completed_today" computed in
-- the caller-supplied IANA timezone (default UTC). Clients pass their local
-- zone so the daily reset boundary matches the user's wall clock.
create or replace function public.list_tasks(p_timezone text default 'UTC')
returns table (
  id uuid,
  name text,
  category task_category,
  applicable_break_window task_break_window,
  always_shown boolean,
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

-- add_task: inserts a new task scoped to the caller. Returns the inserted row.
create or replace function public.add_task(
  p_name text,
  p_category task_category,
  p_applicable_break_window task_break_window,
  p_always_shown boolean
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
  insert into public.tasks (user_id, name, category, applicable_break_window, always_shown)
  values (auth.uid(), p_name, p_category, p_applicable_break_window, coalesce(p_always_shown, false))
  returning * into inserted;
  return inserted;
end;
$$;

-- complete_task: records a completion event for the given task, scoped to caller.
create or replace function public.complete_task(p_task_id uuid)
returns public.task_completions
language plpgsql
security invoker
set search_path = public
as $$
declare
  task_owner uuid;
  inserted public.task_completions;
begin
  if auth.uid() is null then
    raise exception 'complete_task requires an authenticated session';
  end if;
  select user_id into task_owner from public.tasks where id = p_task_id;
  if task_owner is null then
    raise exception 'task not found' using errcode = 'P0002';
  end if;
  if task_owner <> auth.uid() then
    raise exception 'task does not belong to caller' using errcode = '42501';
  end if;
  insert into public.task_completions (task_id, user_id)
  values (p_task_id, auth.uid())
  returning * into inserted;
  return inserted;
end;
$$;

-- Grants -------------------------------------------------------------------

grant execute on function public.list_tasks(text) to authenticated;
grant execute on function public.add_task(text, task_category, task_break_window, boolean) to authenticated;
grant execute on function public.complete_task(uuid) to authenticated;
