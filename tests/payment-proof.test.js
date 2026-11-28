import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {MEDIA_CATEGORIES,imageTarget} from '../app/services/media.js';

const sql=await readFile(new URL('../supabase/migrations/202611280013_deposit_payment_proofs.sql',import.meta.url),'utf8');

test('付款證明沿用私有媒體且支援一至八張截圖',()=>{
  assert.equal(MEDIA_CATEGORIES.has('payment_proof'),true);
  assert.equal(imageTarget('payment_proof',4000,2000).width,2800);
  assert.match(sql,/category='payment_proof' and status='active'/);
  assert.match(sql,/array_length\(p_media_ids,1\),0\) not between 1 and 8/);
  assert.match(sql,/payment_proof_media/);
  assert.doesNotMatch(sql,/base64/i);
});

test('上傳只進入待核對，不會自動確認付款或預約',()=>{
  const register=sql.match(/create or replace function public\.register_payment_proof[\s\S]*?grant execute/i)?.[0]||'';
  assert.match(register,/payment_status='proof_pending'/);
  assert.doesNotMatch(register,/insert into public\.payments/i);
  assert.doesNotMatch(register,/status='confirmed'/i);
});

test('只有業主可核對實際入帳並採版本鎖與不可重複付款',()=>{
  const verify=sql.match(/create or replace function public\.verify_payment_proof[\s\S]*?grant execute/i)?.[0]||'';
  assert.match(verify,/current_user_has_org\(v\.organization_id,array\['owner'\]\)/);
  assert.match(verify,/for update/);
  assert.match(verify,/v\.version<>p_expected_version/);
  assert.match(sql,/unique index payments_one_per_proof/);
  assert.match(verify,/payment_type='refund' then -amount else amount/);
});

test('付款證明表只開放租戶內讀取，寫入必須走 RPC',()=>{
  assert.match(sql,/alter table public\.payment_proofs enable row level security/);
  assert.match(sql,/payment_proofs_staff_select/);
  assert.doesNotMatch(sql,/create policy payment_proofs_\w+_(insert|update)/i);
  assert.match(sql,/create trigger payment_proofs_audit/);
});
