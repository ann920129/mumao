import {getSupabase} from '../lib/supabase.js';

const TYPES=new Set(['image/jpeg','image/png','image/webp','image/heic','image/heif']);
const HIGH_DETAIL=new Set(['medication_packaging','prescription','food_packaging','food_instructions','payment_proof']);
export const MEDIA_CATEGORIES=new Set(['cat_profile','checkin_condition','luggage','food_packaging','food_instructions','supplement','medication_packaging','prescription','daily_care','abnormal_event','elimination','checkout_luggage','payment_proof','other']);

export function validateImage(file,{maxBytes=12*1024*1024}={}){
  if(!file||!TYPES.has(file.type))throw new TypeError('僅支援 JPEG、PNG、WebP、HEIC 或 HEIF 圖片');
  if(!Number.isFinite(file.size)||file.size<=0)throw new RangeError('圖片檔案是空的');
  if(file.size>maxBytes)throw new RangeError('原始圖片不可超過 12 MB');
  return true;
}

export function imageTarget(category,width,height){
  if(!MEDIA_CATEGORIES.has(category))throw new TypeError('不支援的照片分類');
  const max=HIGH_DETAIL.has(category)?2800:1920,scale=Math.min(1,max/Math.max(width,height));
  return{width:Math.max(1,Math.round(width*scale)),height:Math.max(1,Math.round(height*scale)),quality:HIGH_DETAIL.has(category)?0.92:0.84};
}

async function decode(file){
  try{return await createImageBitmap(file,{imageOrientation:'from-image'})}catch(error){
    if(['image/heic','image/heif'].includes(file.type))throw new Error('此瀏覽器無法安全處理 HEIC/HEIF；請改用相機的 JPEG/相容格式後重試');
    const url=URL.createObjectURL(file);try{const image=new Image();image.decoding='async';image.src=url;await image.decode();return image}finally{URL.revokeObjectURL(url)}
  }
}

function render(source,width,height,quality){
  const canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;
  const context=canvas.getContext('2d',{alpha:false});if(!context)throw new Error('裝置無法處理圖片');
  context.fillStyle='#fff';context.fillRect(0,0,width,height);context.drawImage(source,0,0,width,height);
  return new Promise((resolve,reject)=>canvas.toBlob(blob=>blob?.type==='image/webp'?resolve(blob):reject(new Error('瀏覽器無法產生安全的 WebP 圖片')),'image/webp',quality));
}

export async function processPrivateImage(file,category){
  validateImage(file);if(!MEDIA_CATEGORIES.has(category))throw new TypeError('不支援的照片分類');
  const source=await decode(file);try{const target=imageTarget(category,source.width,source.height),thumbScale=Math.min(1,480/Math.max(target.width,target.height)),thumbWidth=Math.max(1,Math.round(target.width*thumbScale)),thumbHeight=Math.max(1,Math.round(target.height*thumbScale));const [main,thumbnail]=await Promise.all([render(source,target.width,target.height,target.quality),render(source,thumbWidth,thumbHeight,.76)]);return{main,thumbnail,width:target.width,height:target.height,originalName:file.name||'image',originalMime:file.type,privacyProcessed:true}}finally{source.close?.()}
}

export async function uploadPrivateImage({organizationId,reservationId,reservationCatId=null,stayItemId=null,abnormalEventId=null,category,file,onProgress=()=>{}}){
  onProgress({state:'processing',percent:5});const processed=await processPrivateImage(file,category);const client=await getSupabase();
  onProgress({state:'registering',percent:30});const {data:media,error:beginError}=await client.rpc('begin_media_upload',{p_organization_id:organizationId,p_reservation_id:reservationId,p_category:category,p_original_name:processed.originalName,p_original_mime:processed.originalMime,p_main_size:processed.main.size,p_thumbnail_size:processed.thumbnail.size,p_width:processed.width,p_height:processed.height,p_reservation_cat_id:reservationCatId,p_stay_item_id:stayItemId,p_abnormal_event_id:abnormalEventId});if(beginError)throw beginError;
  const thumbPath=media.metadata.thumbnail_path,uploaded=[];
  try{
    onProgress({state:'uploading_main',percent:45});let result=await client.storage.from('private-media').upload(media.storage_path,processed.main,{cacheControl:'3600',upsert:false,contentType:'image/webp'});if(result.error)throw result.error;uploaded.push(media.storage_path);
    onProgress({state:'uploading_thumbnail',percent:75});result=await client.storage.from('private-media').upload(thumbPath,processed.thumbnail,{cacheControl:'3600',upsert:false,contentType:'image/webp'});if(result.error)throw result.error;uploaded.push(thumbPath);
    onProgress({state:'finalizing',percent:90});const {data:active,error:finalError}=await client.rpc('finalize_media_upload',{p_media_id:media.id,p_expected_version:media.version});if(finalError)throw finalError;onProgress({state:'complete',percent:100});return active;
  }catch(error){try{if(uploaded.length)await client.storage.from('private-media').remove(uploaded)}catch{}try{await client.rpc('fail_media_upload',{p_media_id:media.id,p_expected_version:media.version})}catch{}throw error}
}

export async function signedMediaUrls(media,expiresIn=300){
  const paths=[media.storage_path,media.metadata?.thumbnail_path].filter(Boolean),client=await getSupabase();const {data,error}=await client.storage.from('private-media').createSignedUrls(paths,Math.min(Math.max(expiresIn,60),600));if(error)throw error;return{full:data?.[0]?.signedUrl||null,thumbnail:data?.[1]?.signedUrl||data?.[0]?.signedUrl||null}
}
