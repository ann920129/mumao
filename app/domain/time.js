const DATE_FORMAT=new Intl.DateTimeFormat('zh-TW',{timeZone:'Asia/Taipei',year:'numeric',month:'2-digit',day:'2-digit'});
const DATE_TIME_FORMAT=new Intl.DateTimeFormat('zh-TW',{timeZone:'Asia/Taipei',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false});
export function taipeiDate(input=new Date()){const parts=DATE_FORMAT.formatToParts(input).reduce((a,p)=>(a[p.type]=p.value,a),{});return `${parts.year}-${parts.month}-${parts.day}`}
export function addLocalDays(dateOnly,days){const [y,m,d]=dateOnly.split('-').map(Number);return new Date(Date.UTC(y,m-1,d+days)).toISOString().slice(0,10)}
export function formatTaipei(input){return DATE_TIME_FORMAT.format(new Date(input))}
export function tomorrowTaipei(now=new Date()){return addLocalDays(taipeiDate(now),1)}
export function dateRange(start,end){const result=[];for(let date=start;date<end;date=addLocalDays(date,1))result.push(date);return result}
export function taipeiDateTimeInput(input=new Date()){const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Taipei',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(input).reduce((a,p)=>(a[p.type]=p.value,a),{});return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`}
export function taipeiInputToIso(value){if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value||''))throw new TypeError('日期時間格式錯誤');const iso=new Date(`${value}:00+08:00`);if(Number.isNaN(iso.valueOf()))throw new RangeError('無效日期時間');return iso.toISOString()}
