export const ROOM_TYPES=Object.freeze([
  {key:'jazz',name:'爵士房',base:760,maxCats:2},
  {key:'upgrade',name:'爵士升等房',base:1100,maxCats:3},
  {key:'first',name:'頭等房',base:1400,maxCats:4},
  {key:'little_president',name:'小總統房',base:2500,maxCats:6},
  {key:'president',name:'大總統房',base:3200,maxCats:7},
  {key:'standard',name:'東海標準房',base:800,maxCats:2}
]);
export const REGULAR_PRICES=Object.freeze({jazz:{single:760,multi:950},upgrade:{single:880,multi:1100},first:{single:1120,multi:1400},little_president:{single:2000,multi:2500},president:{single:2560,multi:3200},standard:{single:800,multi:1000}});
export const LONG_STAY_SINGLE=Object.freeze({jazz:{N06:680,N13:650,N30:550,N90:500},upgrade:{N06:790,N13:750,N30:650,N90:570},first:{N06:1010,N13:960,N30:820,N90:730},little_president:{N06:1800,N13:1700,N30:1600,N90:1400},president:{N06:2300,N13:2150,N30:1850,N90:1650},standard:{N06:720,N13:680,N30:570,N90:520}});
export const LONG_STAY_MULTI=Object.freeze({jazz:{N06:860,N13:810,N30:680,N90:620},upgrade:{N06:990,N13:940,N30:800,N90:720},first:{N06:1260,N13:1200,N30:1010,N90:910},little_president:{N06:2250,N13:2100,N30:1800,N90:1600},president:{N06:2880,N13:2700,N30:2300,N90:2100},standard:{N06:900,N13:850,N30:710,N90:650}});

export function parseDateOnly(value){if(!/^\d{4}-\d{2}-\d{2}$/.test(value||''))throw new TypeError('日期格式必須為 YYYY-MM-DD');const [y,m,d]=value.split('-').map(Number);const date=new Date(Date.UTC(y,m-1,d));if(date.getUTCFullYear()!==y||date.getUTCMonth()!==m-1||date.getUTCDate()!==d)throw new RangeError('無效日期');return date}
export function calculateNights(checkIn,checkOut){const nights=(parseDateOnly(checkOut)-parseDateOnly(checkIn))/86400000;if(!Number.isInteger(nights)||nights<1)throw new RangeError('退房日必須晚於入住日');return nights}
export function tierFor(nights){if(nights>=90)return {code:'N90',label:'90 晚起'};if(nights>=30)return {code:'N30',label:'30 晚起'};if(nights>=13)return {code:'N13',label:'13 晚起'};if(nights>=6)return {code:'N06',label:'6 晚起'};return null}
export function calculateDeposit(total){if(!Number.isFinite(total)||total<=0)return 0;return Math.floor((total*3+5)/10)}
export function calculatePrice({roomKey,catCount,checkIn,checkOut}){const room=ROOM_TYPES.find(item=>item.key===roomKey);if(!room)throw new RangeError('未知房型');if(!Number.isInteger(catCount)||catCount<1||catCount>room.maxCats)throw new RangeError(`此房型限 1 至 ${room.maxCats} 隻`);const nights=calculateNights(checkIn,checkOut);const tier=tierFor(nights);const table=catCount>=2?LONG_STAY_MULTI:LONG_STAY_SINGLE;const nightly=tier?table[roomKey][tier.code]:REGULAR_PRICES[roomKey][catCount>=2?'multi':'single'];const total=nightly*nights;const deposit=calculateDeposit(total);return Object.freeze({version:'legacy-2026-06-30',currency:'TWD',roomKey,roomName:room.name,catCount,nights,tier:tier?.code??null,tierLabel:tier?.label??'一般方案',nightly,total,deposit,balance:total-deposit})}
