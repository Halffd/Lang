# Spec: supabase-sync

Scope: feature

# Supabase Sync for Lang App

## Context
The lang app currently stores saved words in SharedPreferences and dictionaries in local SQLite. No cloud sync or SRS (spaced repetition) exists. We need to add Supabase for cloud backup/sync and implement a complete SRS system.

## Decisions
1. Full SRS system with SM-2 algorithm, cards, reviews, due dates
2. Anonymous auth by default, users can optionally create accounts
3. Local-first: all data works offline, syncs when online
4. Supabase Realtime for live sync across devices

## Database Schema

### Tables

```sql
-- Users (managed by Supabase Auth, we add profile extension)
create table public.profiles (
  id uuid references auth.users primary key,
  created_at timestamptz default now(),
  settings jsonb default '{}',
  srs_settings jsonb default '{"interval_modifier": 1.0, "new_cards_per_day": 20}'
);

-- Saved Words (supabase mirrors local SharedPreferences)
create table public.saved_words (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles not null,
  word text not null,
  reading text,
  sentence text,
  frequency int,
  context jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, word)
);

-- SRS Decks
create table public.srs_decks (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles not null,
  name text not null,
  description text,
  icon text default '📚',
  color text default '#3B82F6',
  created_at timestamptz default now(),
  unique(user_id, name)
);

-- SRS Cards
create table public.srs_cards (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles not null,
  deck_id uuid references public.srs_decks on delete cascade,
  word_id uuid references public.saved_words on delete set null,
  
  -- Front/Back
  front text not null,
  back text not null,
  reading text,
  
  -- SM-2 fields
  ease_factor float default 2.5,
  interval int default 0,  -- days until next review
  repetitions int default 0,
  due_date timestamptz default now(),
  
  -- Metadata
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_reviewed_at timestamptz,
  
  unique(user_id, front)
);

-- SRS Review Log
create table public.srs_reviews (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles not null,
  card_id uuid references public.srs_cards on delete cascade,
  rating int check (rating >= 0 and rating <= 5),
  time_taken_ms int,
  reviewed_at timestamptz default now()
);

-- Dictionary metadata (for syncing installed dictionaries)
create table public.user_dictionaries (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles not null,
  title text not null,
  version int,
  language text,
  entry_count int,
  installed_at timestamptz default now(),
  unique(user_id, title)
);
```

### Row Level Security
```sql
-- All tables use RLS with user_id = auth.uid()
alter table public.saved_words enable row level security;
alter table public.srs_decks enable row level security;
alter table public.srs_cards enable row level security;
alter table public.srs_reviews enable row level security;
alter table public.user_dictionaries enable row level security;

-- RLS policies: users can only access their own data
create policy "Users access own data" on public.saved_words
  for all using (user_id = auth.uid());

-- Similar policies for all other tables
```

### Sync Strategy
1. **Local-first**: All operations happen locally first
2. **Supabase sync**: Background sync when online using Supabase Realtime subscriptions
3. **Conflict resolution**: Last-write-wins based on `updated_at`
4. **Offline queue**: Pending changes queued and synced when connectivity restored

## Files to Create/Modify

### New Files
- `lib/core/services/supabase_service.dart` - Supabase client singleton
- `lib/core/services/srs_service.dart` - SM-2 algorithm + SRS logic
- `lib/domain/entities/srs_card.dart` - Card entity
- `lib/domain/entities/srs_deck.dart` - Deck entity
- `lib/domain/entities/srs_review.dart` - Review log entity
- `lib/data/datasources/supabase_data_source.dart` - Supabase data operations
- `lib/data/repositories/srs_repository_impl.dart` - SRS repository implementation
- `lib/domain/repositories/srs_repository.dart` - SRS repository interface

### Modified Files
- `lib/main.dart` - Initialize Supabase
- `lib/presentation/providers/analyzer_provider.dart` - Add sync methods
- `lib/presentation/screens/saved_words_screen.dart` - Add deck management UI
- `lib/presentation/screens/analyze_screen.dart` - Add SRS integration
- `lib/data/repositories/analyzer_repository_impl.dart` - Add Supabase sync

## SM-2 Algorithm Implementation
```
Input: quality (0-5)
- 0-2: Reset (repeat)
- 3: Good interval * ease_factor
- 4-5: Great interval * ease_factor * 1.3

Ease Factor: min 1.3, updated based on quality
- q < 3: ef = ef
- q >= 3: ef = ef + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))

Due date = now + interval days
```

## Verification
1. `dart analyze` passes
2. Unit tests for SM-2 algorithm
3. Integration test for sync flow
4. Manual test: save word → appears in Supabase → syncs to another device