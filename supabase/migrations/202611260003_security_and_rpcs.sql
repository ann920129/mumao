begin;
create or replace function public.current_user_has_org(p_organization_id uuid,p_roles text[] default null) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.organization_members m where m.organization_id=p_organization_id and m.user_id=auth.uid() and m.status='active' and (p_roles is null or m.role=any(p_roles)))
$$;
revoke all on function public.current_user_has_org(uuid,text[]) from public;
grant execute on function public.current_user_has_org(uuid,text[]) to authenticated;
create or replace function public.current_org_role(p_organization_id uuid) returns text language sql stable security definer set search_path=public,pg_temp as $$
  select role from public.organization_members where organization_id=p_organization_id and user_id=auth.uid() and status='active' limit 1
$$;
revoke all on function public.current_org_role(uuid) from public; grant execute on function public.current_org_role(uuid) to authenticated;

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.organization_members enable row level security;
create policy organizations_read on public.organizations for select to authenticated using(public.current_user_has_org(id));
create policy profiles_self_read on public.profiles for select to authenticated using(id=auth.uid());
create policy profiles_self_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy members_read on public.organization_members for select to authenticated using(user_id=auth.uid() or public.current_user_has_org(organization_id,array['owner','manager']));

do $$ declare t text; begin foreach t in array array[
  'hotel_settings','room_types','rooms','pricing_rules','owners','cats','owner_user_links','reservations','reservation_cats','room_allocations','price_snapshots','payments',
  'stay_item_categories','stay_items','item_inventory_movements','checkout_item_checks','item_alerts','care_plans','care_plan_meals','care_plan_items','care_days','meal_records','meal_record_items','water_records','urination_records','defecation_records','activity_records','medication_orders','medication_records','medication_item_links','abnormal_events','abnormal_event_updates','shifts','handover_records','tasks','notification_tasks','notification_logs','daily_reports','cleaning_records','media_files','audit_logs','legacy_imports'
] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;

-- 所有內部營運資料預設僅旅館工作人員可讀。customer 日後另由核准的 daily report 發布 RPC 提供。
do $$ declare t text; begin foreach t in array array[
  'hotel_settings','room_types','rooms','pricing_rules','owners','cats','reservations','reservation_cats','room_allocations','price_snapshots',
  'stay_item_categories','stay_items','item_inventory_movements','checkout_item_checks','item_alerts','care_plans','care_plan_meals','care_plan_items','care_days','meal_records','meal_record_items','water_records','urination_records','defecation_records','activity_records','medication_orders','medication_records','medication_item_links','abnormal_events','abnormal_event_updates','shifts','handover_records','tasks','notification_tasks','notification_logs','daily_reports','cleaning_records','media_files'
] loop execute format('create policy %I_staff_read on public.%I for select to authenticated using(public.current_user_has_org(organization_id,array[''owner'',''manager'',''staff'']))',t,t); end loop; end $$;

create policy owner_user_links_staff_read on public.owner_user_links for select to authenticated using(public.current_user_has_org(organization_id,array['owner','manager']));
create policy payments_owner_read on public.payments for select to authenticated using(public.current_user_has_org(organization_id,array['owner']));
create policy audit_owner_read on public.audit_logs for select to authenticated using(public.current_user_has_org(organization_id,array['owner']));
create policy legacy_owner_read on public.legacy_imports for select to authenticated using(public.current_user_has_org(organization_id,array['owner']));

-- 主檔與價格只有業主可變更。人員邀請/停用刻意不提供 client policy，必須走受保護後端。
do $$ declare t text; begin foreach t in array array['hotel_settings','room_types','rooms','pricing_rules'] loop
  execute format('create policy %I_owner_insert on public.%I for insert to authenticated with check(public.current_user_has_org(organization_id,array[''owner'']) and (created_by is null or created_by=auth.uid()))',t,t);
  execute format('create policy %I_owner_update on public.%I for update to authenticated using(public.current_user_has_org(organization_id,array[''owner''])) with check(public.current_user_has_org(organization_id,array[''owner'']) and (updated_by is null or updated_by=auth.uid()))',t,t);
end loop; end $$;
create policy stay_item_categories_owner_insert on public.stay_item_categories for insert to authenticated with check(public.current_user_has_org(organization_id,array['owner']));
create policy stay_item_categories_owner_update on public.stay_item_categories for update to authenticated using(public.current_user_has_org(organization_id,array['owner'])) with check(public.current_user_has_org(organization_id,array['owner']));

-- 一般工作人員可新增/更新實際照護紀錄，但不能直接刪除歷史。
do $$ declare t text; begin foreach t in array array['stay_items','checkout_item_checks','care_plans','care_plan_meals','meal_records','water_records','urination_records','defecation_records','activity_records','medication_orders','abnormal_events','shifts','handover_records','tasks','notification_tasks','daily_reports','cleaning_records','media_files'] loop
  execute format('create policy %I_staff_insert on public.%I for insert to authenticated with check(public.current_user_has_org(organization_id,array[''owner'',''manager'',''staff'']) and created_by=auth.uid())',t,t);
  execute format('create policy %I_staff_update on public.%I for update to authenticated using(public.current_user_has_org(organization_id,array[''owner'',''manager'',''staff''])) with check(public.current_user_has_org(organization_id,array[''owner'',''manager'',''staff'']) and updated_by=auth.uid())',t,t);
end loop; end $$;
create policy owners_manage_insert on public.owners for insert to authenticated with check(public.current_user_has_org(organization_id,array['owner','manager']) and created_by=auth.uid());
create policy owners_manage_update on public.owners for update to authenticated using(public.current_user_has_org(organization_id,array['owner','manager'])) with check(updated_by=auth.uid());
create policy cats_manage_insert on public.cats for insert to authenticated with check(public.current_user_has_org(organization_id,array['owner','manager']) and created_by=auth.uid());
create policy cats_manage_update on public.cats for update to authenticated using(public.current_user_has_org(organization_id,array['owner','manager'])) with check(updated_by=auth.uid());
create policy reservations_manage_insert on public.reservations for insert to authenticated with check(public.current_user_has_org(organization_id,array['owner','manager']) and created_by=auth.uid() and updated_by=auth.uid());
create policy reservations_manage_update on public.reservations for update to authenticated using(public.current_user_has_org(organization_id,array['owner','manager'])) with check(updated_by=auth.uid());

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin insert into public.profiles(id,display_name) values(new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'),''),split_part(new.email,'@',1))) on conflict(id) do nothing; return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.audit_row() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare org uuid; rid uuid; begin org=coalesce(new.organization_id,old.organization_id); rid=coalesce(new.id,old.id); insert into public.audit_logs(organization_id,actor_id,table_name,record_id,action,old_data,new_data) values(org,auth.uid(),tg_table_name,rid,lower(tg_op),case when tg_op in('UPDATE','DELETE') then to_jsonb(old) end,case when tg_op in('INSERT','UPDATE') then to_jsonb(new) end); return coalesce(new,old); end $$;
do $$ declare t text; begin foreach t in array array['reservations','room_allocations','payments','stay_items','checkout_item_checks','meal_records','water_records','urination_records','defecation_records','medication_orders','medication_records','abnormal_events','handover_records','notification_tasks','daily_reports','cleaning_records'] loop execute format('create trigger %I_audit after insert or update or delete on public.%I for each row execute function public.audit_row()',t,t); end loop; end $$;

create or replace function public.create_reservation(p_organization_id uuid,p_owner_id uuid,p_cat_ids uuid[],p_room_id uuid,p_expected_check_in_at timestamptz,p_expected_check_out_at timestamptz,p_price_snapshot jsonb default '{}',p_notes text default null,p_idempotency_key uuid default gen_random_uuid()) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid();v_id uuid;v_room_type uuid;v_room_code text;v_count int;v_nights int;v_group text;v_nightly int;v_total int;v_deposit int;v_number text;v_cat uuid;
begin
  if not public.current_user_has_org(p_organization_id,array['owner','manager']) then raise exception 'permission denied' using errcode='42501'; end if;
  if p_expected_check_out_at<=p_expected_check_in_at then raise exception 'checkout must be after checkin' using errcode='22023'; end if;
  if not exists(select 1 from public.owners where organization_id=p_organization_id and id=p_owner_id and archived_at is null) then raise exception 'owner not found'; end if;
  v_count=coalesce(array_length(p_cat_ids,1),0); if v_count<1 then raise exception 'at least one cat is required'; end if;
  select r.room_type_id,rt.code into v_room_type,v_room_code from public.rooms r join public.room_types rt on rt.id=r.room_type_id and rt.organization_id=r.organization_id where r.organization_id=p_organization_id and r.id=p_room_id and r.status<>'out_of_service';
  if v_room_type is null then raise exception 'room not found or unavailable'; end if;
  if exists(select 1 from unnest(p_cat_ids) x where not exists(select 1 from public.cats c where c.organization_id=p_organization_id and c.owner_id=p_owner_id and c.id=x and c.archived_at is null)) then raise exception 'cat does not belong to owner'; end if;
  v_nights=(p_expected_check_out_at at time zone 'Asia/Taipei')::date-(p_expected_check_in_at at time zone 'Asia/Taipei')::date; if v_nights<1 then raise exception 'reservation must include at least one night'; end if;
  v_group=case when v_count>=2 then 'multi' else 'single' end;
  select nightly_amount into v_nightly from public.pricing_rules where organization_id=p_organization_id and room_type_id=v_room_type and cat_group=v_group and active and min_nights<=v_nights and valid_from<=(p_expected_check_in_at at time zone 'Asia/Taipei')::date and (valid_until is null or valid_until>=(p_expected_check_in_at at time zone 'Asia/Taipei')::date) order by min_nights desc,valid_from desc limit 1;
  if v_nightly is null then raise exception 'no applicable pricing rule'; end if;
  v_total=v_nightly*v_nights;v_deposit=floor((v_total*3+5)/10.0);v_number='MM-'||to_char(now() at time zone 'Asia/Taipei','YYYYMMDD')||'-'||lpad(nextval('public.reservation_number_seq')::text,5,'0');
  insert into public.reservations(organization_id,owner_id,reservation_number,status,expected_check_in_at,expected_check_out_at,total_amount,deposit_amount,balance_amount,notes,idempotency_key,created_by,updated_by) values(p_organization_id,p_owner_id,v_number,'confirmed',p_expected_check_in_at,p_expected_check_out_at,v_total,v_deposit,v_total-v_deposit,p_notes,p_idempotency_key,v_user,v_user) returning id into v_id;
  foreach v_cat in array p_cat_ids loop insert into public.reservation_cats(organization_id,reservation_id,cat_id,care_snapshot,created_by) select p_organization_id,v_id,c.id,jsonb_build_object('allergies',c.allergies,'chronic_conditions',c.chronic_conditions,'food_restrictions',c.food_restrictions,'medication_info',c.medication_info,'special_care',c.special_care,'emergency_instructions',c.emergency_instructions),v_user from public.cats c where c.id=v_cat and c.organization_id=p_organization_id; end loop;
  insert into public.room_allocations(organization_id,reservation_id,room_id,check_in_at,check_out_at,created_by,updated_by) values(p_organization_id,v_id,p_room_id,p_expected_check_in_at,p_expected_check_out_at,v_user,v_user);
  insert into public.price_snapshots(organization_id,reservation_id,version_label,calculation,nights,cat_count,nightly_amount,total_amount,deposit_amount,balance_amount,created_by) values(p_organization_id,v_id,coalesce(p_price_snapshot->>'version','server-rule'),p_price_snapshot||jsonb_build_object('server_validated',true,'room_code',v_room_code),v_nights,v_count,v_nightly,v_total,v_deposit,v_total-v_deposit,v_user);
  return v_id;
exception when unique_violation then select id into v_id from public.reservations where organization_id=p_organization_id and idempotency_key=p_idempotency_key; if v_id is not null then return v_id; end if; raise; end $$;
revoke all on function public.create_reservation(uuid,uuid,uuid[],uuid,timestamptz,timestamptz,jsonb,text,uuid) from public;grant execute on function public.create_reservation(uuid,uuid,uuid[],uuid,timestamptz,timestamptz,jsonb,text,uuid) to authenticated;

create or replace function public.record_inventory_movement(p_stay_item_id uuid,p_movement_type text,p_quantity numeric,p_unit text,p_reason text,p_idempotency_key uuid) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_item public.stay_items%rowtype;v_id uuid;v_delta numeric;v_record_quantity numeric;
begin select * into v_item from public.stay_items where id=p_stay_item_id for update;if not found or not public.current_user_has_org(v_item.organization_id,array['owner','manager','staff']) then raise exception 'item not found';end if;
  select id into v_id from public.item_inventory_movements where organization_id=v_item.organization_id and stay_item_id=p_stay_item_id and idempotency_key=p_idempotency_key;if v_id is not null then return v_id;end if;
  if p_movement_type='correction' then if p_quantity=0 then raise exception 'correction must be non-zero';end if; else if p_quantity<=0 then raise exception 'quantity must be positive';end if;end if;
  v_delta=case when p_movement_type in('offered','waste','returned') then -p_quantity when p_movement_type in('received','replenishment') then p_quantity when p_movement_type='correction' then p_quantity when p_movement_type='consumed' then 0 else 0 end;
  v_record_quantity=case when p_movement_type in('offered','waste','returned') then -p_quantity else p_quantity end;
  if v_item.remaining_quantity is null then raise exception 'remaining quantity is unknown; set it explicitly before movement';end if;if v_item.remaining_quantity+v_delta<0 then raise exception 'insufficient remaining quantity';end if;
  insert into public.item_inventory_movements(organization_id,stay_item_id,movement_type,quantity,unit,reason,idempotency_key,created_by) values(v_item.organization_id,p_stay_item_id,p_movement_type,v_record_quantity,p_unit,p_reason,p_idempotency_key,auth.uid()) returning id into v_id;
  update public.stay_items set remaining_quantity=remaining_quantity+v_delta,updated_by=auth.uid() where id=p_stay_item_id;return v_id;end $$;
revoke all on function public.record_inventory_movement(uuid,text,numeric,text,text,uuid) from public;grant execute on function public.record_inventory_movement(uuid,text,numeric,text,text,uuid) to authenticated;

create or replace function public.claim_medication_task(p_record_id uuid,p_expected_version integer) returns public.medication_records language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.medication_records%rowtype;begin select * into v from public.medication_records where id=p_record_id for update;if not found or not public.current_user_has_org(v.organization_id,array['owner','manager','staff']) then raise exception 'record not found';end if;if v.version<>p_expected_version then raise exception 'record changed; reload before administering' using errcode='40001';end if;if v.status not in('pending','requires_confirmation') then raise exception 'medication task is not claimable';end if;update public.medication_records set status='in_progress',claimed_by=auth.uid(),claimed_at=now(),updated_by=auth.uid() where id=v.id returning * into v;return v;end $$;
revoke all on function public.claim_medication_task(uuid,integer) from public;grant execute on function public.claim_medication_task(uuid,integer) to authenticated;

create or replace function public.complete_task(p_task_id uuid,p_expected_version integer) returns public.tasks language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.tasks%rowtype;begin select * into v from public.tasks where id=p_task_id for update;if not found or not public.current_user_has_org(v.organization_id,array['owner','manager','staff']) then raise exception 'task not found';end if;if v.version<>p_expected_version then raise exception 'task changed; reload' using errcode='40001';end if;if v.status not in('pending','in_progress') then raise exception 'task cannot be completed';end if;update public.tasks set status='completed',completed_by=auth.uid(),completed_at=now(),updated_by=auth.uid() where id=v.id returning * into v;return v;end $$;
revoke all on function public.complete_task(uuid,integer) from public;grant execute on function public.complete_task(uuid,integer) to authenticated;

create or replace function public.dashboard_summary(p_organization_id uuid,p_today date,p_tomorrow date) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin if not public.current_user_has_org(p_organization_id,array['owner','manager','staff']) then raise exception 'permission denied';end if;return jsonb_build_object(
 'boarding_cats',(select count(*) from public.reservation_cats rc join public.reservations r on r.id=rc.reservation_id where rc.organization_id=p_organization_id and r.status in('checked_in','waiting_checkout')),
 'occupied_rooms',(select count(*) from public.rooms where organization_id=p_organization_id and status in('occupied','waiting_checkout')),
 'available_rooms',(select count(*) from public.rooms where organization_id=p_organization_id and status in('available','cleaning_completed')),
 'today_checkins',(select count(*) from public.reservations where organization_id=p_organization_id and (expected_check_in_at at time zone 'Asia/Taipei')::date=p_today and status in('confirmed','checked_in')),
 'today_checkouts',(select count(*) from public.reservations where organization_id=p_organization_id and (expected_check_out_at at time zone 'Asia/Taipei')::date=p_today and status in('checked_in','waiting_checkout','checked_out')),
 'tomorrow_checkins',(select count(*) from public.reservations where organization_id=p_organization_id and (expected_check_in_at at time zone 'Asia/Taipei')::date=p_tomorrow and status='confirmed'),
 'tomorrow_checkouts',(select count(*) from public.reservations where organization_id=p_organization_id and (expected_check_out_at at time zone 'Asia/Taipei')::date=p_tomorrow and status in('checked_in','waiting_checkout')),
 'pending_meals',(select count(*) from public.tasks where organization_id=p_organization_id and task_type='meal' and status in('pending','in_progress')),
 'pending_medications',(select count(*) from public.tasks where organization_id=p_organization_id and task_type='medication' and status in('pending','in_progress','requires_confirmation')),
 'unresolved_events',(select count(*) from public.abnormal_events where organization_id=p_organization_id and status in('open','monitoring')),
 'pending_notifications',(select count(*) from public.notification_tasks where organization_id=p_organization_id and status in('pending','message_copied','waiting_response')),
 'pending_cleaning',(select count(*) from public.cleaning_records where organization_id=p_organization_id and status<>'completed'),
 'pending_handovers',(select count(*) from public.handover_records where organization_id=p_organization_id and important and acknowledged_at is null));end $$;
revoke all on function public.dashboard_summary(uuid,date,date) from public;grant execute on function public.dashboard_summary(uuid,date,date) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('private-media','private-media',false,12582912,array['image/jpeg','image/png','image/webp','image/heic','image/heif','application/pdf']) on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy private_media_read on storage.objects for select to authenticated using(bucket_id='private-media' and public.current_user_has_org(((storage.foldername(name))[1])::uuid,array['owner','manager','staff']));
create policy private_media_insert on storage.objects for insert to authenticated with check(bucket_id='private-media' and public.current_user_has_org(((storage.foldername(name))[1])::uuid,array['owner','manager','staff']) and owner_id::text=auth.uid()::text);
create policy private_media_update on storage.objects for update to authenticated using(bucket_id='private-media' and owner_id::text=auth.uid()::text and public.current_user_has_org(((storage.foldername(name))[1])::uuid,array['owner','manager','staff'])) with check(bucket_id='private-media' and owner_id::text=auth.uid()::text);

alter publication supabase_realtime add table public.rooms,public.reservations,public.tasks,public.abnormal_events,public.notification_tasks,public.cleaning_records;
commit;
