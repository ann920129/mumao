import test from 'node:test';
import assert from 'node:assert/strict';
import {formatDailyReport} from '../app/domain/report.js';

test('日報不把缺少紀錄推定為正常',()=>{const text=formatDailyReport({cat_name:'木木',report_date:'2026-11-26'});assert.match(text,/尚無紀錄不代表正常/);assert.equal((text.match(/尚無已記錄項目/g)||[]).length,7);assert.doesNotMatch(text,/一切正常|狀況正常/)});
test('日報只輸出白名單照護欄位並保留不確定狀態',()=>{const text=formatDailyReport({cat_name:'木木',report_date:'2026-11-26',public_message:'今天比較怕生。',water:[{time:'10:00',observation:'unknown'}],medications:[{time:'09:00',name:'處方藥',status:'requires_confirmation'}],internal_notes:'不可外流'});assert.match(text,/不確定/);assert.match(text,/需人工確認/);assert.match(text,/今天比較怕生/);assert.doesNotMatch(text,/不可外流/)});
