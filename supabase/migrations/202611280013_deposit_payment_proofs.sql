begin;

alter table public.reservations drop constraint reservations_payment_status_check;
alter table public.reservations add constraint reservations_payment_status_check check(payment_status in('unpaid','proof_pending','partially_paid','deposit_paid','paid','refunded','payment_exception'));

create table public.payment_proofs(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,reservation_id uuid not null,
 declared_amount integer not null check(declared_amount>0),paid_at timestamptz not null,bank_account_last5 text check(bank_account_last5 is null or bank_account_last5~'^[0-9]{5}$'),notes text,
 status text not null default 'uploaded' check(status in('uploaded','verified','rejected','archived')),uploaded_by uuid not null references auth.users(id),uploaded_at timestamptz not null default now(),verified_by uuid references auth.users(id),verified_at timestamptz,rejection_reason text,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid not null references auth.users(id),updated_by uuid not null references auth.users(id),version integer not null default 1,
 unique(organization_id,id),foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict
);
create table public.payment_proof_media(
 organization_id uuid not null references public.organizations(id) on delete restrict,payment_proof_id uuid not null,media_id uuid not null,sort_order integer not null default 0,created_at timestamptz not null default now(),created_by uuid not null references auth.users(id),
 primary key(organization_id,payment_proof_id,media_id),unique(organization_id,media_id),foreign key(organization_id,payment_proof_id) references public.payment_proofs(organization_id,id) on delete restrict,foreign key(organization_id,media_id) references public.media_files(organization_id,id) on delete restrict
);
alter table public.payments add column payment_proof_id uuid;
alter table public.payments add constraint payments_proof_fk foreign key(organization_id,payment_proof_id) references public.payment_proofs(organization_id,id) on delete restrict;
create unique index payments_one_per_proof on public.payments(organization_id,payment_proof_id) where payment_proof_id is not null;
create trigger payment_proofs_updated before update on public.payment_proofs for each row execute function public.set_updated_at();
create trigger payment_proofs_audit after insert or update or delete on public.payment_proofs for each row execute function public.audit_row();

alter table public.payment_proofs enable row level security;
alter table public.payment_proof_media enable row level security;
create policy payment_proofs_staff_select on public.payment_proofs for select to authenticated using(public.current_user_has_org(organization_id,array['owner','manager','staff']));
create policy payment_proof_media_staff_select on public.payment_proof_media for select to authenticated using(public.current_user_has_org(organization_id,array['owner','manager','staff']));

create or replace function public.guard_reservation_update() returns trigger language plpgsql set search_path=public,pg_temp as $$
declare v_room_status text;v_role text;v_financial_changed boolean;
begin
 if new.organization_id<>old.organization_id or new.reservation_number<>old.reservation_number or new.idempotency_key<>old.idempotency_key or new.booked_at<>old.booked_at or new.created_at<>old.created_at or new.created_by<>old.created_by then raise exception 'immutable reservation fields cannot be changed';end if;
 v_role=public.current_org_role(old.organization_id);
 if new.owner_id<>old.owner_id and(old.status not in('draft','pending') or v_role not in('owner','manager')) then raise exception 'owner can only change while inquiry is editable' using errcode='42501';end if;
 v_financial_changed=(new.total_amount,new.deposit_amount,new.additional_charges,new.discount_amount,new.balance_amount,new.currency,new.payment_status) is distinct from(old.total_amount,old.deposit_amount,old.additional_charges,old.discount_amount,old.balance_amount,old.currency,old.payment_status);
 if v_financial_changed and v_role<>'owner' and not((new.total_amount,new.deposit_amount,new.additional_charges,new.discount_amount,new.balance_amount,new.currency) is not distinct from(old.total_amount,old.deposit_amount,old.additional_charges,old.discount_amount,old.balance_amount,old.currency) and new.payment_status='proof_pending' and old.payment_status in('unpaid','proof_pending')) then raise exception 'only owner may change pricing or payment fields' using errcode='42501';end if;
 if new.status<>old.status and new.status='checked_in' then if not exists(select 1 from public.stay_workflows where organization_id=old.organization_id and reservation_id=old.id and workflow_type='checkin' and status='completed') then raise exception 'completed check-in workflow required';end if;select rm.status into v_room_status from public.room_allocations ra join public.rooms rm on rm.id=ra.room_id and rm.organization_id=ra.organization_id where ra.organization_id=old.organization_id and ra.reservation_id=old.id and ra.allocation_status='active';if v_room_status is null or v_room_status not in('available','reserved','waiting_checkin','cleaning_completed') then raise exception 'room is not ready for check-in';end if;end if;
 if new.status<>old.status and new.status='checked_out' and not exists(select 1 from public.stay_workflows where organization_id=old.organization_id and reservation_id=old.id and workflow_type='checkout' and status='completed') then raise exception 'completed checkout workflow required';end if;
 return new;
end $$;

create or replace function public.begin_media_upload(p_organization_id uuid,p_reservation_id uuid,p_category text,p_original_name text,p_original_mime text,p_main_size bigint,p_thumbnail_size bigint,p_width integer,p_height integer,p_reservation_cat_id uuid default null,p_stay_item_id uuid default null,p_abnormal_event_id uuid default null) returns public.media_files language plpgsql security definer set search_path=public,storage,pg_temp as $$
declare v public.media_files%rowtype;v_id uuid:=gen_random_uuid();v_reservation uuid:=p_reservation_id;v_linked_reservation uuid;v_path text;v_thumb text;v_user uuid:=auth.uid();
begin
 if not public.current_user_has_org(p_organization_id,array['owner','manager','staff']) then raise exception 'permission denied';end if;
 if p_category not in('cat_profile','checkin_condition','luggage','food_packaging','food_instructions','supplement','medication_packaging','prescription','daily_care','abnormal_event','elimination','checkout_luggage','payment_proof','other') then raise exception 'invalid media category';end if;
 if p_original_mime not in('image/jpeg','image/png','image/webp','image/heic','image/heif') then raise exception 'invalid original image type';end if;
 if p_main_size<=0 or p_main_size>12582912 or p_thumbnail_size<=0 or p_thumbnail_size>2097152 or p_width<=0 or p_height<=0 then raise exception 'invalid processed image metadata';end if;
 if p_reservation_id is not null and not exists(select 1 from public.reservations where organization_id=p_organization_id and id=p_reservation_id) then raise exception 'reservation not found';end if;
 if p_reservation_cat_id is not null then select reservation_id into v_linked_reservation from public.reservation_cats where organization_id=p_organization_id and id=p_reservation_cat_id;if not found then raise exception 'stay cat not found';end if;v_reservation=coalesce(v_reservation,v_linked_reservation);if v_reservation<>v_linked_reservation then raise exception 'stay cat does not belong to reservation';end if;end if;
 if p_stay_item_id is not null then select reservation_id into v_linked_reservation from public.stay_items where organization_id=p_organization_id and id=p_stay_item_id and archived_at is null;if not found then raise exception 'stay item not found';end if;v_reservation=coalesce(v_reservation,v_linked_reservation);if v_reservation<>v_linked_reservation then raise exception 'stay item does not belong to reservation';end if;end if;
 if p_abnormal_event_id is not null then select rc.reservation_id into v_linked_reservation from public.abnormal_events ae join public.reservation_cats rc on rc.organization_id=ae.organization_id and rc.id=ae.reservation_cat_id where ae.organization_id=p_organization_id and ae.id=p_abnormal_event_id;if not found then raise exception 'abnormal event not found';end if;v_reservation=coalesce(v_reservation,v_linked_reservation);if v_reservation<>v_linked_reservation then raise exception 'event does not belong to reservation';end if;end if;
 if v_reservation is null then raise exception 'media must be linked to a reservation';end if;
 v_path=p_organization_id||'/'||v_reservation||'/'||p_category||'/'||v_id||'/main.webp';v_thumb=p_organization_id||'/'||v_reservation||'/'||p_category||'/'||v_id||'/thumb.webp';
 insert into public.media_files(id,organization_id,reservation_id,reservation_cat_id,stay_item_id,abnormal_event_id,category,storage_bucket,storage_path,original_name,mime_type,file_size,width,height,metadata,status,created_by,updated_by) values(v_id,p_organization_id,v_reservation,p_reservation_cat_id,p_stay_item_id,p_abnormal_event_id,p_category,'private-media',v_path,left(p_original_name,500),'image/webp',p_main_size,p_width,p_height,jsonb_build_object('thumbnail_path',v_thumb,'thumbnail_size',p_thumbnail_size,'original_mime',p_original_mime,'privacy_processed',true),'uploading',v_user,v_user) returning * into v;return v;
end $$;
revoke all on function public.begin_media_upload(uuid,uuid,text,text,text,bigint,bigint,integer,integer,uuid,uuid,uuid) from public;grant execute on function public.begin_media_upload(uuid,uuid,text,text,text,bigint,bigint,integer,integer,uuid,uuid,uuid) to authenticated;

create or replace function public.register_payment_proof(p_reservation_id uuid,p_media_ids uuid[],p_declared_amount integer,p_paid_at timestamptz,p_bank_account_last5 text default null,p_notes text default null) returns public.payment_proofs language plpgsql security definer set search_path=public,pg_temp as $$
declare v_res public.reservations%rowtype;v public.payment_proofs%rowtype;v_user uuid:=auth.uid();v_media uuid;v_order int:=0;
begin select * into v_res from public.reservations where id=p_reservation_id for update;if not found or not public.current_user_has_org(v_res.organization_id,array['owner','manager','staff']) then raise exception 'reservation not found';end if;
 if p_declared_amount<=0 or p_paid_at>now()+interval '1 day' then raise exception 'invalid payment details';end if;if nullif(trim(p_bank_account_last5),'') is not null and trim(p_bank_account_last5)!~'^[0-9]{5}$' then raise exception 'bank account last five digits must be numeric';end if;
 if coalesce(array_length(p_media_ids,1),0) not between 1 and 8 or cardinality(p_media_ids)<>(select count(distinct x) from unnest(p_media_ids) x) then raise exception 'one to eight unique payment images are required';end if;
 if exists(select 1 from unnest(p_media_ids) x where not exists(select 1 from public.media_files where organization_id=v_res.organization_id and id=x and reservation_id=v_res.id and category='payment_proof' and status='active')) then raise exception 'active payment proof image not found';end if;
 insert into public.payment_proofs(organization_id,reservation_id,declared_amount,paid_at,bank_account_last5,notes,uploaded_by,created_by,updated_by) values(v_res.organization_id,v_res.id,p_declared_amount,p_paid_at,nullif(trim(p_bank_account_last5),''),nullif(trim(p_notes),''),v_user,v_user,v_user) returning * into v;
 foreach v_media in array p_media_ids loop insert into public.payment_proof_media(organization_id,payment_proof_id,media_id,sort_order,created_by) values(v.organization_id,v.id,v_media,v_order,v_user);v_order=v_order+1;end loop;
 update public.reservations set status=case when status='draft' then 'pending' else status end,payment_status='proof_pending',updated_by=v_user where id=v_res.id;return v;end $$;
revoke all on function public.register_payment_proof(uuid,uuid[],integer,timestamptz,text,text) from public;grant execute on function public.register_payment_proof(uuid,uuid[],integer,timestamptz,text,text) to authenticated;

create or replace function public.verify_payment_proof(p_payment_proof_id uuid,p_actual_amount integer,p_method text,p_reference text,p_notes text,p_expected_version integer) returns public.payment_proofs language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.payment_proofs%rowtype;v_res public.reservations%rowtype;v_user uuid:=auth.uid();v_paid integer;
begin select * into v from public.payment_proofs where id=p_payment_proof_id for update;if not found or not public.current_user_has_org(v.organization_id,array['owner']) then raise exception 'only owner may verify payment' using errcode='42501';end if;if v.version<>p_expected_version then raise exception 'payment proof changed; reload' using errcode='40001';end if;if v.status<>'uploaded' then raise exception 'payment proof is not pending verification';end if;if p_actual_amount<=0 then raise exception 'verified amount must be positive';end if;
 select * into v_res from public.reservations where organization_id=v.organization_id and id=v.reservation_id for update;
 insert into public.payments(organization_id,reservation_id,payment_proof_id,amount,payment_type,method,paid_at,reference,notes,created_by) values(v.organization_id,v.reservation_id,v.id,p_actual_amount,'deposit',nullif(trim(p_method),''),v.paid_at,nullif(trim(p_reference),''),nullif(trim(p_notes),''),v_user);
 update public.payment_proofs set status='verified',verified_by=v_user,verified_at=now(),updated_by=v_user where id=v.id returning * into v;
 select coalesce(sum(case when payment_type='refund' then -amount else amount end),0) into v_paid from public.payments where organization_id=v.organization_id and reservation_id=v.reservation_id;
 update public.reservations set payment_status=case when v_paid>=total_amount+additional_charges-discount_amount then 'paid' when v_paid>=deposit_amount then 'deposit_paid' else 'partially_paid' end,updated_by=v_user where id=v_res.id;return v;end $$;
revoke all on function public.verify_payment_proof(uuid,integer,text,text,text,integer) from public;grant execute on function public.verify_payment_proof(uuid,integer,text,text,text,integer) to authenticated;

create or replace function public.reject_payment_proof(p_payment_proof_id uuid,p_reason text,p_expected_version integer) returns public.payment_proofs language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.payment_proofs%rowtype;begin select * into v from public.payment_proofs where id=p_payment_proof_id for update;if not found or not public.current_user_has_org(v.organization_id,array['owner']) then raise exception 'only owner may reject payment' using errcode='42501';end if;if v.version<>p_expected_version or v.status<>'uploaded' then raise exception 'payment proof changed; reload' using errcode='40001';end if;if length(trim(coalesce(p_reason,'')))<3 then raise exception 'rejection reason is required';end if;update public.payment_proofs set status='rejected',rejection_reason=trim(p_reason),verified_by=auth.uid(),verified_at=now(),updated_by=auth.uid() where id=v.id returning * into v;update public.reservations set payment_status='payment_exception',updated_by=auth.uid() where id=v.reservation_id;return v;end $$;
revoke all on function public.reject_payment_proof(uuid,text,integer) from public;grant execute on function public.reject_payment_proof(uuid,text,integer) to authenticated;

commit;
