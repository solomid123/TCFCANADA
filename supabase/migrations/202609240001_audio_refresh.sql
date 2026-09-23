create or replace function public.upgrade_tcf_audio_asset(
  p_session uuid, p_name text, p_old_sha text, p_asset jsonb
) returns boolean language plpgsql security definer set search_path = '' as $$
declare changed integer;
begin
  if p_name !~ '^audio-[0-9]+\.wav$' or p_asset->>'name' <> p_name then
    raise exception 'Invalid audio asset';
  end if;
  update public.tcf_listening_sessions
  set assets = jsonb_set(assets, array[p_name], p_asset), updated_at = now()
  where id = p_session and state = 'ready' and assets->p_name->>'sha256' = p_old_sha;
  get diagnostics changed = row_count;
  return changed = 1;
end;
$$;
revoke all on function public.upgrade_tcf_audio_asset(uuid,text,text,jsonb) from public, anon, authenticated;
grant execute on function public.upgrade_tcf_audio_asset(uuid,text,text,jsonb) to service_role;
