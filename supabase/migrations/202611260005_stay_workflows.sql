begin;
create table public.stay_workflows(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  reservation_id uuid not null,
  workflow_type text not null check(workflow_type in('checkin','checkout')),
  status text not null default 'draft' check(status in('draft','completed','cancelled')),
  progress jsonb not null default '{}',
  completed_at timestamptz,
  completed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),updated_by uuid not null references auth.users(id),version integer not null default 1,
  unique(organization_id,reservation_id,workflow_type),unique(organization_id,id),
  foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict
);
create trigger stay_workflows_updated before update on public.stay_workflows for each row execute function public.set_updated_at();
alter table public.stay_workflows enable row level security;
create policy stay_workflows_staff_read on public.stay_workflows for select to authenticated using(public.current_user_has_org(organization_id,array['owner','manager','staff']));
-- 寫入只經由下列 RPC，避免客戶端偽造完成狀態與人員時間。

create or replace function public.save_stay_workflow(p_reservation_id uuid,p_workflow_type text,p_progress jsonb,p_expected_version integer default null) returns public.stay_workflows language plpgsql security definer set search_path=public,pg_temp as $$
declare v_res public.reservations%rowtype;v_flow public.stay_workflows%rowtype;v_user uuid:=auth.uid();
begin
 select * into v_res from public.reservations where id=p_reservation_id;
 if not found or not public.current_user_has_org(v_res.organization_id,array['owner','manager','staff']) then raise exception 'reservation not found';end if;
 if p_workflow_type not in('checkin','checkout') or jsonb_typeof(p_progress)<>'object' then raise exception 'invalid workflow payload';end if;
 if (p_workflow_type='checkin' and v_res.status<>'confirmed') or (p_workflow_type='checkout' and v_res.status not in('checked_in','waiting_checkout')) then raise exception 'workflow is not valid for reservation status';end if;
 select * into v_flow from public.stay_workflows where organization_id=v_res.organization_id and reservation_id=v_res.id and workflow_type=p_workflow_type for update;
 if found then
   if v_flow.status<>'draft' then raise exception 'workflow is no longer editable';end if;
   if p_expected_version is not null and v_flow.version<>p_expected_version then raise exception 'workflow changed; reload' using errcode='40001';end if;
   update public.stay_workflows set progress=p_progress,updated_by=v_user where id=v_flow.id returning * into v_flow;
 else
   insert into public.stay_workflows(organization_id,reservation_id,workflow_type,progress,created_by,updated_by) values(v_res.organization_id,v_res.id,p_workflow_type,p_progress,v_user,v_user) returning * into v_flow;
 end if;
 return v_flow;
end $$;
revoke all on function public.save_stay_workflow(uuid,text,jsonb,integer) from public;grant execute on function public.save_stay_workflow(uuid,text,jsonb,integer) to authenticated;

create or replace function public.complete_checkin(p_reservation_id uuid,p_actual_check_in_at timestamptz,p_progress jsonb,p_expected_reservation_version integer) returns public.reservations language plpgsql security definer set search_path=public,pg_temp as $$
declare v_res public.reservations%rowtype;v_allocation public.room_allocations%rowtype;v_user uuid:=auth.uid();v_required text;v_day date;v_rc record;
begin
 select * into v_res from public.reservations where id=p_reservation_id for update;
 if not found or not public.current_user_has_org(v_res.organization_id,array['owner','manager']) then raise exception 'permission denied';end if;
 if v_res.version<>p_expected_reservation_version then raise exception 'reservation changed; reload' using errcode='40001';end if;
 if v_res.status<>'confirmed' then raise exception 'only confirmed reservations may check in';end if;
 foreach v_required in array array['reservation_confirmed','owner_cat_confirmed','room_confirmed','actual_time_confirmed','luggage_reviewed','food_reviewed','supplements_reviewed','medications_reviewed','feeding_instructions_confirmed','care_instructions_confirmed'] loop
   if coalesce((p_progress->>v_required)::boolean,false) is not true then raise exception 'check-in item % is not confirmed',v_required;end if;
 end loop;
 select * into v_allocation from public.room_allocations where organization_id=v_res.organization_id and reservation_id=v_res.id and allocation_status='active' for update;
 if not found then raise exception 'active room allocation required';end if;
 if p_actual_check_in_at>now()+interval '1 day' or p_actual_check_in_at>=v_res.expected_check_out_at then raise exception 'actual check-in time is invalid';end if;
 insert into public.stay_workflows(organization_id,reservation_id,workflow_type,status,progress,completed_at,completed_by,created_by,updated_by) values(v_res.organization_id,v_res.id,'checkin','completed',p_progress,now(),v_user,v_user,v_user)
 on conflict(organization_id,reservation_id,workflow_type) do update set status='completed',progress=excluded.progress,completed_at=now(),completed_by=v_user,updated_by=v_user where public.stay_workflows.status='draft';
 update public.reservations set status='checked_in',actual_check_in_at=p_actual_check_in_at,updated_by=v_user where id=v_res.id returning * into v_res;
 update public.rooms set status='occupied',updated_by=v_user where id=v_allocation.room_id and organization_id=v_res.organization_id;
 for v_rc in select id from public.reservation_cats where organization_id=v_res.organization_id and reservation_id=v_res.id loop
   for v_day in select d::date from generate_series((p_actual_check_in_at at time zone 'Asia/Taipei')::date,(v_res.expected_check_out_at at time zone 'Asia/Taipei')::date-1,interval '1 day') d loop
     insert into public.care_days(organization_id,reservation_cat_id,care_date,day_number,created_by) values(v_res.organization_id,v_rc.id,v_day,(v_day-(p_actual_check_in_at at time zone 'Asia/Taipei')::date)+1,v_user) on conflict do nothing;
   end loop;
 end loop;
 perform public.generate_care_tasks(v_res.id);return v_res;
end $$;
revoke all on function public.complete_checkin(uuid,timestamptz,jsonb,integer) from public;grant execute on function public.complete_checkin(uuid,timestamptz,jsonb,integer) to authenticated;

create or replace function public.ensure_care_day(p_reservation_cat_id uuid,p_care_date date) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_org uuid;v_res public.reservations%rowtype;v_id uuid;v_start date;v_end date;
begin
 select rc.organization_id,r into v_org,v_res from public.reservation_cats rc join public.reservations r on r.id=rc.reservation_id and r.organization_id=rc.organization_id where rc.id=p_reservation_cat_id;
 if not found or not public.current_user_has_org(v_org,array['owner','manager','staff']) then raise exception 'stay cat not found';end if;
 if v_res.status not in('checked_in','waiting_checkout') then raise exception 'cat is not currently checked in';end if;
 v_start=(coalesce(v_res.actual_check_in_at,v_res.expected_check_in_at) at time zone 'Asia/Taipei')::date;v_end=(v_res.expected_check_out_at at time zone 'Asia/Taipei')::date;
 if p_care_date<v_start or p_care_date>=v_end then raise exception 'care date is outside the boarding interval';end if;
 insert into public.care_days(organization_id,reservation_cat_id,care_date,day_number,created_by) values(v_org,p_reservation_cat_id,p_care_date,(p_care_date-v_start)+1,auth.uid()) on conflict(organization_id,reservation_cat_id,care_date) do update set care_date=excluded.care_date returning id into v_id;return v_id;
end $$;
revoke all on function public.ensure_care_day(uuid,date) from public;grant execute on function public.ensure_care_day(uuid,date) to authenticated;

create trigger stay_workflows_audit after insert or update or delete on public.stay_workflows for each row execute function public.audit_row();
alter publication supabase_realtime add table public.stay_workflows,public.meal_records,public.water_records,public.urination_records,public.defecation_records;
commit;
