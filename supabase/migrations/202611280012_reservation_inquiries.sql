begin;

alter table public.reservations add column room_type_id uuid;
alter table public.reservations add column special_requests text;
alter table public.reservations add constraint reservations_room_type_fk foreign key(organization_id,room_type_id) references public.room_types(organization_id,id) on delete restrict;
update public.reservations r set room_type_id=rm.room_type_id from public.room_allocations a join public.rooms rm on rm.organization_id=a.organization_id and rm.id=a.room_id where a.organization_id=r.organization_id and a.reservation_id=r.id and a.allocation_status='active';
create index reservations_upcoming_idx on public.reservations(organization_id,expected_check_in_at,id);

alter table public.price_snapshots drop constraint if exists price_snapshots_organization_id_reservation_id_key;
alter table public.price_snapshots add column version integer not null default 1 check(version>=1);
alter table public.price_snapshots add constraint price_snapshots_reservation_version_key unique(organization_id,reservation_id,version);

create or replace function public.guard_reservation_update() returns trigger language plpgsql set search_path=public,pg_temp as $$
declare v_room_status text;v_role text;
begin
 if new.organization_id<>old.organization_id or new.reservation_number<>old.reservation_number or new.idempotency_key<>old.idempotency_key or new.booked_at<>old.booked_at or new.created_at<>old.created_at or new.created_by<>old.created_by then raise exception 'immutable reservation fields cannot be changed';end if;
 v_role=public.current_org_role(old.organization_id);
 if new.owner_id<>old.owner_id and (old.status not in('draft','pending') or v_role not in('owner','manager')) then raise exception 'owner can only change while inquiry is editable' using errcode='42501';end if;
 if (new.total_amount,new.deposit_amount,new.additional_charges,new.discount_amount,new.balance_amount,new.currency,new.payment_status) is distinct from (old.total_amount,old.deposit_amount,old.additional_charges,old.discount_amount,old.balance_amount,old.currency,old.payment_status) and v_role<>'owner' then raise exception 'only owner may change pricing or payment fields' using errcode='42501';end if;
 if new.status<>old.status and new.status='checked_in' then
   if not exists(select 1 from public.stay_workflows where organization_id=old.organization_id and reservation_id=old.id and workflow_type='checkin' and status='completed') then raise exception 'completed check-in workflow required';end if;
   select rm.status into v_room_status from public.room_allocations ra join public.rooms rm on rm.id=ra.room_id and rm.organization_id=ra.organization_id where ra.organization_id=old.organization_id and ra.reservation_id=old.id and ra.allocation_status='active';
   if v_room_status is null or v_room_status not in('available','reserved','waiting_checkin','cleaning_completed') then raise exception 'room is not ready for check-in';end if;
 end if;
 if new.status<>old.status and new.status='checked_out' and not exists(select 1 from public.stay_workflows where organization_id=old.organization_id and reservation_id=old.id and workflow_type='checkout' and status='completed') then raise exception 'completed checkout workflow required';end if;
 return new;
end $$;

create or replace function public.create_reservation(p_organization_id uuid,p_owner_id uuid,p_cat_ids uuid[],p_room_id uuid,p_expected_check_in_at timestamptz,p_expected_check_out_at timestamptz,p_price_snapshot jsonb default '{}',p_notes text default null,p_idempotency_key uuid default gen_random_uuid()) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid();v_id uuid;v_room_type uuid;v_room_code text;v_count int;v_nights int;v_group text;v_nightly int;v_total int;v_deposit int;v_number text;v_cat uuid;
begin
  if not public.current_user_has_org(p_organization_id,array['owner','manager']) then raise exception 'permission denied' using errcode='42501';end if;
  if p_expected_check_out_at<=p_expected_check_in_at then raise exception 'checkout must be after checkin' using errcode='22023';end if;
  if not exists(select 1 from public.owners where organization_id=p_organization_id and id=p_owner_id and archived_at is null) then raise exception 'owner not found';end if;
  v_count=coalesce(array_length(p_cat_ids,1),0);if v_count<1 then raise exception 'at least one cat is required';end if;
  select r.room_type_id,rt.code into v_room_type,v_room_code from public.rooms r join public.room_types rt on rt.id=r.room_type_id and rt.organization_id=r.organization_id where r.organization_id=p_organization_id and r.id=p_room_id and r.status<>'out_of_service';
  if v_room_type is null then raise exception 'room not found or unavailable';end if;
  if exists(select 1 from unnest(p_cat_ids) x where not exists(select 1 from public.cats c where c.organization_id=p_organization_id and c.owner_id=p_owner_id and c.id=x and c.archived_at is null)) then raise exception 'cat does not belong to owner';end if;
  v_nights=(p_expected_check_out_at at time zone 'Asia/Taipei')::date-(p_expected_check_in_at at time zone 'Asia/Taipei')::date;if v_nights<1 then raise exception 'reservation must include at least one night';end if;
  v_group=case when v_count>=2 then 'multi' else 'single' end;
  select nightly_amount into v_nightly from public.pricing_rules where organization_id=p_organization_id and room_type_id=v_room_type and cat_group=v_group and active and min_nights<=v_nights and valid_from<=(p_expected_check_in_at at time zone 'Asia/Taipei')::date and(valid_until is null or valid_until>=(p_expected_check_in_at at time zone 'Asia/Taipei')::date) order by min_nights desc,valid_from desc limit 1;
  if v_nightly is null then raise exception 'no applicable pricing rule';end if;
  v_total=v_nightly*v_nights;v_deposit=floor((v_total*3+5)/10.0);v_number='MM-'||to_char(now() at time zone 'Asia/Taipei','YYYYMMDD')||'-'||lpad(nextval('public.reservation_number_seq')::text,5,'0');
  insert into public.reservations(organization_id,owner_id,room_type_id,reservation_number,status,expected_check_in_at,expected_check_out_at,total_amount,deposit_amount,balance_amount,notes,idempotency_key,created_by,updated_by) values(p_organization_id,p_owner_id,v_room_type,v_number,'confirmed',p_expected_check_in_at,p_expected_check_out_at,v_total,v_deposit,v_total-v_deposit,p_notes,p_idempotency_key,v_user,v_user) returning id into v_id;
  foreach v_cat in array p_cat_ids loop insert into public.reservation_cats(organization_id,reservation_id,cat_id,care_snapshot,created_by) select p_organization_id,v_id,c.id,jsonb_build_object('allergies',c.allergies,'chronic_conditions',c.chronic_conditions,'food_restrictions',c.food_restrictions,'medication_info',c.medication_info,'special_care',c.special_care,'emergency_instructions',c.emergency_instructions),v_user from public.cats c where c.id=v_cat and c.organization_id=p_organization_id;end loop;
  insert into public.room_allocations(organization_id,reservation_id,room_id,check_in_at,check_out_at,created_by,updated_by) values(p_organization_id,v_id,p_room_id,p_expected_check_in_at,p_expected_check_out_at,v_user,v_user);
  insert into public.price_snapshots(organization_id,reservation_id,version_label,calculation,nights,cat_count,nightly_amount,total_amount,deposit_amount,balance_amount,created_by) values(p_organization_id,v_id,coalesce(p_price_snapshot->>'version','server-rule'),p_price_snapshot||jsonb_build_object('server_validated',true,'room_code',v_room_code),v_nights,v_count,v_nightly,v_total,v_deposit,v_total-v_deposit,v_user);
  return v_id;
exception when unique_violation then select id into v_id from public.reservations where organization_id=p_organization_id and idempotency_key=p_idempotency_key;if v_id is not null then return v_id;end if;raise;end $$;
revoke all on function public.create_reservation(uuid,uuid,uuid[],uuid,timestamptz,timestamptz,jsonb,text,uuid) from public;
grant execute on function public.create_reservation(uuid,uuid,uuid[],uuid,timestamptz,timestamptz,jsonb,text,uuid) to authenticated;

create or replace function public.create_reservation_inquiry(p_organization_id uuid,p_owner_id uuid,p_cat_ids uuid[],p_room_type_id uuid,p_expected_check_in_at timestamptz,p_expected_check_out_at timestamptz,p_price_snapshot jsonb default '{}',p_special_requests text default null,p_notes text default null,p_idempotency_key uuid default gen_random_uuid()) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid();v_id uuid;v_room_code text;v_max int;v_count int;v_nights int;v_group text;v_nightly int;v_total int;v_deposit int;v_number text;v_cat uuid;
begin
 if not public.current_user_has_org(p_organization_id,array['owner','manager']) then raise exception 'permission denied' using errcode='42501';end if;
 if p_expected_check_out_at<=p_expected_check_in_at then raise exception 'checkout must be after checkin' using errcode='22023';end if;
 if not exists(select 1 from public.owners where organization_id=p_organization_id and id=p_owner_id and archived_at is null) then raise exception 'owner not found';end if;
 v_count=coalesce(array_length(p_cat_ids,1),0);if v_count<1 then raise exception 'at least one cat is required';end if;
 select code,max_cats into v_room_code,v_max from public.room_types where organization_id=p_organization_id and id=p_room_type_id and active;
 if v_room_code is null then raise exception 'room type not found';end if;if v_count>v_max then raise exception 'room capacity exceeded';end if;
 if exists(select 1 from unnest(p_cat_ids) x where not exists(select 1 from public.cats c where c.organization_id=p_organization_id and c.owner_id=p_owner_id and c.id=x and c.archived_at is null)) then raise exception 'cat does not belong to owner';end if;
 v_nights=(p_expected_check_out_at at time zone 'Asia/Taipei')::date-(p_expected_check_in_at at time zone 'Asia/Taipei')::date;if v_nights<1 then raise exception 'reservation must include at least one night';end if;
 v_group=case when v_count>=2 then 'multi' else 'single' end;
 select nightly_amount into v_nightly from public.pricing_rules where organization_id=p_organization_id and room_type_id=p_room_type_id and cat_group=v_group and active and min_nights<=v_nights and valid_from<=(p_expected_check_in_at at time zone 'Asia/Taipei')::date and(valid_until is null or valid_until>=(p_expected_check_in_at at time zone 'Asia/Taipei')::date) order by min_nights desc,valid_from desc limit 1;
 if v_nightly is null then raise exception 'no applicable pricing rule';end if;
 v_total=v_nightly*v_nights;v_deposit=floor((v_total*3+5)/10.0);v_number='MM-'||to_char(now() at time zone 'Asia/Taipei','YYYYMMDD')||'-'||lpad(nextval('public.reservation_number_seq')::text,5,'0');
 insert into public.reservations(organization_id,owner_id,room_type_id,reservation_number,status,expected_check_in_at,expected_check_out_at,total_amount,deposit_amount,balance_amount,special_requests,notes,idempotency_key,created_by,updated_by) values(p_organization_id,p_owner_id,p_room_type_id,v_number,'draft',p_expected_check_in_at,p_expected_check_out_at,v_total,v_deposit,v_total-v_deposit,nullif(trim(p_special_requests),''),nullif(trim(p_notes),''),p_idempotency_key,v_user,v_user) returning id into v_id;
 foreach v_cat in array p_cat_ids loop insert into public.reservation_cats(organization_id,reservation_id,cat_id,care_snapshot,created_by) select p_organization_id,v_id,c.id,jsonb_build_object('allergies',c.allergies,'chronic_conditions',c.chronic_conditions,'food_restrictions',c.food_restrictions,'medication_info',c.medication_info,'special_care',c.special_care,'emergency_instructions',c.emergency_instructions),v_user from public.cats c where c.id=v_cat and c.organization_id=p_organization_id;end loop;
 insert into public.price_snapshots(organization_id,reservation_id,version_label,version,calculation,nights,cat_count,nightly_amount,total_amount,deposit_amount,balance_amount,created_by) values(p_organization_id,v_id,coalesce(p_price_snapshot->>'version','legacy-2026-06-30'),1,p_price_snapshot||jsonb_build_object('server_validated',true,'room_code',v_room_code),v_nights,v_count,v_nightly,v_total,v_deposit,v_total-v_deposit,v_user);
 return v_id;
exception when unique_violation then select id into v_id from public.reservations where organization_id=p_organization_id and idempotency_key=p_idempotency_key;if v_id is not null then return v_id;end if;raise;end $$;
revoke all on function public.create_reservation_inquiry(uuid,uuid,uuid[],uuid,timestamptz,timestamptz,jsonb,text,text,uuid) from public;
grant execute on function public.create_reservation_inquiry(uuid,uuid,uuid[],uuid,timestamptz,timestamptz,jsonb,text,text,uuid) to authenticated;

create or replace function public.update_reservation_inquiry(p_reservation_id uuid,p_owner_id uuid,p_cat_ids uuid[],p_room_type_id uuid,p_expected_check_in_at timestamptz,p_expected_check_out_at timestamptz,p_price_snapshot jsonb,p_special_requests text,p_notes text,p_expected_version integer) returns public.reservations language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.reservations%rowtype;v_user uuid:=auth.uid();v_room_code text;v_max int;v_count int;v_nights int;v_group text;v_nightly int;v_total int;v_deposit int;v_snapshot_version int;v_cat uuid;
begin
 select * into v from public.reservations where id=p_reservation_id for update;
 if not found or not public.current_user_has_org(v.organization_id,array['owner']) then raise exception 'only owner may revise a quotation' using errcode='42501';end if;
 if v.version<>p_expected_version then raise exception 'reservation changed; reload' using errcode='40001';end if;if v.status not in('draft','pending') then raise exception 'confirmed financial records cannot be overwritten';end if;
 if p_expected_check_out_at<=p_expected_check_in_at then raise exception 'checkout must be after checkin' using errcode='22023';end if;
 if not exists(select 1 from public.owners where organization_id=v.organization_id and id=p_owner_id and archived_at is null) then raise exception 'owner not found';end if;
 v_count=coalesce(array_length(p_cat_ids,1),0);if v_count<1 then raise exception 'at least one cat is required';end if;
 select code,max_cats into v_room_code,v_max from public.room_types where organization_id=v.organization_id and id=p_room_type_id and active;if v_room_code is null then raise exception 'room type not found';end if;if v_count>v_max then raise exception 'room capacity exceeded';end if;
 if exists(select 1 from unnest(p_cat_ids) x where not exists(select 1 from public.cats c where c.organization_id=v.organization_id and c.owner_id=p_owner_id and c.id=x and c.archived_at is null)) then raise exception 'cat does not belong to owner';end if;
 v_nights=(p_expected_check_out_at at time zone 'Asia/Taipei')::date-(p_expected_check_in_at at time zone 'Asia/Taipei')::date;v_group=case when v_count>=2 then 'multi' else 'single' end;
 select nightly_amount into v_nightly from public.pricing_rules where organization_id=v.organization_id and room_type_id=p_room_type_id and cat_group=v_group and active and min_nights<=v_nights and valid_from<=(p_expected_check_in_at at time zone 'Asia/Taipei')::date and(valid_until is null or valid_until>=(p_expected_check_in_at at time zone 'Asia/Taipei')::date) order by min_nights desc,valid_from desc limit 1;if v_nightly is null then raise exception 'no applicable pricing rule';end if;
 v_total=v_nightly*v_nights;v_deposit=floor((v_total*3+5)/10.0);
 delete from public.reservation_cats where organization_id=v.organization_id and reservation_id=v.id;
 foreach v_cat in array p_cat_ids loop insert into public.reservation_cats(organization_id,reservation_id,cat_id,care_snapshot,created_by) select v.organization_id,v.id,c.id,jsonb_build_object('allergies',c.allergies,'chronic_conditions',c.chronic_conditions,'food_restrictions',c.food_restrictions,'medication_info',c.medication_info,'special_care',c.special_care,'emergency_instructions',c.emergency_instructions),v_user from public.cats c where c.id=v_cat and c.organization_id=v.organization_id;end loop;
 update public.reservations set owner_id=p_owner_id,room_type_id=p_room_type_id,expected_check_in_at=p_expected_check_in_at,expected_check_out_at=p_expected_check_out_at,total_amount=v_total,deposit_amount=v_deposit,balance_amount=v_total-v_deposit,special_requests=nullif(trim(p_special_requests),''),notes=nullif(trim(p_notes),''),updated_by=v_user where id=v.id returning * into v;
 select coalesce(max(version),0)+1 into v_snapshot_version from public.price_snapshots where organization_id=v.organization_id and reservation_id=v.id;
 insert into public.price_snapshots(organization_id,reservation_id,version_label,version,calculation,nights,cat_count,nightly_amount,total_amount,deposit_amount,balance_amount,created_by) values(v.organization_id,v.id,coalesce(p_price_snapshot->>'version','legacy-2026-06-30'),v_snapshot_version,p_price_snapshot||jsonb_build_object('server_validated',true,'room_code',v_room_code),v_nights,v_count,v_nightly,v_total,v_deposit,v_total-v_deposit,v_user);
 return v;
end $$;
revoke all on function public.update_reservation_inquiry(uuid,uuid,uuid[],uuid,timestamptz,timestamptz,jsonb,text,text,integer) from public;
grant execute on function public.update_reservation_inquiry(uuid,uuid,uuid[],uuid,timestamptz,timestamptz,jsonb,text,text,integer) to authenticated;

commit;
