# 系統架構

```text
GitHub Pages（公開靜態 PWA）
  ├─ Supabase Auth：員工登入/密碼重設
  ├─ PostgREST + RPC：RLS 與交易式業務操作
  ├─ Realtime：預約、待辦、異常、通知、清潔
  ├─ Private Storage：organization/reservation/category/uuid.ext
  └─ Edge Function：邀請員工等高權限操作
```

前端維持 vanilla HTML/CSS/ES modules，避免不必要框架與建置成本。`app/domain` 不依賴瀏覽器，直接由 Node 回歸測試；`repository` 是資料存取邊界。公開設定只含 project URL 與 publishable/anon key，真正授權由 RLS/RPC 判斷。

系統 online-first。service worker 只快取同源公開殼層，排除 `config.js`、Supabase、token、客戶資料、照片與 signed URL。不自動重播不確定的用藥動作。

提醒採雙層設計：資料庫唯一鍵防重複；登入/開啟應用時執行補償同步。尚未設定可靠背景排程，因此不宣稱關閉應用後仍會推播。
