import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const root=new URL('../',import.meta.url),migration=new URL('supabase/migrations/202611280016_user_display_preferences.sql',root);

test('顯示偏好依旅館及使用者隔離並同步',async()=>{const sql=await readFile(migration,'utf8');assert.match(sql,/primary key\(organization_id,user_id\)/);assert.match(sql,/user_id=auth\.uid\(\)/);assert.match(sql,/current_user_has_org/);assert.match(sql,/alter publication supabase_realtime add table public\.user_preferences/)});

test('顯示偏好只有核准布林鍵且預設值符合規格',async()=>{const sql=await readFile(migration,'utf8');for(const key of ['show_cat_photos','show_cat_names','show_occupancy','show_checkin','show_checkout','show_meals'])assert.match(sql,new RegExp(`"${key}":true`));for(const key of ['show_elimination','show_owner','show_special_care'])assert.match(sql,new RegExp(`"${key}":false`));assert.match(sql,/unknown room display preference/);assert.match(sql,/must be boolean/)});

test('顯示偏好表不含業務或敏感資料欄位',async()=>{const sql=await readFile(migration,'utf8'),table=sql.match(/create table public\.user_preferences\(([\s\S]*?)\n\);/)[1];for(const field of ['owner_id','reservation_id','cat_id','payment_data','medication_data','photo_path'])assert.doesNotMatch(table,new RegExp(`^\\s*${field}\\s`,'m'))});

test('關閉照片時前端不查詢或簽發縮圖',async()=>{const js=await readFile(new URL('app/main.js',root),'utf8');assert.match(js,/if\(state\.cloud&&prefs\.show_cat_photos\).*roomCatPhotos/s);assert.match(js,/恢復預設設定/);assert.match(js,/只影響你的畫面/)});
