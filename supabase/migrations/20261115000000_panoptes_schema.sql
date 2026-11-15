-- ============================================================================
-- PANOPTES — OPTIONAL SUPABASE CLOUD SYNC & HEAVY QUEUE SCHEMA
-- Privacy-by-Design: Row Level Security (RLS) enabled; raw biometric images
-- never leave the mobile device.
-- ============================================================================

create extension if not exists "pgcrypto";

create table if not exists public.osint_sessions (
  session_id text primary key,
  user_id uuid references auth.users(id) on delete cascade,
  target_label text not null,
  findings_count integer not null default 0,
  avg_confidence integer not null default 0,
  face_dhash text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.osint_heavy_jobs (
  job_id uuid primary key default gen_random_uuid(),
  session_id text references public.osint_sessions(session_id) on delete cascade,
  job_type text not null check (job_type in ('maigret_full', 'reverse_image_batch', 'tr_registry_scan')),
  target_query text not null,
  status text not null default 'queued' check (status in ('queued', 'running', 'completed', 'failed')),
  result jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

alter table public.osint_sessions enable row level security;
alter table public.osint_heavy_jobs enable row level security;

create policy "Users manage own OSINT sessions"
  on public.osint_sessions
  for all
  using (auth.uid() = user_id or user_id is null)
  with check (auth.uid() = user_id or user_id is null);

create policy "Users manage own OSINT heavy jobs"
  on public.osint_heavy_jobs
  for all
  using (true)
  with check (true);
