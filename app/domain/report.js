const labels={
  finished:'吃完',small_remaining:'剩少量',half_eaten:'約吃一半',small_eaten:'只吃少量',not_eaten:'未進食',offered:'已提供',observing:'持續觀察',not_applicable:'不適用',
  normal:'紀錄為正常',less:'較少',more:'較多',not_observed:'尚未觀察到',unknown:'不確定',
  not_yet_observed:'尚未觀察',none_observed:'未觀察到',abnormal:'有異常',
  formed:'成形',hard:'偏硬',soft:'偏軟',diarrhea:'腹瀉',
  pending:'待執行',in_progress:'執行中',administered:'已依指示執行',unsuccessful:'未成功',requires_confirmation:'需人工確認',paused:'暫停',
  appetite:'食慾',water:'飲水',urination:'排尿',defecation:'排便',vomiting:'嘔吐',low_activity:'活動量偏低',injury:'傷勢',behavior:'行為',medication:'用藥',other:'其他',
  observation:'觀察',follow_up:'需追蹤',high:'高風險',emergency:'緊急',open:'未結案',monitoring:'追蹤中',resolved:'已處理',closed:'已結案'
};

const label=value=>labels[value]||value||'未填寫';
const time=value=>value?`${value} `:'';
const quantity=(value,unit)=>value===null||value===undefined||value===''?'':`${value}${unit||''}`;
const section=(title,items,formatter)=>[`【${title}】`,...(items?.length?items.map(formatter):['尚無已記錄項目'])].join('\n');

export function formatDailyReport(content={}){
  const meals=section('餐點',content.meals,x=>`${time(x.time)}${x.label||'餐點'}：${label(x.status)}${quantity(x.consumed_quantity,x.unit)?`，實際吃 ${quantity(x.consumed_quantity,x.unit)}`:''}`);
  const water=section('飲水',content.water,x=>`${time(x.time)}${label(x.observation)}${quantity(x.amount,x.unit)?`，${quantity(x.amount,x.unit)}`:''}${x.water_replaced===true?'，已換水':''}`);
  const urination=section('排尿',content.urination,x=>`${time(x.time)}${label(x.observation_state)}${x.clump_count!==null&&x.clump_count!==undefined?`，尿塊 ${x.clump_count} 個`:''}${x.suspected_blood?'，疑似血尿':''}${x.repeated_visits?'，有頻繁進出砂盆':''}`);
  const defecation=section('排便',content.defecation,x=>`${time(x.time)}${label(x.observation_state)}${x.consistency?`，${label(x.consistency)}`:''}${x.suspected_blood?'，疑似血便':''}`);
  const activity=section('活動與狀態',content.activity,x=>`${time(x.time)}${[x.activity,x.mood,x.social_interaction].filter(Boolean).join('；')||'已建立活動紀錄'}${x.vomiting?'；有嘔吐紀錄':''}${x.visible_injury?'；有可見傷勢紀錄':''}`);
  const medications=section('用藥',content.medications,x=>`${time(x.actual_time||x.time)}${x.name||'藥品'}：${label(x.status)}`);
  const events=section('需留意事件',content.events,x=>`${time(x.time)}${label(x.category)}｜${label(x.severity)}｜${label(x.status)}`);
  return [`${content.cat_name||'貓咪'}｜${content.report_date||''} 照護日報`,'以下僅依系統中已實際記錄的內容整理；尚無紀錄不代表正常。',content.public_message?.trim()?`\n${content.public_message.trim()}`:'',meals,water,urination,defecation,activity,medications,events].filter(Boolean).join('\n\n');
}
