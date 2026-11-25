# 測試報告

日期：2026-11-26（Asia/Taipei）

## 已執行

- `npm test`：28/28 通過。
- 計價：六房型、單/多貓、5→6、12→13、30、90 夜、跨月、閏年、跨年、訂金/尾款、錯誤日期/容量。
- 時區：UTC→臺北換日、跨年明日提醒、照護日不含退房日。
- 日期時間：`datetime-local` 與 Asia/Taipei/UTC 互轉。
- legacy：只讀探索、錯誤 JSON、原始備份、穩定 fingerprint。
- 安全靜態檢查：公開設定無高權限 key、service worker cache 邊界、RLS 表清單、私有 Storage、房間 exclusion、無 client DELETE policy。
- 工作流 guard：入住/退房必須有完成工作流、待清潔房不可入住、manager 不可修改價格/付款、需歸還物品不可保持 pending。
- 班別/通知靜態檢查：班別不可重疊、重要交接確認、未完成責任例外、通知轉換與「複製≠送出」。
- 用藥靜態檢查：未確認藥單不可執行、原子 claim、不確定結果不可直接重試、主管人工解鎖、排程限住宿期間。
- 日報檢查：缺少紀錄不推定正常、只輸出公開白名單欄位、草稿/主管核准/人工傳送狀態受 RPC 保護。
- 庫存靜態檢查：row lock、idempotency、單位一致、未知數量不轉 0、負庫存拒絕與低庫存提醒。
- 瀏覽器 smoke：Chrome headless、HTTP server；首頁、`#reports` 與 `#items` 路由、日報安全提示、庫存紀錄與合成預覽成功渲染。
- `node --check`：主要 JS modules 與 service worker 無語法錯誤。
- GitHub Actions run `45722004018`：application job 通過（8 秒）；database job 通過（1 分 21 秒），10 個 migrations、seed、第二次 reset 與 schema lint 全部成功。
- 首次 CI 曾在 migration 005 發現 `ensure_care_day` 複合 rowtype 指派語法錯誤；修正後已由下一輪從零重建驗證通過。
- GitHub Actions run `45724836518`：pgTAP 兩組織、owner/staff/customer/inactive 角色測試 10/10 通過，確認跨租戶讀寫隔離、停用帳號阻擋與 staff 價格更新不生效。

## 未驗證（不得視為通過）

- 遠端 Supabase 套用、Auth invitation/deactivation、Storage signed URL、Realtime/重連、Edge Function。
- 同時預約、同日 turnover、用藥雙人競爭、庫存重送、通知改期等資料庫整合測試。
- 上傳壓縮/方向/重試、完整 PWA install/offline shell、iOS Safari、平板/桌面、可及性與壓力測試。
- GitHub Pages、Auth redirect 與實際部署 URL。

第一次測試曾有 2 個「測試規則本身」失敗（註解提到 service role、RLS 由動態 SQL 建立）；已修正檢查方式後重跑 20/20。沒有掩蓋產品失敗。
