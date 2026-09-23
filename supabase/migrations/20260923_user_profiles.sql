-- user_profiles: per-user profile + stats mirror. Row per user, keyed
-- by auth.users.id, with RLS so clients can only touch their own row.

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text default '',
  native_language text default 'en',
  target_language text default 'ja',
  languages jsonb default '["ja"]',
  xp integer default 0,
  gems integer default 0,
  streak integer default 0,
  daily_goal integer default 50,
  cards_mastered integer default 0,
  updated_at timestamptz not null default now()
);

alter table public.user_profiles enable row level security;

create policy if not exists "user_profiles_select_own"
  on public.user_profiles for select using (auth.uid() = user_id);

create policy if not exists "user_profiles_insert_own"
  on public.user_profiles for insert with check (auth.uid() = user_id);

create policy if not exists "user_profiles_update_own"
  on public.user_profiles for update using (auth.uid() = user_id);

-- realtime so other devices can pull profile changes as they happen
alter publication supabase_realtime add table public.user_profiles;
