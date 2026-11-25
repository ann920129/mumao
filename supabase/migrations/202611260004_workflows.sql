begin;
create or replace function public.bootstrap_organization(p_name text,p_slug text) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_org uuid;v_user uuid:=auth.uid();v_types jsonb:='[{"code":"jazz","name":"爵士房","max":2},{"code":"upgrade","name":"爵士升等房","max":3},{"code":"first","name":"頭等房","max":4},{"code":"little_president","name":"小總統房","max":6},{"code":"president","name":"大總統房","max":7},{"code":"standard","name":"東海標準房","max":2}]';v_item jsonb;v_rt uuid;v_prices jsonb;v_key text;v_value text;
begin
 if v_user is null then raise exception 'authentication required';end if;
 if exists(select 1 from public.organization_members where user_id=v_user and status='active' and role='owner') then raise exception 'this account already owns an organization';end if;
 insert into public.organizations(name,slug) values(trim(p_name),lower(trim(p_slug))) returning id into v_org;
 insert into public.organization_members(organization_id,user_id,role,status,joined_at) values(v_org,v_user,'owner','active',now());
 insert into public.hotel_settings(organization_id,created_by,updated_by) values(v_org,v_user,v_user);
 for v_item in select * from jsonb_array_elements(v_types) loop
   insert into public.room_types(organization_id,code,name,max_cats,sort_order,created_by,updated_by) values(v_org,v_item->>'code',v_item->>'name',(v_item->>'max')::int,(select count(*) from public.room_types where organization_id=v_org),v_user,v_user) returning id into v_rt;
   v_prices=case v_item->>'code'
    when 'jazz' then '{"single":[760,680,650,550,500],"multi":[950,860,810,680,620]}'
    when 'upgrade' then '{"single":[880,790,750,650,570],"multi":[1100,990,940,800,720]}'
    when 'first' then '{"single":[1120,1010,960,820,730],"multi":[1400,1260,1200,1010,910]}'
    when 'little_president' then '{"single":[2000,1800,1700,1600,1400],"multi":[2500,2250,2100,1800,1600]}'
    when 'president' then '{"single":[2560,2300,2150,1850,1650],"multi":[3200,2880,2700,2300,2100]}'
    else '{"single":[800,720,680,570,520],"multi":[1000,900,850,710,650]}' end::jsonb;
   insert into public.pricing_rules(organization_id,room_type_id,code,min_nights,cat_group,nightly_amount,created_by,updated_by)
   select v_org,v_rt,x.code,x.nights,g.grp,(v_prices->g.grp->>x.idx)::int,v_user,v_user from (values('REGULAR',1,0),('N06',6,1),('N13',13,2),('N30',30,3),('N90',90,4)) x(code,nights,idx) cross join (values('single'),('multi')) g(grp);
 end loop;
 insert into public.stay_item_categories(organization_id,code,name,sort_order) select v_org,x.code,x.name,x.ord from (values('luggage','行李',1),('carrier','外出籠',2),('blanket','毯子',3),('bed','床墊',4),('toy','玩具',5),('food_bowl','食盆',6),('water_bowl','水盆',7),('dry_food','乾飼料',8),('wet_food','濕食',9),('canned_food','罐頭',10),('fresh_food','鮮食',11),('snack','零食',12),('supplement','保健品',13),('medication','藥品',14),('cleaning','清潔用品',15),('other','其他',16)) x(code,name,ord);
 return v_org;
end $$;
revoke all on function public.bootstrap_organization(text,text) from public;grant execute on function public.bootstrap_organization(text,text) to authenticated;

create or replace function public.reconcile_next_day_notifications(p_organization_id uuid,p_local_today date default (now() at time zone 'Asia/Taipei')::date) returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid();v_count integer:=0;v_tomorrow date:=p_local_today+1;
begin if not public.current_user_has_org(p_organization_id,array['owner','manager','staff']) then raise exception 'permission denied';end if;
 with candidates as(
  select r.*,o.name owner_name,string_agg(c.name,'、' order by c.name) cat_names,ra.room_id,rm.name room_name
  from public.reservations r join public.owners o on o.id=r.owner_id and o.organization_id=r.organization_id join public.reservation_cats rc on rc.reservation_id=r.id and rc.organization_id=r.organization_id join public.cats c on c.id=rc.cat_id and c.organization_id=r.organization_id left join public.room_allocations ra on ra.reservation_id=r.id and ra.organization_id=r.organization_id and ra.allocation_status='active' left join public.rooms rm on rm.id=ra.room_id
  where r.organization_id=p_organization_id and r.status in('confirmed','checked_in','waiting_checkout') and ((r.expected_check_in_at at time zone 'Asia/Taipei')::date=v_tomorrow or (r.expected_check_out_at at time zone 'Asia/Taipei')::date=v_tomorrow) group by r.id,o.name,ra.room_id,rm.name
 ),upserted as(
  insert into public.notification_tasks(organization_id,reservation_id,notification_type,target_date,status,message,source_revision,created_by,updated_by)
  select p_organization_id,id,case when (expected_check_in_at at time zone 'Asia/Taipei')::date=v_tomorrow then 'next_day_checkin' else 'next_day_checkout' end,v_tomorrow,'pending',
    case when (expected_check_in_at at time zone 'Asia/Taipei')::date=v_tomorrow then owner_name||'您好，提醒您明日 '||to_char(expected_check_in_at at time zone 'Asia/Taipei','HH24:MI')||' 帶 '||cat_names||' 入住暮貓旅宿。房間：'||coalesce(room_name,'待安排')||'。請記得攜帶已確認的食物、藥品與用品，如時間異動請告知，謝謝。'
    else owner_name||'您好，提醒您明日 '||to_char(expected_check_out_at at time zone 'Asia/Taipei','HH24:MI')||' 接 '||cat_names||' 回家。現場會與您核對尾款及行李用品，謝謝。' end,version,v_user,v_user from candidates
  on conflict(organization_id,reservation_id,notification_type,target_date) do update set message=excluded.message,source_revision=excluded.source_revision,status=case when public.notification_tasks.source_revision<>excluded.source_revision then 'pending' else public.notification_tasks.status end,updated_by=v_user
  returning 1) select count(*) into v_count from upserted;return v_count;end $$;
revoke all on function public.reconcile_next_day_notifications(uuid,date) from public;grant execute on function public.reconcile_next_day_notifications(uuid,date) to authenticated;

create or replace function public.generate_care_tasks(p_reservation_id uuid) returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare v_res public.reservations%rowtype;v_user uuid:=auth.uid();v_count int;
begin select * into v_res from public.reservations where id=p_reservation_id;if not found or not public.current_user_has_org(v_res.organization_id,array['owner','manager','staff']) then raise exception 'reservation not found';end if;
 insert into public.care_days(organization_id,reservation_cat_id,care_date,day_number,created_by)
 select v_res.organization_id,rc.id,d::date,(d::date-(v_res.expected_check_in_at at time zone 'Asia/Taipei')::date)+1,v_user from public.reservation_cats rc cross join generate_series((v_res.expected_check_in_at at time zone 'Asia/Taipei')::date,(v_res.expected_check_out_at at time zone 'Asia/Taipei')::date-1,interval '1 day') d where rc.reservation_id=v_res.id on conflict do nothing;
 with generated as(
 insert into public.tasks(organization_id,reservation_id,reservation_cat_id,task_type,title,due_at,status,source_type,source_id,idempotency_key,created_by,updated_by)
 select v_res.organization_id,v_res.id,cp.reservation_cat_id,'meal',c.name||'｜'||m.label,(cd.care_date+m.scheduled_time) at time zone 'Asia/Taipei','pending','care_plan_meal',m.id,'meal:'||m.id||':'||cd.care_date,v_user,v_user
 from public.care_plans cp join public.care_plan_meals m on m.care_plan_id=cp.id and m.organization_id=cp.organization_id and m.active join public.care_days cd on cd.reservation_cat_id=cp.reservation_cat_id and cd.organization_id=cp.organization_id join public.reservation_cats rc on rc.id=cp.reservation_cat_id join public.cats c on c.id=rc.cat_id
 where cp.organization_id=v_res.organization_id and rc.reservation_id=v_res.id and cp.status='confirmed' and m.scheduled_time is not null on conflict(organization_id,idempotency_key) do nothing returning 1) select count(*) into v_count from generated;return v_count;end $$;
revoke all on function public.generate_care_tasks(uuid) from public;grant execute on function public.generate_care_tasks(uuid) to authenticated;

create or replace function public.finish_medication_task(p_record_id uuid,p_expected_version integer,p_status text,p_notes text default null) returns public.medication_records language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.medication_records%rowtype;begin select * into v from public.medication_records where id=p_record_id for update;if not found or not public.current_user_has_org(v.organization_id,array['owner','manager','staff']) then raise exception 'record not found';end if;if v.version<>p_expected_version or v.status<>'in_progress' or v.claimed_by<>auth.uid() then raise exception 'claim lost or record changed' using errcode='40001';end if;if p_status not in('administered','unsuccessful','requires_confirmation','paused','not_applicable') then raise exception 'invalid medication status';end if;
 update public.medication_records set status=p_status,actual_administered_at=case when p_status='administered' then now() end,responsible_staff=auth.uid(),notes=p_notes,updated_by=auth.uid() where id=v.id returning * into v;
 if p_status in('unsuccessful','requires_confirmation') then insert into public.tasks(organization_id,task_type,title,description,due_at,priority,status,source_type,source_id,idempotency_key,created_by,updated_by) values(v.organization_id,'medication_follow_up','用藥結果需人工確認',p_notes,now(),3,'requires_confirmation','medication_record',v.id,'med-follow-up:'||v.id,auth.uid(),auth.uid()) on conflict(organization_id,idempotency_key) do nothing;end if;return v;end $$;
revoke all on function public.finish_medication_task(uuid,integer,text,text) from public;grant execute on function public.finish_medication_task(uuid,integer,text,text) to authenticated;

create or replace function public.complete_cleaning(p_cleaning_id uuid,p_expected_version integer,p_checklist jsonb,p_notes text default null) returns public.cleaning_records language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.cleaning_records%rowtype;begin select * into v from public.cleaning_records where id=p_cleaning_id for update;if not found or not public.current_user_has_org(v.organization_id,array['owner','manager','staff']) then raise exception 'cleaning record not found';end if;if v.version<>p_expected_version then raise exception 'record changed' using errcode='40001';end if;if not(coalesce((p_checklist->>'litter_box')::boolean,false) and coalesce((p_checklist->>'bowls')::boolean,false) and coalesce((p_checklist->>'bedding')::boolean,false) and coalesce((p_checklist->>'disinfection')::boolean,false)) then raise exception 'required cleaning checklist is incomplete';end if;
 update public.cleaning_records set status='completed',checklist=p_checklist,notes=p_notes,completed_at=now(),responsible_staff=auth.uid(),updated_by=auth.uid() where id=v.id returning * into v;update public.rooms set status='available',updated_by=auth.uid() where id=v.room_id and organization_id=v.organization_id;return v;end $$;
revoke all on function public.complete_cleaning(uuid,integer,jsonb,text) from public;grant execute on function public.complete_cleaning(uuid,integer,jsonb,text) to authenticated;
commit;
