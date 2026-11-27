begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select plan(8);

insert into auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) values
 ('17000000-0000-0000-0000-000000000001','event-owner@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('17000000-0000-0000-0000-000000000002','event-staff@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
insert into public.organizations(id,name,slug) values('27000000-0000-0000-0000-000000000001','異常測試旅館','event-test');
insert into public.organization_members(organization_id,user_id,role,status,joined_at) values
 ('27000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000001','owner','active',now()),
 ('27000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000002','staff','active',now());
insert into public.owners(id,organization_id,name,phone,created_by,updated_by) values('37000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000001','異常測試飼主','0900000071','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000001');
insert into public.cats(id,organization_id,owner_id,name,created_by,updated_by) values('47000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000001','37000000-0000-0000-0000-000000000001','異常測試貓','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000001');
insert into public.reservations(id,organization_id,owner_id,reservation_number,status,expected_check_in_at,expected_check_out_at,idempotency_key,created_by,updated_by) values('57000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000001','37000000-0000-0000-0000-000000000001','EVENT-001','checked_in',now()-interval '1 day',now()+interval '1 day','67000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000001');
insert into public.reservation_cats(id,organization_id,reservation_id,cat_id,created_by) values('77000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000001','57000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000001');
insert into public.abnormal_events(id,organization_id,reservation_cat_id,category,severity,event_at,description,follow_up_required,created_by,updated_by) values('87000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','appetite','follow_up',now(),'食量下降',true,'17000000-0000-0000-0000-000000000002','17000000-0000-0000-0000-000000000002');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"17000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.add_abnormal_event_followup('87000000-0000-0000-0000-000000000001','稍後已少量進食',now()+interval '2 hours',1)$$,'工作人員可新增實際追蹤');
select is((select status from public.abnormal_events where id='87000000-0000-0000-0000-000000000001'),'monitoring','新增追蹤後進入持續觀察');
select is((select count(*)::integer from public.abnormal_event_updates where abnormal_event_id='87000000-0000-0000-0000-000000000001'),1,'追蹤留下不可覆寫歷程');
select throws_ok($$select public.add_abnormal_event_followup('87000000-0000-0000-0000-000000000001','舊裝置覆寫',null,1)$$,'40001','event changed','舊版本不可覆寫追蹤');
select throws_ok($$select public.resolve_abnormal_event('87000000-0000-0000-0000-000000000001','已恢復正常',2)$$,'42501','only owner or manager may resolve an event','一般工作人員不可結案');

select set_config('request.jwt.claims','{"sub":"17000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.resolve_abnormal_event('87000000-0000-0000-0000-000000000001','已恢復正常進食，業主確認結案',2)$$,'業主可結案');
select is((select status from public.abnormal_events where id='87000000-0000-0000-0000-000000000001'),'resolved','結案狀態正確');
select is((select count(*)::integer from public.abnormal_event_updates where abnormal_event_id='87000000-0000-0000-0000-000000000001'),2,'結案保留第二筆歷程');

select * from finish();
rollback;
