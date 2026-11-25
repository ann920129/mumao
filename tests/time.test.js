import test from 'node:test';import assert from 'node:assert/strict';import {taipeiDate,tomorrowTaipei,addLocalDays,dateRange} from '../app/domain/time.js';
test('UTC 日期邊界轉成臺北日期',()=>{assert.equal(taipeiDate(new Date('2026-11-25T16:30:00Z')),'2026-11-26');assert.equal(taipeiDate(new Date('2026-11-25T15:59:59Z')),'2026-11-25')});
test('明日提醒以 Asia/Taipei 日期為準',()=>assert.equal(tomorrowTaipei(new Date('2026-12-31T15:30:00Z')),'2027-01-01'));
test('日期區間不含退房日',()=>assert.deepEqual(dateRange('2026-12-30','2027-01-02'),['2026-12-30','2026-12-31','2027-01-01']));
test('本地日期加天數處理閏年',()=>assert.equal(addLocalDays('2028-02-28',1),'2028-02-29'));
