begin;

create table public.shared_elimination_observations(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  reservation_id uuid not null,
  observation_type text not null check(observation_type in('urination','defecation')),
  attribution text not null default 'unidentifiable_shared' check(attribution='unidentifiable_shared'),
  observed_at timestamptz not null,
  observation_state text not null check(observation_state in('observed','not_observed','unknown','abnormal')),
  quantity text,
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique(organization_id,id),
  foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict
);

alter table public.shared_elimination_observations enable row level security;
create policy shared_elimination_staff_read on public.shared_elimination_observations for select to authenticated
 using(public.current_user_has_org(organization_id,array['owner','manager','staff']));

create trigger shared_elimination_audit after insert or update or delete on public.shared_elimination_observations
 for each row execute function public.audit_row();

create or replace function public.record_shared_elimination_observation(
 p_reservation_id uuid,p_observation_type text,p_observed_at timestamptz,p_observation_state text,p_quantity text default null,p_notes text default null
) returns public.shared_elimination_observations language plpgsql security definer set search_path=public,pg_temp as $$
declare v_org uuid;v_row public.shared_elimination_observations;
begin
 select organization_id into v_org from public.reservations where id=p_reservation_id and status in('checked_in','waiting_checkout') for share;
 if v_org is null or not public.current_user_has_org(v_org,array['owner','manager','staff']) then raise exception 'active stay not found' using errcode='42501';end if;
 if p_observation_type not in('urination','defecation') or p_observation_state not in('observed','not_observed','unknown','abnormal') then raise exception 'invalid shared elimination observation';end if;
 insert into public.shared_elimination_observations(organization_id,reservation_id,observation_type,observed_at,observation_state,quantity,notes,created_by)
 values(v_org,p_reservation_id,p_observation_type,p_observed_at,p_observation_state,nullif(trim(p_quantity),''),nullif(trim(p_notes),''),auth.uid()) returning * into v_row;
 return v_row;
end $$;
revoke all on function public.record_shared_elimination_observation(uuid,text,timestamptz,text,text,text) from public;
grant execute on function public.record_shared_elimination_observation(uuid,text,timestamptz,text,text,text) to authenticated;

create or replace function public.room_care_summary(p_reservation_id uuid,p_care_date date) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_org uuid;v_room text;v_result jsonb;
begin
 select r.organization_id,rm.name into v_org,v_room from public.reservations r left join public.room_allocations ra on ra.organization_id=r.organization_id and ra.reservation_id=r.id and ra.allocation_status='active' left join public.rooms rm on rm.organization_id=ra.organization_id and rm.id=ra.room_id where r.id=p_reservation_id;
 if v_org is null or not public.current_user_has_org(v_org,array['owner','manager','staff']) then raise exception 'reservation not found' using errcode='42501';end if;
 select jsonb_build_object(
  'reservation_id',p_reservation_id,'care_date',p_care_date,'room_name',v_room,
  'cats',coalesce(jsonb_agg(jsonb_build_object(
   'reservation_cat_id',rc.id,'cat_name',c.name,
   'breakfast',coalesce((select mr.status from public.care_days cd join public.meal_records mr on mr.organization_id=cd.organization_id and mr.care_day_id=cd.id where cd.organization_id=v_org and cd.reservation_cat_id=rc.id and cd.care_date=p_care_date and lower(trim(mr.label)) in('早餐','breakfast') order by coalesce(mr.actual_feeding_at,mr.created_at) desc limit 1),'pending'),
   'lunch',coalesce((select mr.status from public.care_days cd join public.meal_records mr on mr.organization_id=cd.organization_id and mr.care_day_id=cd.id where cd.organization_id=v_org and cd.reservation_cat_id=rc.id and cd.care_date=p_care_date and lower(trim(mr.label)) in('午餐','lunch') order by coalesce(mr.actual_feeding_at,mr.created_at) desc limit 1),'pending'),
   'dinner',coalesce((select mr.status from public.care_days cd join public.meal_records mr on mr.organization_id=cd.organization_id and mr.care_day_id=cd.id where cd.organization_id=v_org and cd.reservation_cat_id=rc.id and cd.care_date=p_care_date and lower(trim(mr.label)) in('晚餐','dinner') order by coalesce(mr.actual_feeding_at,mr.created_at) desc limit 1),'pending'),
   'medication',case
    when not exists(select 1 from public.medication_orders mo where mo.organization_id=v_org and mo.reservation_cat_id=rc.id and mo.confirmation_status='confirmed' and p_care_date between mo.start_date and mo.end_date) then 'not_applicable'
    when exists(select 1 from public.medication_orders mo left join public.medication_records mr on mr.organization_id=mo.organization_id and mr.medication_order_id=mo.id and (mr.scheduled_at at time zone 'Asia/Taipei')::date=p_care_date where mo.organization_id=v_org and mo.reservation_cat_id=rc.id and mo.confirmation_status='confirmed' and p_care_date between mo.start_date and mo.end_date and (mr.id is null or mr.status not in('administered','not_applicable'))) then 'pending'
    else 'administered' end
  ) order by c.name),'[]'::jsonb),
  'shared_elimination',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'type',s.observation_type,'state',s.observation_state,'quantity',s.quantity,'notes',s.notes,'observed_at',s.observed_at) order by s.observed_at desc) from public.shared_elimination_observations s where s.organization_id=v_org and s.reservation_id=p_reservation_id and (s.observed_at at time zone 'Asia/Taipei')::date=p_care_date),'[]'::jsonb)
 ) into v_result from public.reservation_cats rc join public.cats c on c.organization_id=rc.organization_id and c.id=rc.cat_id where rc.organization_id=v_org and rc.reservation_id=p_reservation_id;
 return coalesce(v_result,jsonb_build_object('reservation_id',p_reservation_id,'care_date',p_care_date,'room_name',v_room,'cats','[]'::jsonb,'shared_elimination','[]'::jsonb));
end $$;
revoke all on function public.room_care_summary(uuid,date) from public;
grant execute on function public.room_care_summary(uuid,date) to authenticated;

commit;
