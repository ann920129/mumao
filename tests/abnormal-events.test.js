import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const root=new URL('../',import.meta.url);

test('異常追蹤與結案採鎖定、版本及角色保護',async()=>{
  const [sql,repository,main]=await Promise.all([
    readFile(new URL('supabase/migrations/202611280017_abnormal_event_followup.sql',root),'utf8'),
    readFile(new URL('app/services/repository.js',root),'utf8'),
    readFile(new URL('app/main.js',root),'utf8')
  ]);
  assert.ok((sql.match(/for update/g)||[]).length>=2);
  assert.ok((sql.match(/v\.version<>p_expected_version/g)||[]).length>=2);
  assert.match(sql,/array\['owner','manager','staff'\]/);
  assert.match(sql,/array\['owner','manager'\]/);
  assert.match(sql,/insert into public\.abnormal_event_updates/);
  assert.match(repository,/addAbnormalEventFollowup/);
  assert.match(repository,/resolveAbnormalEvent/);
  assert.match(main,/事件已被其他人更新/);
});
