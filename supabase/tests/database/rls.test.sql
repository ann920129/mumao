begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select plan(10);

insert into auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
values
 ('10000000-0000-0000-0000-000000000001','owner-a@example.test','x',now(),'{}','{"display_name":"A 業主"}','authenticated','authenticated',now(),now()),
 ('10000000-0000-0000-0000-000000000002','staff-a@example.test','x',now(),'{}','{"display_name":"A 保母"}','authenticated','authenticated',now(),now()),
 ('10000000-0000-0000-0000-000000000003','owner-b@example.test','x',now(),'{}','{"display_name":"B 業主"}','authenticated','authenticated',now(),now()),
 ('10000000-0000-0000-0000-000000000004','customer-a@example.test','x',now(),'{}','{"display_name":"A 客戶"}','authenticated','authenticated',now(),now()),
 ('10000000-0000-0000-0000-000000000005','inactive-a@example.test','x',now(),'{}','{"display_name":"停用人員"}','authenticated','authenticated',now(),now());

insert into public.organizations(id,name,slug) values
 ('20000000-0000-0000-0000-000000000001','測試旅館 A','test-hotel-a'),
 ('20000000-0000-0000-0000-000000000002','測試旅館 B','test-hotel-b');
insert into public.organization_members(organization_id,user_id,role,status,joined_at) values
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','owner','active',now()),
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','staff','active',now()),
 ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003','owner','active',now()),
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004','customer','active',now()),
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000005','staff','inactive',now());
insert into public.owners(id,organization_id,name,phone,created_by,updated_by) values
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','A 的飼主','0900000001','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','B 的飼主','0900000002','10000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((select count(*)::integer from public.organizations),1,'A 業主只能讀到 A 組織');
select is((select count(*)::integer from public.owners),1,'A 業主不能讀到 B 個資');
select is(public.current_org_role('20000000-0000-0000-0000-000000000001'),'owner','角色函式回傳 A 業主');
select throws_ok($$insert into public.owners(organization_id,name,phone,created_by,updated_by) values('20000000-0000-0000-0000-000000000002','越權','0900','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001')$$,'42501',null,'A 業主不可寫入 B 組織');

select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is((select count(*)::integer from public.owners),1,'A 保母可讀 A 營運資料');
select is(public.current_org_role('20000000-0000-0000-0000-000000000001'),'staff','角色函式回傳 A 保母');
select throws_ok($$update public.pricing_rules set nightly_amount=1 where organization_id='20000000-0000-0000-0000-000000000001'$$,'42501',null,'保母不可改價格');

select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select is((select name from public.owners limit 1),'B 的飼主','B 業主只讀到 B 個資');

select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select is((select count(*)::integer from public.owners),0,'customer 不可讀內部飼主表');

select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000005","role":"authenticated"}',true);
select is((select count(*)::integer from public.owners),0,'停用帳號不可讀營運資料');

select * from finish();
rollback;
