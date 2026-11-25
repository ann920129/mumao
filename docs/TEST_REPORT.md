# 測試報告

日期：2026-11-26（Asia/Taipei）

## 已執行

- `npm test`：22/22 通過。
- 計價：六房型、單/多貓、5→6、12→13、30、90 夜、跨月、閏年、跨年、訂金/尾款、錯誤日期/容量。
- 時區：UTC→臺北換日、跨年明日提醒、照護日不含退房日。
- 日期時間：`datetime-local` 與 Asia/Taipei/UTC 互轉。
- legacy：只讀探索、錯誤 JSON、原始備份、穩定 fingerprint。
- 安全靜態檢查：公開設定無高權限 key、service worker cache 邊界、RLS 表清單、私有 Storage、房間 exclusion、無 client DELETE policy。
- 工作流 guard：入住/退房必須有完成工作流、待清潔房不可入住、manager 不可修改價格/付款、需歸還物品不可保持 pending。
- 瀏覽器 smoke：Chrome headless、390×844、HTTP server；首頁、2026-11-26 臺北日期、12 張卡片與五欄底部導覽成功渲染。
- `node --check`：主要 JS modules 與 service worker 無語法錯誤。

## 未驗證（不得視為通過）

- migration 在真實 Supabase PostgreSQL 的語法/套用、RLS 兩租戶與多角色、Auth invitation/deactivation、Storage signed URL、Realtime/重連、Edge Function。
- 同時預約、同日 turnover、用藥雙人競爭、庫存重送、通知改期等資料庫整合測試。
- 上傳壓縮/方向/重試、完整 PWA install/offline shell、iOS Safari、平板/桌面、可及性與壓力測試。
- GitHub Pages、Auth redirect 與實際部署 URL。

第一次測試曾有 2 個「測試規則本身」失敗（註解提到 service role、RLS 由動態 SQL 建立）；已修正檢查方式後重跑 20/20。沒有掩蓋產品失敗。
