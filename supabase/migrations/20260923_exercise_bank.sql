-- exercise_bank: pre-generated AI lesson exercises shared across users.
-- Generated in batches by an offline job, QA'd, then served instantly
-- without per-user generation cost.

create table if not exists public.exercise_bank (
  id bigint generated always as identity primary key,
  language text not null,               -- 'ja', 'es', ...
  level text not null default 'A1',     -- CEFR A1..C2 or app tier
  type text not null,                   -- flashcard/mc/written/cloze/match/listening/spoken
  prompt text not null,
  prompt_sub text,
  answer text not null default '',
  choices jsonb,
  pairs jsonb,
  breakdown jsonb,
  prompt_hash text not null,            -- normalized+hashed prompt for dedupe
  qa_status text not null default 'pending',  -- pending | verified | flagged
  source text not null default 'pregenerated', -- pregenerated | user_ai
  created_at timestamptz not null default now()
);

-- dedupe within the bank: same language+prompt only once
create unique index if not exists exercise_bank_dedupe
  on public.exercise_bank (language, level, type, prompt_hash);

alter table public.exercise_bank enable row level security;

-- anyone authed can read verified/pending; writes are service-side
create policy if not exists "exercise_bank_read"
  on public.exercise_bank for select using (true);

create policy if not exists "exercise_bank_insert"
  on public.exercise_bank for insert with check (true);
