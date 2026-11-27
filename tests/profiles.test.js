import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const root=new URL('../',import.meta.url);

test('飼主與貓咪編輯受角色與版本鎖定保護',async()=>{
  const [repository,main,security]=await Promise.all([
    readFile(new URL('app/services/repository.js',root),'utf8'),
    readFile(new URL('app/main.js',root),'utf8'),
    readFile(new URL('supabase/migrations/202611260003_security_and_rpcs.sql',root),'utf8')
  ]);
  assert.match(repository,/updateOwner\(ownerId,expectedVersion,payload\)/);
  assert.match(repository,/updateCat\(catId,expectedVersion,payload\)/);
  assert.ok((repository.match(/\.eq\('version',expectedVersion\)/g)||[]).length>=2);
  assert.match(main,/\['owner','manager'\]\.includes\(state\.membership\?\.role\)/);
  assert.match(main,/資料已被其他裝置更新/);
  assert.match(security,/owners_manage_update/);
  assert.match(security,/cats_manage_update/);
});
