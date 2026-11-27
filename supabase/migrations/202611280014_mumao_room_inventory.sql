begin;

create or replace function public.provision_mumao_rooms(p_organization_id uuid) returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid();v_item record;v_type uuid;v_count integer;v_names text[]:=array['爵1','爵2','爵3','爵4','爵5','爵6','爵7','升1','升2','升3','升4','升5','升6','升7','頭1','頭2','頭3','頭4','頭5','小總','大總'];
begin
 if not public.current_user_has_org(p_organization_id,array['owner']) then raise exception 'only owner may provision rooms' using errcode='42501';end if;
 if exists(select 1 from public.rooms where organization_id=p_organization_id and status<>'out_of_service' and not(name=any(v_names))) then raise exception 'non-canonical active rooms must be reviewed before provisioning';end if;
 if (select count(*) from public.room_types where organization_id=p_organization_id and code in('jazz','upgrade','first','little_president','president') and active)<>5 then raise exception 'five required room types must exist';end if;
 for v_item in select * from (values
  ('jazz','爵1',1),('jazz','爵2',2),('jazz','爵3',3),('jazz','爵4',4),('jazz','爵5',5),('jazz','爵6',6),('jazz','爵7',7),
  ('upgrade','升1',8),('upgrade','升2',9),('upgrade','升3',10),('upgrade','升4',11),('upgrade','升5',12),('upgrade','升6',13),('upgrade','升7',14),
  ('first','頭1',15),('first','頭2',16),('first','頭3',17),('first','頭4',18),('first','頭5',19),('little_president','小總',20),('president','大總',21)
 ) x(code,name,sort_order) loop
  select id into v_type from public.room_types where organization_id=p_organization_id and code=v_item.code and active;
  insert into public.rooms(organization_id,room_type_id,name,status,sort_order,created_by,updated_by) values(p_organization_id,v_type,v_item.name,'available',v_item.sort_order,v_user,v_user)
  on conflict(organization_id,name) do update set room_type_id=excluded.room_type_id,sort_order=excluded.sort_order,updated_by=v_user where public.rooms.status='out_of_service';
 end loop;
 select count(*) into v_count from public.rooms where organization_id=p_organization_id and status<>'out_of_service' and name=any(v_names);
 if v_count<>21 then raise exception 'canonical active room count must be 21';end if;return v_count;
end $$;
revoke all on function public.provision_mumao_rooms(uuid) from public;grant execute on function public.provision_mumao_rooms(uuid) to authenticated;

create or replace function public.auto_provision_mumao_rooms() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin if new.code='standard' and not exists(select 1 from public.rooms where organization_id=new.organization_id) then perform public.provision_mumao_rooms(new.organization_id);end if;return new;end $$;
create trigger room_types_auto_provision after insert on public.room_types for each row execute function public.auto_provision_mumao_rooms();
revoke all on function public.auto_provision_mumao_rooms() from public,anon,authenticated;

create or replace function public.enforce_reservation_capacity() returns trigger language plpgsql set search_path=public,pg_temp as $$
declare v_reservation uuid:=coalesce(new.reservation_id,old.reservation_id);v_org uuid:=coalesce(new.organization_id,old.organization_id);v_max integer;v_count integer;
begin select rt.max_cats into v_max from public.reservations r join public.room_types rt on rt.organization_id=r.organization_id and rt.id=r.room_type_id where r.organization_id=v_org and r.id=v_reservation;if v_max is null then return coalesce(new,old);end if;select count(*) into v_count from public.reservation_cats where organization_id=v_org and reservation_id=v_reservation;if v_count>v_max then raise exception 'room type capacity exceeded';end if;return coalesce(new,old);end $$;
create constraint trigger reservation_cats_capacity after insert or update of reservation_id,cat_id on public.reservation_cats deferrable initially immediate for each row execute function public.enforce_reservation_capacity();

create or replace function public.enforce_reservation_room_type_capacity() returns trigger language plpgsql set search_path=public,pg_temp as $$
declare v_max integer;v_count integer;begin if new.room_type_id is null then return new;end if;select max_cats into v_max from public.room_types where organization_id=new.organization_id and id=new.room_type_id;select count(*) into v_count from public.reservation_cats where organization_id=new.organization_id and reservation_id=new.id;if v_count>v_max then raise exception 'room type capacity exceeded';end if;return new;end $$;
create trigger reservations_room_type_capacity before update of room_type_id on public.reservations for each row execute function public.enforce_reservation_room_type_capacity();

create or replace function public.enforce_allocation_room_type() returns trigger language plpgsql set search_path=public,pg_temp as $$
declare v_reserved_type uuid;v_room_type uuid;v_count integer;v_max integer;begin select room_type_id into v_reserved_type from public.reservations where organization_id=new.organization_id and id=new.reservation_id;select room_type_id into v_room_type from public.rooms where organization_id=new.organization_id and id=new.room_id;if v_reserved_type is null or v_room_type is null or v_reserved_type<>v_room_type then raise exception 'allocated room type does not match reservation';end if;select max_cats into v_max from public.room_types where organization_id=new.organization_id and id=v_room_type;select count(*) into v_count from public.reservation_cats where organization_id=new.organization_id and reservation_id=new.reservation_id;if v_count>v_max then raise exception 'physical room capacity exceeded';end if;return new;end $$;
create trigger room_allocations_type_capacity before insert or update of room_id,reservation_id on public.room_allocations for each row execute function public.enforce_allocation_room_type();

commit;
