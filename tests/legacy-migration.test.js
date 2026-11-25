import test from 'node:test';import assert from 'node:assert/strict';import {discoverLegacy,validateLegacyBundle,exportLegacyBackup,fingerprintImport} from '../app/services/legacy-migration.js';
class MemoryStorage{constructor(values={}){this.values=values}getItem(k){return this.values[k]??null}}
test('只讀探索已知舊版 key 並保留原始字串',()=>{const storage=new MemoryStorage({reservations:'[{"id":1}]',unrelated:'secret'});const found=discoverLegacy(storage);assert.equal(found.length,1);assert.equal(found[0].key,'reservations');assert.equal(found[0].raw,'[{"id":1}]')});
test('錯誤 JSON 會列入報告而非猜測資料',()=>{const found=discoverLegacy(new MemoryStorage({bookings:'{broken'}));const result=validateLegacyBundle(found);assert.equal(result.valid,false);assert.equal(result.issues.length,1)});
test('備份不刪除來源且含格式版本',()=>{const storage=new MemoryStorage({careRecords:'[]'});const backup=JSON.parse(exportLegacyBackup(storage));assert.equal(backup.format,'mumao-legacy-backup-v1');assert.equal(storage.getItem('careRecords'),'[]')});
test('相同輸入產生穩定匯入指紋以防重複',()=>assert.equal(fingerprintImport({a:1}),fingerprintImport({a:1})));
