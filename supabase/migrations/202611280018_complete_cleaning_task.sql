begin;

create or replace function public.complete_cleaning(p_cleaning_id uuid,p_expected_version integer,p_checklist jsonb,p_notes text default null) returns public.cleaning_records language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.cleaning_records%rowtype;
begin
 select * into v from public.cleaning_records where id=p_cleaning_id for update;
 if not found or not public.current_user_has_org(v.organization_id,array['owner','manager','staff']) then raise exception 'cleaning record not found';end if;
 if v.version<>p_expected_version then raise exception 'record changed' using errcode='40001';end if;
 if not(coalesce((p_checklist->>'litter_box')::boolean,false) and coalesce((p_checklist->>'bowls')::boolean,false) and coalesce((p_checklist->>'bedding')::boolean,false) and coalesce((p_checklist->>'disinfection')::boolean,false)) then raise exception 'required cleaning checklist is incomplete';end if;
 update public.cleaning_records set status='completed',checklist=p_checklist,notes=p_notes,completed_at=now(),responsible_staff=auth.uid(),updated_by=auth.uid() where id=v.id returning * into v;
 update public.rooms set status='available',updated_by=auth.uid() where id=v.room_id and organization_id=v.organization_id;
 update public.tasks set status='completed',completed_by=auth.uid(),completed_at=v.completed_at,updated_by=auth.uid()
 where organization_id=v.organization_id and source_type='cleaning_record' and source_id=v.id and status in('pending','in_progress','requires_confirmation');
 return v;
end $$;
revoke all on function public.complete_cleaning(uuid,integer,jsonb,text) from public;
grant execute on function public.complete_cleaning(uuid,integer,jsonb,text) to authenticated;

update public.tasks t set
 status='completed',
 completed_by=coalesce(c.responsible_staff,c.updated_by),
 completed_at=coalesce(c.completed_at,now()),
 updated_by=coalesce(c.responsible_staff,c.updated_by)
from public.cleaning_records c
where t.organization_id=c.organization_id and t.source_type='cleaning_record' and t.source_id=c.id and c.status='completed' and t.status in('pending','in_progress','requires_confirmation');

commit;
