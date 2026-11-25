const DATE_FORMAT=new Intl.DateTimeFormat('zh-TW',{timeZone:'Asia/Taipei',year:'numeric',month:'2-digit',day:'2-digit'});
const DATE_TIME_FORMAT=new Intl.DateTimeFormat('zh-TW',{timeZone:'Asia/Taipei',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false});
export function taipeiDate(input=new Date()){const parts=DATE_FORMAT.formatToParts(input).reduce((a,p)=>(a[p.type]=p.value,a),{});return `${parts.year}-${parts.month}-${parts.day}`}
export function addLocalDays(dateOnly,days){const [y,m,d]=dateOnly.split('-').map(Number);return new Date(Date.UTC(y,m-1,d+days)).toISOString().slice(0,10)}
export function formatTaipei(input){return DATE_TIME_FORMAT.format(new Date(input))}
export function tomorrowTaipei(now=new Date()){return addLocalDays(taipeiDate(now),1)}
export function dateRange(start,end){const result=[];for(let date=start;date<end;date=addLocalDays(date,1))result.push(date);return result}
