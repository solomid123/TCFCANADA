create table if not exists public.tcf_listening_sessions (
  id uuid primary key,
  owner_id uuid references auth.users(id) on delete cascade,
  state text not null default 'queued' check (state in ('queued','generating','ready','failed')),
  phase text not null default 'En attente',
  planned integer not null default 0,
  images integer not null default 0,
  audio integer not null default 0,
  plan jsonb not null default '[]'::jsonb,
  assets jsonb not null default '{}'::jsonb,
  image_checks jsonb not null default '{}'::jsonb,
  image_attempts jsonb not null default '{}'::jsonb,
  error text,
  lease_token uuid,
  lease_until timestamptz,
  step_attempts integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.tcf_listening_sessions enable row level security;
revoke all on public.tcf_listening_sessions from anon, authenticated;
grant all on public.tcf_listening_sessions to service_role;
create index if not exists tcf_listening_owner_idx on public.tcf_listening_sessions(owner_id, created_at);

create or replace function public.claim_tcf_listening_job()
returns setof public.tcf_listening_sessions
language plpgsql security definer set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(82374911);
  update public.tcf_listening_sessions
  set state = case when step_attempts < 2 then 'queued' else 'failed' end,
      error = case when step_attempts < 2 then null else 'Préparation interrompue. Réessayez pour reprendre les éléments manquants.' end,
      lease_token = null, lease_until = null
  where lease_until < now() and state = 'generating';
  if exists(select 1 from public.tcf_listening_sessions where lease_until > now()) then return; end if;
  return query
  update public.tcf_listening_sessions s
  set lease_token = gen_random_uuid(), lease_until = now() + interval '130 seconds',
      state = 'generating', step_attempts = step_attempts + 1, updated_at = now()
  where s.id = (
    select id from public.tcf_listening_sessions
    where state in ('queued','generating') and lease_token is null
    order by created_at limit 1 for update skip locked
  ) returning s.*;
end;
$$;
revoke all on function public.claim_tcf_listening_job() from public, anon, authenticated;
grant execute on function public.claim_tcf_listening_job() to service_role;
