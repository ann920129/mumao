begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select plan(23);

insert into auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) values
 ('12000000-0000-0000-0000-000000000001','ops-owner@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('12000000-0000-0000-0000-000000000002','ops-staff-1@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('12000000-0000-0000-0000-000000000003','ops-staff-2@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
insert into public.organizations(id,name,slug) values('22000000-0000-0000-0000-000000000001','營運測試旅館','operations-test-hotel');
insert into public.organization_members(organization_id,user_id,role,status,joined_at) values
 ('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','owner','active',now()),
 ('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000002','staff','active',now()),
 ('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000003','staff','active',now());
insert into public.owners(id,organization_id,name,phone,created_by,updated_by)
values('32000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','明日入住飼主','0900000021','12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001');
insert into public.cats(id,organization_id,owner_id,name,created_by,updated_by)
values('42000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','安全測試貓','12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001');
insert into public.reservations(id,organization_id,owner_id,reservation_number,status,expected_check_in_at,expected_check_out_at,idempotency_key,created_by,updated_by)
values('52000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','OPS-001','confirmed','2026-11-27 10:00+08','2026-11-29 10:00+08','62000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001');
insert into public.reservation_cats(id,organization_id,reservation_id,cat_id,created_by)
values('72000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001','42000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.create_medication_order('72000000-0000-0000-0000-000000000001','測試藥品','依處方 1 份','','口服',array['11:00'::time],'2026-11-27','2026-11-27',1,null,'測試處方',null)$$,'人員可逐字建立待確認藥單');
select is((select confirmation_status from public.medication_orders where name='測試藥品'),'requires_confirmation','新藥單不會自動確認');
select throws_ok(format('select public.confirm_medication_order(%L,1)',(select id from public.medication_orders where name='測試藥品')),'P0001','permission denied','staff 不可確認藥單');

select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok(format('select public.confirm_medication_order(%L,1)',(select id from public.medication_orders where name='測試藥品')),'業主確認後才建立用藥排程');
select is((select count(*)::integer from public.medication_records),1,'只建立住宿時段內的排程');

select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select lives_ok(format('select public.claim_medication_task(%L,1)',(select id from public.medication_records limit 1)),'第一位人員可原子 claim');
select is((select claimed_by from public.medication_records limit 1),'12000000-0000-0000-0000-000000000002'::uuid,'claim 綁定實際執行人員');

select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok(format('select public.claim_medication_task(%L,1)',(select id from public.medication_records limit 1)),'40001','record changed; reload before administering','第二位人員使用舊版本不能重複 claim');
select throws_ok(format('select public.finish_medication_task(%L,2,%L,%L)',(select id from public.medication_records limit 1),'administered','非 claim 人員'),'40001','claim lost or record changed','非 claim 人員不能記錄結果');

select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select lives_ok(format('select public.finish_medication_task(%L,2,%L,%L)',(select id from public.medication_records limit 1),'requires_confirmation','無法確認是否完整服下'),'不確定結果可安全送主管確認');
select is((select status from public.medication_records limit 1),'requires_confirmation','不確定結果不會被標為已給藥');
select is((select count(*)::integer from public.tasks where task_type='medication_follow_up' and status='requires_confirmation'),1,'不確定結果只建立一筆高優先追蹤');
select throws_ok(format('select public.claim_medication_task(%L,3)',(select id from public.medication_records limit 1)),'P0001','medication task is not claimable; uncertain results require manager verification','不確定結果不能由 staff 直接重試');

select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok(format('select public.resolve_medication_record(%L,3,%L,%L)',(select id from public.medication_records limit 1),'retry','已人工核對，重新排程'),'業主可留下理由後解鎖重試');
select is((select status from public.medication_records limit 1),'pending','主管核對後才回到待執行');

select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is(public.reconcile_next_day_notifications('22000000-0000-0000-0000-000000000001','2026-11-26'),1,'依 Asia/Taipei 建立明日入住提醒');
select is((select status from public.notification_tasks where notification_type='next_day_checkin'),'pending','新提醒先保持 pending');
select lives_ok(format('select public.transition_notification(%L,%L,null,null,null,1)',(select id from public.notification_tasks where notification_type='next_day_checkin'),'message_copied'),'複製訊息是獨立狀態');
select ok((select actual_notified_at is null from public.notification_tasks where notification_type='next_day_checkin'),'複製訊息不等於已通知');
select lives_ok(format('select public.transition_notification(%L,%L,%L,null,null,2)',(select id from public.notification_tasks where notification_type='next_day_checkin'),'sent','LINE'),'實際送出需記錄管道');
select ok((select actual_notified_at is not null from public.notification_tasks where notification_type='next_day_checkin'),'只有 sent 寫入實際通知時間');
select is(public.reconcile_next_day_notifications('22000000-0000-0000-0000-000000000001','2026-11-26'),1,'重跑提醒補償同步具冪等唯一鍵');
select is((select status from public.notification_tasks where notification_type='next_day_checkin'),'sent','來源未變時補償同步不會退回 pending');

select * from finish();
rollback;
