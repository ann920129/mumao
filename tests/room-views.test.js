import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const root=new URL('../',import.meta.url);

test('固定平面配置使用指定 21 房 grid area 且不依狀態重排',async()=>{const [js,css]=await Promise.all([readFile(new URL('app/main.js',root),'utf8'),readFile(new URL('styles.css',root),'utf8')]);for(const name of ['小總','大總','頭1','頭5','升1','升7','爵1','爵7'])assert.match(js,new RegExp(`${name}:'`));assert.match(css,/grid-template-areas:"small head1 head2 head3 head4 head5 up7"/);assert.doesNotMatch(css,/auto-fit|auto-fill/);assert.match(css,/width:846px;height:480px/)});

test('合成預覽也建立核定 21 房，讓瀏覽器可驗證固定配置',async()=>{const js=await readFile(new URL('app/main.js',root),'utf8');assert.match(js,/function demoCanonicalRooms/);assert.match(js,/length:7.*`爵/s);assert.match(js,/length:7.*`升/s);assert.match(js,/length:5.*`頭/s);assert.match(js,/\['小總','little_president'\],\['大總','president'\]/)});

test('房間頁提供平面、列表與房況月曆及縮放替代',async()=>{const js=await readFile(new URL('app/main.js',root),'utf8');for(const label of ['平面配置','列表模式','房況月曆','符合畫面','搜尋房名、貓咪或飼主'])assert.match(js,new RegExp(label));assert.match(js,/calendarSpan=7/);assert.match(js,/data-calendar-span="31"/);assert.match(js,/touch-action:pan-x pan-y pinch-zoom|floor-plan-viewport/)});

test('月曆排除詢問中預約並顯示同日入住退房、清潔與維護',async()=>{const js=await readFile(new URL('app/main.js',root),'utf8');assert.match(js,/\['confirmed','checked_in','waiting_checkout'\]/);assert.match(js,/date===start\?'入 '/);assert.match(js,/date===end.*退 /s);assert.match(js,/calendar-cleaning/);assert.match(js,/calendar-maintenance/)});
