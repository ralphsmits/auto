-- Roadnote shared household storage
-- Run once in Supabase Dashboard > SQL Editor.

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (household_id,user_id)
);

create table if not exists public.household_cars (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  car_key text not null check (car_key in ('karl','crossland')),
  label text not null,
  model_year integer not null,
  efficiency_l_100km numeric(6,2) not null,
  monthly_tax numeric(8,2) not null default 0,
  monthly_insurance numeric(8,2) not null default 0,
  tax_enabled boolean not null default true,
  insurance_enabled boolean not null default true,
  fuel_price numeric(6,3) not null default 1.92,
  updated_at timestamptz not null default now(),
  unique (household_id,car_key)
);

alter table public.household_cars add column if not exists tax_enabled boolean not null default true;
alter table public.household_cars add column if not exists insurance_enabled boolean not null default true;

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  car_key text not null check (car_key in ('karl','crossland')),
  start_label text not null,
  destination_label text not null,
  journey_date date not null,
  trip_type text not null check (trip_type in ('single','return')),
  distance_km numeric(9,2) not null check (distance_km > 0),
  fuel_litres numeric(9,3) not null,
  fuel_price_per_litre numeric(6,3) not null,
  fuel_cost numeric(9,2) not null,
  efficiency_l_100km numeric(6,2) not null,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists trips_household_date_idx on public.trips(household_id,journey_date desc);

create table if not exists public.monthly_periods (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  month_key text not null check (month_key ~ '^\d{4}-\d{2}$'),
  closed_at timestamptz,
  fixed_costs jsonb,
  unique (household_id,month_key)
);
alter table public.monthly_periods add column if not exists fixed_costs jsonb;

create table if not exists public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  code text not null unique,
  created_by uuid not null references auth.users(id),
  expires_at timestamptz not null default now() + interval '7 days',
  use_count integer not null default 0,
  max_uses integer not null default 5
);

create or replace function public.is_household_member(target_household_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.household_members m where m.household_id = target_household_id and m.user_id = auth.uid()); $$;

create or replace function public.create_household(household_name text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare new_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  insert into public.households(name) values (coalesce(nullif(trim(household_name),''),'Family household')) returning id into new_id;
  insert into public.household_members(household_id,user_id,role) values (new_id,auth.uid(),'owner');
  return new_id;
end; $$;

create or replace function public.create_household_invite(target_household_id uuid)
returns text language plpgsql security definer set search_path = public
as $$
declare invite_code text;
begin
  if not public.is_household_member(target_household_id) then raise exception 'You are not a household member.'; end if;
  invite_code := upper(substring(replace(pg_catalog.gen_random_uuid()::text,'-','') from 1 for 12));
  insert into public.household_invites(household_id,code,created_by) values (target_household_id,invite_code,auth.uid());
  return invite_code;
end; $$;

create or replace function public.join_household(invite_code text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare invite_row public.household_invites%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  select * into invite_row from public.household_invites i where i.code=upper(trim(invite_code)) and i.expires_at>now() and i.use_count<i.max_uses for update;
  if invite_row.id is null then raise exception 'That invite code is invalid or expired.'; end if;
  insert into public.household_members(household_id,user_id,role) values (invite_row.household_id,auth.uid(),'member') on conflict do nothing;
  update public.household_invites set use_count=use_count+1 where id=invite_row.id;
  return invite_row.household_id;
end; $$;

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_cars enable row level security;
alter table public.trips enable row level security;
alter table public.monthly_periods enable row level security;
alter table public.household_invites enable row level security;

drop policy if exists "members can read their household" on public.households;
create policy "members can read their household" on public.households for select to authenticated using (public.is_household_member(id));
drop policy if exists "users can read their own memberships" on public.household_members;
create policy "users can read their own memberships" on public.household_members for select to authenticated using (user_id=auth.uid() or public.is_household_member(household_id));
drop policy if exists "members can manage household cars" on public.household_cars;
create policy "members can manage household cars" on public.household_cars for all to authenticated using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
drop policy if exists "members can manage household trips" on public.trips;
create policy "members can manage household trips" on public.trips for all to authenticated using (public.is_household_member(household_id)) with check (public.is_household_member(household_id) and created_by=auth.uid());
drop policy if exists "members can manage monthly periods" on public.monthly_periods;
create policy "members can manage monthly periods" on public.monthly_periods for all to authenticated using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
drop policy if exists "members can create household invites" on public.household_invites;
create policy "members can create household invites" on public.household_invites for insert to authenticated with check (public.is_household_member(household_id) and created_by=auth.uid());

grant usage on schema public to authenticated;
grant select on public.households, public.household_members to authenticated;
grant insert on public.household_invites to authenticated;
grant select,insert,update,delete on public.household_cars, public.trips, public.monthly_periods to authenticated;
grant execute on function public.create_household(text) to authenticated;
grant execute on function public.create_household_invite(uuid) to authenticated;
grant execute on function public.join_household(text) to authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;
-- View-only family access
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
