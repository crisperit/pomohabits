-- =============================================================================
-- Pomohabits: add update_habit and delete_habit RPCs
--
-- Adds two new PostgREST RPCs for editing and deleting habits.
-- No table, enum, index, trigger, or RLS change is needed: owner update/delete
-- policies and the cascade FK (habit_completions.habit_id on delete cascade)
-- already exist from prior migrations.
--
-- New RPCs:
--   update_habit(p_id, p_name, p_category, p_applicable_break_window,
--                p_always_shown, p_icon) returns public.habits
--   delete_habit(p_id) returns void
--
-- Both enforce ownership the same way complete_habit does:
--   - auth.uid() null  -> raise (unauthenticated)
--   - habit not found  -> raise P0002
--   - wrong owner      -> raise 42501
--
-- updated_at is maintained by the existing habits_set_updated_at trigger;
-- do NOT set it manually in update_habit.
-- Completions are removed automatically via the on-delete-cascade FK;
-- delete_habit only deletes the habit row.
-- =============================================================================

-- update_habit ----------------------------------------------------------------

drop function if exists public.update_habit(uuid, text, habit_category, habit_break_window, boolean, text);

-- update_habit: replaces every user-editable field on the caller's habit and
-- returns the updated row. Full-replace (not partial) because the edit form
-- always submits all fields. p_icon null means "no icon".
create function public.update_habit(
  p_id                      uuid,
  p_name                    text,
  p_category                habit_category,
  p_applicable_break_window habit_break_window,
  p_always_shown            boolean,
  p_icon                    text default null
)
returns public.habits
language plpgsql
security invoker
set search_path = public
as $$
declare
  habit_owner uuid;
  updated     public.habits;
begin
  if auth.uid() is null then
    raise exception 'update_habit requires an authenticated session';
  end if;
  select user_id into habit_owner from public.habits where id = p_id;
  if habit_owner is null then
    raise exception 'habit not found' using errcode = 'P0002';
  end if;
  if habit_owner <> auth.uid() then
    raise exception 'habit does not belong to caller' using errcode = '42501';
  end if;
  update public.habits
  set
    name                    = p_name,
    category                = p_category,
    applicable_break_window = p_applicable_break_window,
    always_shown            = p_always_shown,
    icon                    = p_icon
  where id = p_id
  returning * into updated;
  return updated;
end;
$$;

-- delete_habit ----------------------------------------------------------------

drop function if exists public.delete_habit(uuid);

-- delete_habit: hard-deletes the caller's habit. Completions are removed
-- automatically by the existing on-delete-cascade FK on habit_completions.
create function public.delete_habit(p_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  habit_owner uuid;
begin
  if auth.uid() is null then
    raise exception 'delete_habit requires an authenticated session';
  end if;
  select user_id into habit_owner from public.habits where id = p_id;
  if habit_owner is null then
    raise exception 'habit not found' using errcode = 'P0002';
  end if;
  if habit_owner <> auth.uid() then
    raise exception 'habit does not belong to caller' using errcode = '42501';
  end if;
  delete from public.habits where id = p_id;
end;
$$;

-- Grants ----------------------------------------------------------------------

grant execute on function public.update_habit(uuid, text, habit_category, habit_break_window, boolean, text) to authenticated;
grant execute on function public.delete_habit(uuid) to authenticated;
