import {calculatePrice} from './pricing.js';

export const LEGACY_CALCULATOR_PATH='./app/legacy/original-booking-calculator.html';

export function readLegacyQuotation(doc){
  const checked=doc.querySelector('input[name="room"]:checked');
  const roomKey=checked?.id?.replace(/^room_/, '');
  const checkIn=doc.querySelector('#checkIn')?.value;
  const checkOut=doc.querySelector('#checkOut')?.value;
  const catCount=Number.parseInt(doc.querySelector('#catsText')?.textContent||'',10);
  if(!roomKey)throw new Error('請先選擇房型');
  return Object.freeze({...calculatePrice({roomKey,catCount,checkIn,checkOut}),checkIn,checkOut});
}

export function formatLegacyQuotation(price){
  return [
    '暮貓旅宿住宿報價',
    `房型：${price.roomName}`,
    `入住貓咪：${price.catCount} 隻`,
    `住宿：${price.nights} 夜（${price.tierLabel}）`,
    `每晚：NT$ ${price.nightly}`,
    `總價：NT$ ${price.total}`,
    `訂金 30%：NT$ ${price.deposit}`,
    `尾款：NT$ ${price.balance}`
  ].join('\n');
}
