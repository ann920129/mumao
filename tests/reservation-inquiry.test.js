import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const sql=await readFile(new URL('../supabase/migrations/202611280012_reservation_inquiries.sql',import.meta.url),'utf8');

test('預約詢問不配置實體房且由伺服器重算價格',()=>{
  const create=sql.match(/create or replace function public\.create_reservation_inquiry[\s\S]*?grant execute/i)?.[0]||'';
  assert.match(create,/status,expected_check_in_at[\s\S]*?'draft'/);
  assert.doesNotMatch(create,/insert into public\.room_allocations/i);
  assert.match(create,/select nightly_amount into v_nightly from public\.pricing_rules/i);
  assert.match(create,/floor\(\(v_total\*3\+5\)\/10\.0\)/i);
  assert.match(create,/room capacity exceeded/i);
});

test('詢問更新採 row lock、版本檢查並保留報價版本',()=>{
  const update=sql.match(/create or replace function public\.update_reservation_inquiry[\s\S]*?grant execute/i)?.[0]||'';
  assert.match(update,/for update/);
  assert.match(update,/v\.version<>p_expected_version/);
  assert.match(update,/status not in\('draft','pending'\)/);
  assert.match(update,/max\(version\),0\)\+1/);
  assert.match(update,/confirmed financial records cannot be overwritten/);
  assert.match(update,/current_user_has_org\(v\.organization_id,array\['owner'\]\)/);
});

test('歷史報價改為每筆預約多版本唯一',()=>{
  assert.match(sql,/drop constraint if exists price_snapshots_organization_id_reservation_id_key/);
  assert.match(sql,/unique\(organization_id,reservation_id,version\)/);
});
