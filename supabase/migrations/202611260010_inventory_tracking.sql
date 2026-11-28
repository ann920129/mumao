begin;

create index if not exists item_inventory_movements_history_idx on public.item_inventory_movements(organization_id,stay_item_id,occurred_at desc);
create index if not exists item_alerts_open_idx on public.item_alerts(organization_id,stay_item_id,alert_type,status);

create or replace function public.refresh_item_low_stock_alert(p_item_id uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.stay_items%rowtype;begin select * into v from public.stay_items where id=p_item_id;if not found then return;end if;if v.low_stock_threshold is not null and v.remaining_quantity is not null and v.remaining_quantity<=v.low_stock_threshold then if not exists(select 1 from public.item_alerts where organization_id=v.organization_id and stay_item_id=v.id and alert_type='low_stock' and status in('open','acknowledged')) then insert into public.item_alerts(organization_id,stay_item_id,alert_type,status,message) values(v.organization_id,v.id,'low_stock','open',v.name||' 剩餘量已達低庫存門檻');end if;else update public.item_alerts set status='closed',closed_at=now(),closed_by=auth.uid() where organization_id=v.organization_id and stay_item_id=v.id and alert_type='low_stock' and status in('open','acknowledged');end if;end $$;
revoke all on function public.refresh_item_low_stock_alert(uuid) from public;

create or replace function public.sync_item_low_stock_alert() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$begin perform public.refresh_item_low_stock_alert(new.id);return new;end $$;
drop trigger if exists stay_items_low_stock_alert on public.stay_items;
create trigger stay_items_low_stock_alert after insert or update of remaining_quantity,low_stock_threshold on public.stay_items for each row execute function public.sync_item_low_stock_alert();

create or replace function public.record_inventory_movement(p_stay_item_id uuid,p_movement_type text,p_quantity numeric,p_unit text,p_reason text,p_idempotency_key uuid) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_item public.stay_items%rowtype;v_id uuid;v_delta numeric;v_record_quantity numeric;
begin
 select * into v_item from public.stay_items where id=p_stay_item_id for update;
 if not found or not public.current_user_has_org(v_item.organization_id,array['owner','manager','staff']) then raise exception 'item not found';end if;
 select id into v_id from public.item_inventory_movements where organization_id=v_item.organization_id and stay_item_id=p_stay_item_id and idempotency_key=p_idempotency_key;if v_id is not null then return v_id;end if;
 if p_movement_type not in('received','offered','consumed','waste','replenishment','correction','returned') then raise exception 'invalid inventory movement';end if;
 if p_movement_type='correction' then if p_quantity=0 then raise exception 'correction must be non-zero';end if;elsif p_quantity<=0 then raise exception 'quantity must be positive';end if;
 if v_item.remaining_quantity is null then raise exception 'remaining quantity is unknown; initialize it before movement';end if;
 if nullif(trim(v_item.unit),'') is not null and nullif(trim(p_unit),'') is not null and lower(trim(v_item.unit))<>lower(trim(p_unit)) then raise exception 'movement unit must match item unit';end if;
 if p_movement_type in('correction','waste','returned') and length(trim(coalesce(p_reason,'')))<2 then raise exception 'movement reason is required';end if;
 v_delta=case when p_movement_type in('offered','waste','returned') then -p_quantity when p_movement_type in('received','replenishment','correction') then p_quantity when p_movement_type='consumed' then 0 else 0 end;
 v_record_quantity=case when p_movement_type in('offered','waste','returned') then -p_quantity else p_quantity end;
 if v_item.remaining_quantity+v_delta<0 then raise exception 'insufficient remaining quantity';end if;
 insert into public.item_inventory_movements(organization_id,stay_item_id,movement_type,quantity,unit,reason,idempotency_key,created_by) values(v_item.organization_id,p_stay_item_id,p_movement_type,v_record_quantity,coalesce(nullif(trim(p_unit),''),v_item.unit),nullif(trim(p_reason),''),p_idempotency_key,auth.uid()) returning id into v_id;
 update public.stay_items set remaining_quantity=remaining_quantity+v_delta,updated_by=auth.uid() where id=p_stay_item_id;
 perform public.refresh_item_low_stock_alert(p_stay_item_id);
 return v_id;
end $$;
revoke all on function public.record_inventory_movement(uuid,text,numeric,text,text,uuid) from public;grant execute on function public.record_inventory_movement(uuid,text,numeric,text,text,uuid) to authenticated;

create or replace function public.initialize_inventory_quantity(p_stay_item_id uuid,p_quantity numeric,p_unit text,p_reason text,p_expected_version integer) returns public.stay_items language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.stay_items%rowtype;begin select * into v from public.stay_items where id=p_stay_item_id for update;if not found or not public.current_user_has_org(v.organization_id,array['owner','manager','staff']) then raise exception 'item not found';end if;if v.version<>p_expected_version then raise exception 'item changed; reload' using errcode='40001';end if;if v.remaining_quantity is not null then raise exception 'quantity is already known; use an inventory movement';end if;if p_quantity<0 or length(trim(coalesce(p_reason,'')))<2 then raise exception 'non-negative quantity and reason are required';end if;update public.stay_items set received_quantity=coalesce(received_quantity,p_quantity),remaining_quantity=p_quantity,unit=coalesce(nullif(trim(p_unit),''),unit),updated_by=auth.uid() where id=v.id returning * into v;if p_quantity<>0 then insert into public.item_inventory_movements(organization_id,stay_item_id,movement_type,quantity,unit,reason,idempotency_key,created_by) values(v.organization_id,v.id,'correction',p_quantity,v.unit,'[初始化] '||trim(p_reason),gen_random_uuid(),auth.uid());end if;perform public.refresh_item_low_stock_alert(v.id);return v;end $$;
revoke all on function public.initialize_inventory_quantity(uuid,numeric,text,text,integer) from public;grant execute on function public.initialize_inventory_quantity(uuid,numeric,text,text,integer) to authenticated;

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
 'pending_handovers',(select count(*) from public.handover_records where organization_id=p_organization_id and important and acknowledged_at is null),
 'today_shifts',(select count(*) from public.shifts where organization_id=p_organization_id and (starts_at at time zone 'Asia/Taipei')::date<=p_today and (ends_at at time zone 'Asia/Taipei')::date>=p_today and status<>'cancelled'),
 'low_inventory',(select count(*) from public.item_alerts where organization_id=p_organization_id and alert_type='low_stock' and status in('open','acknowledged'))
);end $$;
revoke all on function public.dashboard_summary(uuid,date,date) from public;grant execute on function public.dashboard_summary(uuid,date,date) to authenticated;

commit;
