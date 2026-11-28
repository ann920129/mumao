begin;

create table public.user_preferences(
 organization_id uuid not null references public.organizations(id) on delete restrict,
 user_id uuid not null references auth.users(id) on delete cascade,
 room_display jsonb not null default '{"show_cat_photos":true,"show_cat_names":true,"show_occupancy":true,"show_checkin":true,"show_checkout":true,"show_meals":true,"show_elimination":false,"show_owner":false,"show_special_care":false}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 version integer not null default 1,
 primary key(organization_id,user_id),
 foreign key(organization_id,user_id) references public.organization_members(organization_id,user_id) on delete cascade,
 check(jsonb_typeof(room_display)='object')
);

create trigger user_preferences_updated before update on public.user_preferences for each row execute function public.set_updated_at();
alter table public.user_preferences enable row level security;
create policy user_preferences_self_read on public.user_preferences for select to authenticated using(user_id=auth.uid() and public.current_user_has_org(organization_id));
create policy user_preferences_self_insert on public.user_preferences for insert to authenticated with check(user_id=auth.uid() and public.current_user_has_org(organization_id,array['owner','manager','staff']));
create policy user_preferences_self_update on public.user_preferences for update to authenticated using(user_id=auth.uid() and public.current_user_has_org(organization_id,array['owner','manager','staff'])) with check(user_id=auth.uid() and public.current_user_has_org(organization_id,array['owner','manager','staff']));

create or replace function public.validate_room_display_preferences() returns trigger language plpgsql set search_path=public,pg_temp as $$
declare v_key text;v_allowed constant text[]:=array['show_cat_photos','show_cat_names','show_occupancy','show_checkin','show_checkout','show_meals','show_elimination','show_owner','show_special_care'];
begin
 if exists(select 1 from jsonb_object_keys(new.room_display) k where not(k=any(v_allowed))) then raise exception 'unknown room display preference';end if;
 foreach v_key in array v_allowed loop if new.room_display?v_key and jsonb_typeof(new.room_display->v_key)<>'boolean' then raise exception 'room display preferences must be boolean';end if;end loop;
 new.room_display='{"show_cat_photos":true,"show_cat_names":true,"show_occupancy":true,"show_checkin":true,"show_checkout":true,"show_meals":true,"show_elimination":false,"show_owner":false,"show_special_care":false}'::jsonb||new.room_display;
 return new;
end $$;
create trigger user_preferences_validate before insert or update of room_display on public.user_preferences for each row execute function public.validate_room_display_preferences();
revoke all on function public.validate_room_display_preferences() from public,anon,authenticated;

alter publication supabase_realtime add table public.user_preferences;

commit;
