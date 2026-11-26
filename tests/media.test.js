import test from 'node:test';
import assert from 'node:assert/strict';
import {imageTarget,validateImage} from '../app/services/media.js';

const image=(type='image/jpeg',size=1024)=>({type,size});

test('私密照片只接受允許的圖片格式與合理大小',()=>{
  assert.equal(validateImage(image()),true);
  assert.throws(()=>validateImage(image('application/pdf')),/僅支援/);
  assert.throws(()=>validateImage(image('image/png',0)),/空的/);
  assert.throws(()=>validateImage(image('image/webp',12*1024*1024+1)),/12 MB/);
});

test('一般照片縮至 1920，高細節標籤保留至 2800',()=>{
  assert.deepEqual(imageTarget('luggage',4000,2000),{width:1920,height:960,quality:.84});
  assert.deepEqual(imageTarget('prescription',4000,2000),{width:2800,height:1400,quality:.92});
  assert.deepEqual(imageTarget('supplement',800,600),{width:800,height:600,quality:.84});
  assert.throws(()=>imageTarget('unknown',800,600),/不支援/);
});
