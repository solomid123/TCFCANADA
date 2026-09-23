alter table public.tcf_listening_sessions
  add column if not exists last_answers jsonb,
  add column if not exists last_score integer,
  add column if not exists completed_at timestamptz;

create or replace function public.count_tcf_bank_questions(p_owner uuid)
returns bigint language sql stable security definer set search_path = '' as $$
  select count(distinct md5((q->'turns')::text || (q->'options')::text || (q->>'question')))
  from public.tcf_listening_sessions s,
       lateral jsonb_array_elements(s.plan) q
  where s.state = 'ready'
    and (s.owner_id = p_owner or s.id = '50f71ba1-5c93-4de7-b043-cf2c215fa4c6'::uuid);
$$;
revoke all on function public.count_tcf_bank_questions(uuid) from public, anon, authenticated;
grant execute on function public.count_tcf_bank_questions(uuid) to service_role;
