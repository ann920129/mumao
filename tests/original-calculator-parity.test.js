import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {calculatePrice} from '../app/domain/pricing.js';
import {formatLegacyQuotation} from '../app/domain/legacy-calculator-adapter.js';

const original={
  jazz:{max:2,regular:[760,950],N06:[680,860],N13:[650,810],N30:[550,680],N90:[500,620]},
  upgrade:{max:3,regular:[880,1100],N06:[790,990],N13:[750,940],N30:[650,800],N90:[570,720]},
  first:{max:4,regular:[1120,1400],N06:[1010,1260],N13:[960,1200],N30:[820,1010],N90:[730,910]},
  little_president:{max:6,regular:[2000,2500],N06:[1800,2250],N13:[1700,2100],N30:[1600,1800],N90:[1400,1600]},
  president:{max:7,regular:[2560,3200],N06:[2300,2880],N13:[2150,2700],N30:[1850,2300],N90:[1650,2100]},
  standard:{max:2,regular:[800,1000],N06:[720,900],N13:[680,850],N30:[570,710],N90:[520,650]}
};
const cases=[[1,'regular'],[5,'regular'],[6,'N06'],[12,'N06'],[13,'N13'],[29,'N13'],[30,'N30'],[89,'N30'],[90,'N90']];
const checkout=nights=>new Date(Date.UTC(2026,0,1+nights)).toISOString().slice(0,10);

test('V2 保留的原始計價器副本雜湊完全相同',async()=>{
  const bytes=await readFile(new URL('../app/legacy/original-booking-calculator.html',import.meta.url));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),'21f23ad100a38e048596971c98a000d3db3b40e3a7a960fea1a4725e49893d94');
});

test('六種房型、單多貓與所有長住門檻逐案符合原始來源',()=>{
  for(const [roomKey,reference] of Object.entries(original)){
    for(const catCount of [1,reference.max]){
      for(const [nights,tier] of cases){
        const actual=calculatePrice({roomKey,catCount,checkIn:'2026-01-01',checkOut:checkout(nights)});
        const nightly=reference[tier][catCount===1?0:1];
        const total=nightly*nights;
        assert.deepEqual(
          {nightly:actual.nightly,total:actual.total,deposit:actual.deposit,balance:actual.balance},
          {nightly,total,deposit:Math.floor((total*3+5)/10),balance:total-Math.floor((total*3+5)/10)},
          `${roomKey}/${catCount} cats/${nights} nights`
        );
      }
    }
  }
});

test('顧客報價文字包含歷史價格快照的必要金額',()=>{
  const price=calculatePrice({roomKey:'jazz',catCount:2,checkIn:'2026-01-01',checkOut:'2026-01-07'});
  const text=formatLegacyQuotation(price);
  assert.match(text,/爵士房/);
  assert.match(text,/6 夜（6 晚起）/);
  assert.match(text,/總價：NT\$ 5160/);
  assert.match(text,/訂金 30%：NT\$ 1548/);
});
