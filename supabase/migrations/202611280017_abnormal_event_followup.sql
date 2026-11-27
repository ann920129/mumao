begin;

create or replace function public.add_abnormal_event_followup(
  p_event_id uuid,
  p_notes text,
  p_next_follow_up_at timestamptz,
  p_expected_version integer
) returns public.abnormal_events
language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.abnormal_events%rowtype;
begin
  select * into v from public.abnormal_events where id=p_event_id for update;
  if not found or not public.current_user_has_org(v.organization_id,array['owner','manager','staff']) then raise exception 'event not found' using errcode='42501';end if;
  if v.version<>p_expected_version then raise exception 'event changed' using errcode='40001';end if;
  if v.status in('resolved','closed') then raise exception 'event is already closed';end if;
  if length(trim(coalesce(p_notes,'')))<2 then raise exception 'follow-up notes are required';end if;
  insert into public.abnormal_event_updates(organization_id,abnormal_event_id,update_type,notes,created_by)
  values(v.organization_id,v.id,'follow_up',trim(p_notes),auth.uid());
  update public.abnormal_events set status='monitoring',follow_up_required=true,next_follow_up_at=p_next_follow_up_at,responsible_person=coalesce(responsible_person,auth.uid()),updated_by=auth.uid() where id=v.id returning * into v;
  return v;
end $$;
revoke all on function public.add_abnormal_event_followup(uuid,text,timestamptz,integer) from public;
grant execute on function public.add_abnormal_event_followup(uuid,text,timestamptz,integer) to authenticated;

create or replace function public.resolve_abnormal_event(
  p_event_id uuid,
  p_resolution text,
  p_expected_version integer
) returns public.abnormal_events
language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.abnormal_events%rowtype;
begin
  select * into v from public.abnormal_events where id=p_event_id for update;
  if not found or not public.current_user_has_org(v.organization_id,array['owner','manager']) then raise exception 'only owner or manager may resolve an event' using errcode='42501';end if;
  if v.version<>p_expected_version then raise exception 'event changed' using errcode='40001';end if;
  if v.status in('resolved','closed') then raise exception 'event is already closed';end if;
  if length(trim(coalesce(p_resolution,'')))<2 then raise exception 'resolution is required';end if;
  insert into public.abnormal_event_updates(organization_id,abnormal_event_id,update_type,notes,created_by)
  values(v.organization_id,v.id,'resolution',trim(p_resolution),auth.uid());
  update public.abnormal_events set status='resolved',resolution=trim(p_resolution),follow_up_required=false,next_follow_up_at=null,closed_by=auth.uid(),closed_at=now(),updated_by=auth.uid() where id=v.id returning * into v;
  return v;
end $$;
revoke all on function public.resolve_abnormal_event(uuid,text,integer) from public;
grant execute on function public.resolve_abnormal_event(uuid,text,integer) to authenticated;

commit;
