begin;
create or replace function public.guard_reservation_update() returns trigger language plpgsql set search_path=public,pg_temp as $$
declare v_room_status text;v_role text;
begin
 if new.organization_id<>old.organization_id or new.owner_id<>old.owner_id or new.reservation_number<>old.reservation_number or new.idempotency_key<>old.idempotency_key or new.booked_at<>old.booked_at or new.created_at<>old.created_at or new.created_by<>old.created_by then raise exception 'immutable reservation fields cannot be changed';end if;
 v_role=public.current_org_role(old.organization_id);
 if (new.total_amount,new.deposit_amount,new.additional_charges,new.discount_amount,new.balance_amount,new.currency,new.payment_status) is distinct from (old.total_amount,old.deposit_amount,old.additional_charges,old.discount_amount,old.balance_amount,old.currency,old.payment_status) and v_role<>'owner' then raise exception 'only owner may change pricing or payment fields' using errcode='42501';end if;
 if new.status<>old.status and new.status='checked_in' then
   if not exists(select 1 from public.stay_workflows where organization_id=old.organization_id and reservation_id=old.id and workflow_type='checkin' and status='completed') then raise exception 'completed check-in workflow required';end if;
   select rm.status into v_room_status from public.room_allocations ra join public.rooms rm on rm.id=ra.room_id and rm.organization_id=ra.organization_id where ra.organization_id=old.organization_id and ra.reservation_id=old.id and ra.allocation_status='active';
   if v_room_status is null or v_room_status not in('available','reserved','waiting_checkin','cleaning_completed') then raise exception 'room is not ready for check-in';end if;
 end if;
 if new.status<>old.status and new.status='checked_out' and not exists(select 1 from public.stay_workflows where organization_id=old.organization_id and reservation_id=old.id and workflow_type='checkout' and status='completed') then raise exception 'completed checkout workflow required';end if;
 return new;
end $$;
create trigger reservations_guard before update on public.reservations for each row execute function public.guard_reservation_update();

create or replace function public.save_checkout_item_check(p_stay_item_id uuid,p_status text,p_used_quantity numeric default null,p_remaining_quantity numeric default null,p_actual_returned_quantity numeric default null,p_notes text default null,p_expected_version integer default null) returns public.checkout_item_checks language plpgsql security definer set search_path=public,pg_temp as $$
declare v_item public.stay_items%rowtype;v_check public.checkout_item_checks%rowtype;v_user uuid:=auth.uid();v_expected numeric;
begin
 select * into v_item from public.stay_items where id=p_stay_item_id for update;
 if not found or not public.current_user_has_org(v_item.organization_id,array['owner','manager','staff']) then raise exception 'stay item not found';end if;
 if p_status not in('pending','returned','fully_consumed','left_with_permission','missing','damaged','not_applicable') then raise exception 'invalid return status';end if;
 if coalesce(p_used_quantity,0)<0 or coalesce(p_remaining_quantity,0)<0 or coalesce(p_actual_returned_quantity,0)<0 then raise exception 'quantities cannot be negative';end if;
 v_expected=case when v_item.return_required then p_remaining_quantity else 0 end;
 select * into v_check from public.checkout_item_checks where organization_id=v_item.organization_id and stay_item_id=v_item.id for update;
 if found then
   if p_expected_version is not null and v_check.version<>p_expected_version then raise exception 'item check changed; reload' using errcode='40001';end if;
   update public.checkout_item_checks set used_quantity=p_used_quantity,remaining_quantity=p_remaining_quantity,expected_return_quantity=v_expected,actual_return_quantity=p_actual_returned_quantity,status=p_status,notes=nullif(trim(p_notes),''),verified_by=case when p_status<>'pending' then v_user end,verified_at=case when p_status<>'pending' then now() end,updated_by=v_user where id=v_check.id returning * into v_check;
 else
   insert into public.checkout_item_checks(organization_id,stay_item_id,used_quantity,remaining_quantity,expected_return_quantity,actual_return_quantity,status,notes,verified_by,verified_at,created_by,updated_by) values(v_item.organization_id,v_item.id,p_used_quantity,p_remaining_quantity,v_expected,p_actual_returned_quantity,p_status,nullif(trim(p_notes),''),case when p_status<>'pending' then v_user end,case when p_status<>'pending' then now() end,v_user,v_user) returning * into v_check;
 end if;
 return v_check;
end $$;
revoke all on function public.save_checkout_item_check(uuid,text,numeric,numeric,numeric,text,integer) from public;grant execute on function public.save_checkout_item_check(uuid,text,numeric,numeric,numeric,text,integer) to authenticated;

create or replace function public.complete_checkout(p_reservation_id uuid,p_actual_checkout_at timestamptz,p_progress jsonb,p_expected_reservation_version integer) returns public.reservations language plpgsql security definer set search_path=public,pg_temp as $$
declare v_res public.reservations%rowtype;v_allocation public.room_allocations%rowtype;v_user uuid:=auth.uid();v_required text;v_cleaning uuid;
begin
 select * into v_res from public.reservations where id=p_reservation_id for update;
 if not found or not public.current_user_has_org(v_res.organization_id,array['owner','manager']) then raise exception 'permission denied';end if;
 if v_res.version<>p_expected_reservation_version then raise exception 'reservation changed; reload' using errcode='40001';end if;
 if v_res.status not in('checked_in','waiting_checkout') then raise exception 'reservation is not ready for checkout';end if;
 foreach v_required in array array['actual_checkout_confirmed','outstanding_tasks_reviewed','medication_events_handover','balance_reviewed','luggage_verified','customer_handover_confirmed'] loop if coalesce((p_progress->>v_required)::boolean,false) is not true then raise exception 'checkout item % is not confirmed',v_required;end if;end loop;
 if v_res.balance_amount>0 and v_res.payment_status<>'paid' and length(trim(coalesce(p_progress->>'balance_exception_reason','')))<3 then raise exception 'outstanding balance requires a documented exception';end if;
 if exists(select 1 from public.stay_items si left join public.checkout_item_checks cc on cc.organization_id=si.organization_id and cc.stay_item_id=si.id where si.organization_id=v_res.organization_id and si.reservation_id=v_res.id and si.return_required and si.archived_at is null and (cc.id is null or cc.status='pending')) then raise exception 'all return-required items must be verified';end if;
 select * into v_allocation from public.room_allocations where organization_id=v_res.organization_id and reservation_id=v_res.id and allocation_status='active' for update;if not found then raise exception 'active room allocation required';end if;
 if p_actual_checkout_at<coalesce(v_res.actual_check_in_at,v_res.expected_check_in_at) or p_actual_checkout_at>now()+interval '1 day' then raise exception 'actual checkout time is invalid';end if;
 insert into public.stay_workflows(organization_id,reservation_id,workflow_type,status,progress,completed_at,completed_by,created_by,updated_by) values(v_res.organization_id,v_res.id,'checkout','completed',p_progress,now(),v_user,v_user,v_user) on conflict(organization_id,reservation_id,workflow_type) do update set status='completed',progress=excluded.progress,completed_at=now(),completed_by=v_user,updated_by=v_user where public.stay_workflows.status='draft';
 update public.reservations set status='checked_out',actual_check_out_at=p_actual_checkout_at,updated_by=v_user where id=v_res.id returning * into v_res;
 update public.room_allocations set allocation_status='completed',updated_by=v_user where id=v_allocation.id;
 update public.rooms set status='cleaning_required',updated_by=v_user where id=v_allocation.room_id and organization_id=v_res.organization_id;
 select id into v_cleaning from public.cleaning_records where organization_id=v_res.organization_id and reservation_id=v_res.id and room_id=v_allocation.room_id and status<>'completed' limit 1;
 if v_cleaning is null then insert into public.cleaning_records(organization_id,room_id,reservation_id,scheduled_at,status,created_by,updated_by) values(v_res.organization_id,v_allocation.room_id,v_res.id,now(),'pending',v_user,v_user) returning id into v_cleaning;end if;
 insert into public.tasks(organization_id,reservation_id,room_id,task_type,title,due_at,priority,status,source_type,source_id,idempotency_key,created_by,updated_by) values(v_res.organization_id,v_res.id,v_allocation.room_id,'cleaning','退房後房間清潔',now(),2,'pending','cleaning_record',v_cleaning,'cleaning:'||v_cleaning,v_user,v_user) on conflict(organization_id,idempotency_key) do nothing;
 return v_res;
end $$;
revoke all on function public.complete_checkout(uuid,timestamptz,jsonb,integer) from public;grant execute on function public.complete_checkout(uuid,timestamptz,jsonb,integer) to authenticated;
commit;
