-- Invite repair and protected viewer access. Run in Supabase SQL Editor.
-- Roadnote view-only family access. Run once in Supabase SQL Editor.
-- Existing owners, household members, invites, and journeys are preserved.
-- The existing 'member' role is now view-only; only 'owner' can change data.
begin;

create or replace function public.is_household_owner(target_household_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.household_members m
    where m.household_id=target_household_id and m.user_id=auth.uid() and m.role='owner');
$$;
revoke all on function public.is_household_owner(uuid) from public;
grant execute on function public.is_household_owner(uuid) to authenticated;

drop policy if exists "members can manage household cars" on public.household_cars;
drop policy if exists "members can read household cars" on public.household_cars;
drop policy if exists "owners can manage household cars" on public.household_cars;
create policy "members can read household cars" on public.household_cars for select to authenticated using (public.is_household_member(household_id));
create policy "owners can manage household cars" on public.household_cars for all to authenticated using (public.is_household_owner(household_id)) with check (public.is_household_owner(household_id));

drop policy if exists "members can manage household trips" on public.trips;
drop policy if exists "members can read household trips" on public.trips;
drop policy if exists "owners can manage household trips" on public.trips;
create policy "members can read household trips" on public.trips for select to authenticated using (public.is_household_member(household_id));
create policy "owners can manage household trips" on public.trips for all to authenticated using (public.is_household_owner(household_id)) with check (public.is_household_owner(household_id) and created_by=auth.uid());

drop policy if exists "members can manage monthly periods" on public.monthly_periods;
drop policy if exists "members can read monthly periods" on public.monthly_periods;
drop policy if exists "owners can manage monthly periods" on public.monthly_periods;
create policy "members can read monthly periods" on public.monthly_periods for select to authenticated using (public.is_household_member(household_id));
create policy "owners can manage monthly periods" on public.monthly_periods for all to authenticated using (public.is_household_owner(household_id)) with check (public.is_household_owner(household_id));

drop policy if exists "members can create household invites" on public.household_invites;
drop policy if exists "owners can create household invites" on public.household_invites;
create policy "owners can create household invites" on public.household_invites for insert to authenticated with check (public.is_household_owner(household_id) and created_by=auth.uid());
grant insert on public.household_invites to authenticated;

create or replace function public.create_household_invite(target_household_id uuid)
returns text language plpgsql security definer set search_path = public
as $$
declare invite_code text;
begin
  if not public.is_household_owner(target_household_id) then raise exception 'Only the household owner can create invites.'; end if;
  invite_code := upper(substring(replace(pg_catalog.gen_random_uuid()::text,'-','') from 1 for 12));
  insert into public.household_invites(household_id,code,created_by) values (target_household_id,invite_code,auth.uid());
  return invite_code;
end; $$;
revoke all on function public.create_household_invite(uuid) from public;
grant execute on function public.create_household_invite(uuid) to authenticated;

create or replace function public.join_household(invite_code text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare invite_row public.household_invites%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  select * into invite_row from public.household_invites i where i.code=upper(trim(invite_code)) and i.expires_at>now() and i.use_count<i.max_uses for update;
  if invite_row.id is null then raise exception 'That invite code is invalid or expired.'; end if;
  if not public.is_household_member(invite_row.household_id) then
    insert into public.household_members(household_id,user_id,role) values (invite_row.household_id,auth.uid(),'member');
    update public.household_invites set use_count=use_count+1 where id=invite_row.id;
  end if;
  return invite_row.household_id;
end; $$;
revoke all on function public.join_household(text) from public;
grant execute on function public.join_household(text) to authenticated;

create or replace function public.roadnote_viewer_access_ready()
returns boolean language sql stable security definer set search_path = public
as $$ select true; $$;
revoke all on function public.roadnote_viewer_access_ready() from public;
grant execute on function public.roadnote_viewer_access_ready() to authenticated;

notify pgrst, 'reload schema';
commit;
