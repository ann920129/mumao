import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const sql=await readFile(new URL('../supabase/migrations/202611280014_mumao_room_inventory.sql',import.meta.url),'utf8');
const canonical=['爵1','爵2','爵3','爵4','爵5','爵6','爵7','升1','升2','升3','升4','升5','升6','升7','頭1','頭2','頭3','頭4','頭5','小總','大總'];

test('暮貓房間清單固定為 21 間且名稱唯一',()=>{
  for(const name of canonical)assert.match(sql,new RegExp(`'${name}'`));
  assert.equal(new Set(canonical).size,21);
  assert.match(sql,/v_count<>21/);
  assert.match(sql,/non-canonical active rooms must be reviewed/);
});

test('房型數量及容量沿用核定規則',()=>{
  const rows=[...sql.matchAll(/\('(jazz|upgrade|first|little_president|president)','([^']+)',\d+\)/g)].map(x=>x[1]);
  assert.deepEqual(rows.reduce((out,code)=>(out[code]=(out[code]||0)+1,out),{}),{jazz:7,upgrade:7,first:5,little_president:1,president:1});
  assert.match(sql,/five required room types must exist/);
});

test('資料庫同時驗證預約容量、實體房型與房間衝突',async()=>{
  assert.match(sql,/constraint trigger reservation_cats_capacity/);
  assert.match(sql,/trigger reservations_room_type_capacity/);
  assert.match(sql,/trigger room_allocations_type_capacity/);
  assert.match(sql,/allocated room type does not match reservation/);
  const foundation=await readFile(new URL('../supabase/migrations/202611260001_foundation.sql',import.meta.url),'utf8');
  assert.match(foundation,/exclude using gist\(organization_id with =,room_id with =,tstzrange\(check_in_at,check_out_at,'\[\)'\) with &&\)/);
});
