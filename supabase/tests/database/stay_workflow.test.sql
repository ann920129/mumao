begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select plan(17);

insert into auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) values
 ('13000000-0000-0000-0000-000000000001','stay-owner@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('13000000-0000-0000-0000-000000000002','stay-staff@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
insert into public.organizations(id,name,slug) values('23000000-0000-0000-0000-000000000001','入住退房測試旅館','stay-workflow-test');
insert into public.organization_members(organization_id,user_id,role,status,joined_at) values
 ('23000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001','owner','active',now()),
 ('23000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000002','staff','active',now());
insert into public.owners(id,organization_id,name,phone,created_by,updated_by)
values('33000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','流程測試飼主','0900000031','13000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001');
insert into public.cats(id,organization_id,owner_id,name,created_by,updated_by)
values('43000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','流程測試貓','13000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001');
insert into public.room_types(id,organization_id,code,name,max_cats,created_by,updated_by)
values('53000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','jazz','爵士房',2,'13000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001');
insert into public.rooms(id,organization_id,room_type_id,name,status,created_by,updated_by)
values('63000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','53000000-0000-0000-0000-000000000001','流程測試房','available','13000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001');
insert into public.reservations(id,organization_id,owner_id,room_type_id,reservation_number,status,expected_check_in_at,expected_check_out_at,idempotency_key,created_by,updated_by)
values('73000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','53000000-0000-0000-0000-000000000001','STAY-001','confirmed',now()-interval '1 hour',now()+interval '1 day','83000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001');
insert into public.reservation_cats(id,organization_id,reservation_id,cat_id,created_by)
values('93000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','43000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001');
insert into public.room_allocations(id,organization_id,reservation_id,room_id,check_in_at,check_out_at,created_by,updated_by)
values('a3000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001',now()-interval '1 hour',now()+interval '1 day','13000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001');
insert into public.stay_item_categories(id,organization_id,code,name)
values('b3000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','luggage','行李');
insert into public.stay_items(id,organization_id,reservation_id,category_id,name,received_quantity,remaining_quantity,unit,return_required,created_by,updated_by)
values('c3000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','外出籠',1,1,'個',true,'13000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.complete_checkin('73000000-0000-0000-0000-000000000001',now()-interval '30 minutes','{}'::jsonb,1)$$,'P0001','check-in item reservation_confirmed is not confirmed','入住缺少人工核對時被拒絕');
select lives_ok($$select public.complete_checkin('73000000-0000-0000-0000-000000000001',now()-interval '30 minutes','{"reservation_confirmed":true,"owner_cat_confirmed":true,"room_confirmed":true,"actual_time_confirmed":true,"luggage_reviewed":true,"food_reviewed":true,"supplements_reviewed":true,"medications_reviewed":true,"feeding_instructions_confirmed":true,"care_instructions_confirmed":true}'::jsonb,1)$$,'完整核對後可完成入住');
select is((select status from public.reservations where id='73000000-0000-0000-0000-000000000001'),'checked_in','預約進入住宿中');
select is((select status from public.rooms where id='63000000-0000-0000-0000-000000000001'),'occupied','房間同步改為使用中');
select ok((select count(*)>0 from public.care_days where reservation_cat_id='93000000-0000-0000-0000-000000000001'),'入住建立住宿期間照護日');
select throws_ok($$select public.complete_checkout('73000000-0000-0000-0000-000000000001',now(),'{"actual_checkout_confirmed":true,"outstanding_tasks_reviewed":true,"medication_events_handover":true,"balance_reviewed":true,"luggage_verified":true,"customer_handover_confirmed":true}'::jsonb,2)$$,'P0001','all return-required items must be verified','需歸還物品未核對時不能退房');

select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.save_checkout_item_check('c3000000-0000-0000-0000-000000000001','returned',0,1,1,'已交還',null)$$,'工作人員可核對實際歸還物品');
select is((select verified_by from public.checkout_item_checks where stay_item_id='c3000000-0000-0000-0000-000000000001'),'13000000-0000-0000-0000-000000000002'::uuid,'物品核對留下實際人員');

select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.complete_checkout('73000000-0000-0000-0000-000000000001',now(),'{"actual_checkout_confirmed":true,"outstanding_tasks_reviewed":true,"medication_events_handover":true,"balance_reviewed":true,"luggage_verified":true,"customer_handover_confirmed":true}'::jsonb,2)$$,'核對完成後可交易式退房');
select is((select status from public.reservations where id='73000000-0000-0000-0000-000000000001'),'checked_out','預約完成退房');
select is((select allocation_status from public.room_allocations where id='a3000000-0000-0000-0000-000000000001'),'completed','房間配置同步結束');
select is((select status from public.rooms where id='63000000-0000-0000-0000-000000000001'),'cleaning_required','退房後房間不可直接再入住');
select is((select count(*)::integer from public.tasks where task_type='cleaning' and reservation_id='73000000-0000-0000-0000-000000000001'),1,'退房只建立一筆清潔工作');
select throws_ok(format('select public.complete_cleaning(%L,1,%L::jsonb,null)',(select id from public.cleaning_records where reservation_id='73000000-0000-0000-0000-000000000001'),'{"litter_box":true}'),'P0001','required cleaning checklist is incomplete','清潔核對不完整時房間維持不可用');
select lives_ok(format('select public.complete_cleaning(%L,1,%L::jsonb,%L)',(select id from public.cleaning_records where reservation_id='73000000-0000-0000-0000-000000000001'),'{"litter_box":true,"bowls":true,"bedding":true,"disinfection":true}','全部完成'),'四項清潔完成後才釋放房間');
select is((select status from public.rooms where id='63000000-0000-0000-0000-000000000001'),'available','清潔完成後房間回到可入住');
select is((select status from public.cleaning_records where reservation_id='73000000-0000-0000-0000-000000000001'),'completed','清潔紀錄保留完成狀態');

select * from finish();
rollback;
