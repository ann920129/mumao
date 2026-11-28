import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const root=new URL('../',import.meta.url);
const migration=new URL('supabase/migrations/202611280015_room_care_summary.sql',root);

test('房間照護摘要逐貓彙總且缺少紀錄保持 pending',async()=>{const sql=await readFile(migration,'utf8');assert.match(sql,/room_care_summary/);assert.match(sql,/'breakfast'.*'pending'/s);assert.match(sql,/'lunch'.*'pending'/s);assert.match(sql,/'dinner'.*'pending'/s);assert.match(sql,/medication.*not_applicable.*pending/s);assert.match(sql,/reservation_cat_id/)});

test('共用貓砂盆觀察不會被寫入任何單一貓咪',async()=>{const sql=await readFile(migration,'utf8'),table=sql.match(/create table public\.shared_elimination_observations\(([\s\S]*?)\n\);/)[1];assert.match(table,/attribution text not null default 'unidentifiable_shared'/);assert.doesNotMatch(table,/reservation_cat_id/);assert.match(sql,/status in\('checked_in','waiting_checkout'\).*for share/s);assert.match(sql,/current_user_has_org/)});

test('共用排泄只允許 RPC 寫入並受 RLS 讀取隔離',async()=>{const sql=await readFile(migration,'utf8');assert.match(sql,/enable row level security/);assert.match(sql,/shared_elimination_staff_read/);assert.match(sql,/revoke all on function public\.record_shared_elimination_observation/);assert.doesNotMatch(sql,/shared_elimination_staff_insert/)});
