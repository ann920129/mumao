import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const root=new URL('../',import.meta.url);

test('清潔完成同交易釋放房間並關閉待辦',async()=>{
  const sql=await readFile(new URL('supabase/migrations/202611280018_complete_cleaning_task.sql',root),'utf8');
  assert.match(sql,/where id=p_cleaning_id for update/);
  assert.match(sql,/update public\.rooms set status='available'/);
  assert.match(sql,/update public\.tasks set status='completed'/);
  assert.match(sql,/source_type='cleaning_record' and source_id=v\.id/);
  assert.match(sql,/from public\.cleaning_records c/);
});
