# 測試報告

日期：2026-11-28（Asia/Taipei）

## 已執行

- `npm test`：34/34 通過。
- 原版保護：`origin/main` 與 `backup/pre-care-management-v2` 均為 `70226ecd16f650f3fa6691fb306316fe7104ceb5`；兩者 `index.html` 無差異，Git blob `3f42a50ae45da4e28a252f0e08603daf66836373`。
- V2 計價副本：Git blob `3f42a50ae45da4e28a252f0e08603daf66836373`、SHA-256 `21f23ad100a38e048596971c98a000d3db3b40e3a7a960fea1a4725e49893d94`，與受保護原版相同。
- 計價 parity matrix：六房型、單貓/各房型最大貓數、1/5/6/12/13/29/30/89/90 夜共 108 組價格、總額、30% 訂金與尾款逐案通過。
- 原版 Pages：仍由 `main` 根目錄提供 `https://ann920129.github.io/mumao/`，HTTPS 啟用，未修改設定。
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
- 私密照片單元/靜態檢查：允許格式、12 MB 上限、一般/高細節尺寸策略、安全建檔 RPC、Storage 物件核對與刪除權限。
- 瀏覽器 smoke：Chrome 實際操作 `#reservations` → `#pricing`，同源原版 iframe、六房型、選房即時計價及顧客報價複製成功；爵士房 1 夜顯示總價 NT$760、訂金 NT$228、尾款 NT$532。
- `node --check`：主要 JS modules 與 service worker 無語法錯誤。
- GitHub Actions run `45722004018`：application job 通過（8 秒）；database job 通過（1 分 21 秒），10 個 migrations、seed、第二次 reset 與 schema lint 全部成功。
- 首次 CI 曾在 migration 005 發現 `ensure_care_day` 複合 rowtype 指派語法錯誤；修正後已由下一輪從零重建驗證通過。
- GitHub Actions run `45724836518`：pgTAP 兩組織、owner/staff/customer/inactive 角色測試 10/10 通過，確認跨租戶讀寫隔離、停用帳號阻擋與 staff 價格更新不生效。
- GitHub Actions run `45726110372`：application job 31 秒、database job 1 分 17 秒；11 個 migrations、seed、RLS pgTAP 與 schema lint 全部通過。
- GitHub Actions run `45726780722`：私密照片 pgTAP 9/9 通過，涵蓋伺服器路徑、跨租戶拒絕、禁止直接 insert、主圖/縮圖完整性與 active 狀態；application 5 秒、database 1 分 10 秒。
- GitHub Actions run `45727119199`：用藥/提醒 pgTAP 23/23 通過，涵蓋雙人競爭、claim 擁有者、不確定結果主管解鎖、臺北明日、複製不等於送出與重跑冪等；application 15 秒、database 2 分 21 秒。
- GitHub Actions run `45727592893`：住宿流程 pgTAP 17/17 通過，涵蓋入住人工核對、照護日、物品歸還門檻、退房、房間待清潔、四項清潔後釋放；application 6 秒、database 1 分 14 秒。
- Supabase 測試專案：11 個 migrations 已實際 `db push` 成功；遠端 migration 清單與本機 11/11 一致。
- 遠端 `db lint --remote --level warning`：完成，無 error；`bootstrap_organization` 回報 1 個 text→jsonb 型別轉換及 2 個未使用變數 warning。

## 未驗證（不得視為通過）

- 遠端 Auth invitation/deactivation、RLS 行為、Storage signed URL、Realtime/重連、Edge Function。
- 遠端 pgTAP 指令需要本機 Docker/Podman 啟動 pg_prove；目前環境沒有容器執行器，因此未執行，不能以本地 CI 的 59/59 代替遠端結果。
- 同時預約、同日 turnover、真正平行連線競爭、庫存重送與通知改期等額外資料庫壓力測試；目前用藥以兩帳號連續舊版本模擬競爭。
- 實際瀏覽器圖片解碼/壓縮/方向、Storage 上傳/重試/signed URL、完整 PWA install/offline shell、iOS Safari、平板/桌面、可及性與壓力測試。
- GitHub Pages、Auth redirect 與實際部署 URL。

第一次測試曾有 2 個「測試規則本身」失敗（註解提到 service role、RLS 由動態 SQL 建立）；已修正檢查方式後重跑 20/20。沒有掩蓋產品失敗。
