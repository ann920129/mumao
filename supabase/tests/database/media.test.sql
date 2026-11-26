begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select plan(9);

insert into auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
values('11000000-0000-0000-0000-000000000001','media-owner@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
insert into public.organizations(id,name,slug) values
 ('21000000-0000-0000-0000-000000000001','照片測試旅館','media-test-hotel'),
 ('21000000-0000-0000-0000-000000000002','其他旅館','media-other-hotel');
insert into public.organization_members(organization_id,user_id,role,status,joined_at)
values('21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','owner','active',now());
insert into public.owners(id,organization_id,name,phone,created_by,updated_by)
values('31000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','照片測試飼主','0900000011','11000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001');
insert into public.reservations(id,organization_id,owner_id,reservation_number,status,expected_check_in_at,expected_check_out_at,idempotency_key,created_by,updated_by)
values('51000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','31000000-0000-0000-0000-000000000001','MEDIA-001','confirmed',now(),now()+interval '2 days','61000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001');
insert into public.stay_item_categories(id,organization_id,code,name)
values('71000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','medication','藥品');
insert into public.stay_items(id,organization_id,reservation_id,category_id,name,created_by,updated_by)
values('81000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','測試藥袋','11000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.begin_media_upload('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','medication_packaging','藥袋.jpg','image/jpeg',120000,12000,1600,1200,null,'81000000-0000-0000-0000-000000000001',null)$$,'業主可為同租戶住宿物品建立上傳紀錄');
select like((select storage_path from public.media_files where original_name='藥袋.jpg'),'21000000-0000-0000-0000-000000000001/51000000-0000-0000-0000-000000000001/medication_packaging/%/main.webp','Storage 路徑由伺服器限制在租戶與預約下');
select is((select status from public.media_files where original_name='藥袋.jpg'),'uploading','完成物件核對前不會啟用照片');
select ok((select (metadata->>'privacy_processed')::boolean from public.media_files where original_name='藥袋.jpg'),'紀錄標示已完成隱私處理');
select throws_ok($$select public.begin_media_upload('21000000-0000-0000-0000-000000000002',null,'luggage','越權.jpg','image/jpeg',1000,500,100,100)$$,'P0001','permission denied','不可替其他租戶建立照片');
select throws_ok($$insert into public.media_files(organization_id,reservation_id,category,storage_path,original_name,mime_type,file_size,created_by) values('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','luggage','direct/main.webp','直接寫入.jpg','image/webp',1000,'11000000-0000-0000-0000-000000000001')$$,'42501',null,'authenticated 不可繞過 RPC 直接新增 media_files');
select throws_ok(format('select public.finalize_media_upload(%L,1)',(select id from public.media_files where original_name='藥袋.jpg')),'P0001','uploaded image objects are incomplete','缺少主圖或縮圖時不可啟用');

reset role;
insert into storage.objects(bucket_id,name,owner_id,metadata)
select storage_bucket,storage_path,'11000000-0000-0000-0000-000000000001','{"mimetype":"image/webp","size":120000}'::jsonb from public.media_files where original_name='藥袋.jpg'
union all
select storage_bucket,metadata->>'thumbnail_path','11000000-0000-0000-0000-000000000001','{"mimetype":"image/webp","size":12000}'::jsonb from public.media_files where original_name='藥袋.jpg';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok(format('select public.finalize_media_upload(%L,1)',(select id from public.media_files where original_name='藥袋.jpg')),'主圖與縮圖都存在時可完成上傳');
select is((select status from public.media_files where original_name='藥袋.jpg'),'active','完成核對後照片才標為 active');

select * from finish();
rollback;
