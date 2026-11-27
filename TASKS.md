# 開發 checkpoint

更新：2026-11-28（Asia/Taipei）

## 已完成

- [x] 檢查遠端、歷史與原始單檔架構；建立 `backup/pre-care-management-v2` 與 `feature/care-management-v2`。
- [x] 保留六種房型、一般/長住/多貓價格、6/13/30/90 夜與 30% 訂金。
- [x] 建立手機優先 PWA、登入、儀表板、房況、搜尋預約、雲端建立預約、待辦與功能總覽。
- [x] 建立飼主/貓咪基本資料新增與搜尋、業主建立實體房間，讓空白旅館可完成預約前置資料。
- [x] 建立可存草稿的入住確認工作流；完成時由交易鎖定預約、更新房態並建立照護日。
- [x] 建立每日餐點、飲水、排尿、排便、活動輸入與 Day N 檢視，保留未知／未觀察狀態。
- [x] 建立住宿物品（含多貓共用）登記與異常事件回報/跨班顯示畫面。
- [x] 建立退房草稿、逐件物品歸還核對、尾款例外理由、完成退房與清潔工作產生流程。
- [x] 建立清潔四項必要核對；未完成前房間維持待清潔，不能直接入住。
- [x] 新增預約資料庫 guard：manager 不可改價格/付款，入住/退房狀態必須經完成的工作流。
- [x] 建立排班、上班、交班前摘要、重要交接確認與下班例外紀錄；班別不可重疊。
- [x] 建立明日通知專用畫面與狀態 RPC；複製不等於送出，實際送出才記錄通知時間/管道。
- [x] 建立用藥安全閉環：待確認藥單、主管確認後排程、原子 claim、實際結果與不確定狀態人工解鎖。
- [x] 建立飼主日報：只從實際紀錄產生、公開補充白名單、主管核准、複製與人工傳送確認。
- [x] 建立物品庫存異動：取用與食用分離、未知數量初始化、row lock/冪等、單位驗證與低庫存提醒。
- [x] 建立多租戶 schema、複合 FK、RLS、私有 Storage、Realtime、audit 與 optimistic version。
- [x] 建立房間排他、庫存冪等、用藥 claim/追蹤、通知去重、照護工作與清潔 RPC。
- [x] 建立安全人員邀請 Edge Function 與 legacy JSON 備份/驗證/指紋。
- [x] 建立必備文件與自動測試。
- [x] GitHub Actions 以 Supabase CLI 3.4.0 / PostgreSQL 17 從零套用 11 個 migrations、seed 並通過 schema lint。
- [x] pgTAP 建立兩組織、owner/staff/customer/inactive 合成帳號，10/10 驗證租戶隔離、角色讀取、越權寫入與價格保護。
- [x] 完成私密照片前端處理：相機／相簿選取、EXIF 去除、方向修正、WebP 主圖/縮圖、個別進度與失敗重試。
- [x] pgTAP 59/59 驗證 RLS、私密照片路徑/物件核對、用藥並行安全、明日提醒冪等，以及入住→退房→清潔完整流程。
- [x] 將 11 個 migrations 套用至新建 Supabase 測試專案；遠端 migration 清單與本機完全一致，public/extensions schema lint 完成。
- [x] M0：記錄 main/備份 SHA、原版 `index.html` Git blob/SHA-256、GitHub Pages source，並把永久保護規則寫入 V2 `AGENTS.md`。

## 新增升級里程碑（2026-11-28）

- [x] M0 原版保護基準與永久規則。
- [x] M1 原版計價器逐位元副本、V2 adapter、顧客報價複製與完整 parity 測試。
- [x] M2 預約詢問、排序、明細與受權限保護的編輯。
- [x] M3 訂金付款證明與財務核對。
- [x] M4 暮貓限定 21 房配置、固定平面圖與資料庫容量驗證。
- [x] M5 多貓房間照護摘要與共用觀察。
- [x] M6 個人顯示偏好與同步。
- [x] M7 平面／列表／月曆與多尺寸防跑版。
- [ ] M8 CI 已以 16 migrations 重建並通過 pgTAP 68/68；production 遠端 012–016 與實際 Auth／Storage／Realtime 仍待遷移核准。
- [ ] M9 文件與獨立 V2 部署準備已完成；飼主／貓咪編輯已完成，其餘必要功能持續處理。

## 目前工作

- [ ] M8 雲端、RLS、Realtime、Storage、並行與完整流程驗證。
- [ ] 遠端測試專案的 Auth、實際 Storage HTTP 上傳、Realtime 雙裝置與 Edge Function 驗證；待設定公開 Project URL/key 與測試帳號。

## 待完成

- [x] 飼主/貓咪編輯：僅業主／主管顯示入口，以租戶條件、RLS 及 `version` 樂觀鎖避免跨裝置覆寫。
- [ ] 照護紀錄編輯、異常追蹤/結案完整畫面。
- [ ] 私密照片 orphan 排程清理與實際 Storage 上傳整合驗證。
- [ ] 完整 legacy preview/import UI 與錯誤 CSV。
- [ ] 月營收/住房率、授權匯出、PDF/圖像日報與可選客戶入口。
- [ ] Playwright 互動/可及性/多尺寸測試與實際 GitHub Pages 驗證。

## 阻塞

- `PARTIAL`：測試專案已套用 migrations；尚未把公開 Project URL/key 寫入本機設定，因此 Auth、Storage、Realtime 與 Edge Function 雲端整合測試未執行。
- `BLOCKED`：尚未取得合併與 production Pages 上線核准，因此維持 PR 未合併、未部署。

## 測試結果

- `TESTED`：`npm test`，38/38 通過（含原版 parity，以及詢問不占房、伺服器重算、row lock/樂觀版本與報價多版本靜態檢查）。
- `TESTED`：Supabase CLI 遠端 `db push --dry-run` 僅列出 migration 012，確認未寫入遠端；本機沒有 Docker，尚未執行實際 SQL。
- `TESTED`：GitHub Actions run `46040912429`：application 12 秒；database 1 分 26 秒，12 migrations 套用、清空重建、pgTAP 59/59 與 lint 全通過。
- `TESTED`：`npm test` 42/42 通過；付款證明測試確認多圖私有媒體、上傳不自動確認、只有業主可核帳、版本鎖與 RPC-only 寫入。
- `TESTED`：GitHub Actions run `46041951039`：application 5 秒；database 1 分 20 秒，13 migrations、重建、pgTAP 59/59 與 lint 全通過。
- `TESTED`：`npm test` 45/45 通過；精確 21 房名稱/數量、容量 trigger、房型一致與既有排他衝突檢查通過。
- `TESTED`：GitHub Actions run `46042818166`：application 13 秒；database 1 分 22 秒，14 migrations 連續套用、清空重建、pgTAP 59/59 與 lint 全通過。
- `TESTED`：`npm test` 48/48 通過；房間照護缺少紀錄維持待完成、用藥全數完成才彙總完成，共用排泄觀察不會寫入任何單一貓咪。
- `TESTED`：GitHub Actions run `46043672225`：application 7 秒；database 1 分 17 秒，15 migrations 連續套用、清空重建、pgTAP 59/59 與 lint 全通過。
- `TESTED`：Supabase production 標記專案僅執行 `db push --remote --dry-run`，列出 migrations 012–015，未寫入遠端。
- `TESTED`：`npm test` 52/52 通過；偏好依組織與帳號隔離、鍵值白名單、預設開關及關閉照片時不查詢私密縮圖均通過。
- `TESTED`：GitHub Actions run `46044485594`：application 4 秒；database 1 分 10 秒，16 migrations 連續套用、清空重建、pgTAP 59/59 與 lint 全通過。
- `TESTED`：Supabase production 標記專案僅執行 `db push --remote --dry-run`，列出 migrations 012–016，未寫入遠端。
- `TESTED`：`npm test` 56/56 通過；固定 grid-area、21 房預覽、三種檢視、詢問不占房與同日入住／退房標記通過。
- `TESTED`：Chrome 實際以桌面、390×844 手機、768×1024 平板檢查固定平面、可控縮放、包含式水平捲動、列表搜尋、週月曆與響應式房間明細；未見頁面層級橫向溢位。
- `TESTED`：GitHub Actions run `46063538658`：application 7 秒；database 1 分 14 秒，16 migrations 連續套用、清空重建、pgTAP 59/59 與 lint 全通過。
- `TESTED`：Supabase production 遠端 migration list 確認 001–011 一致、012–016 未套用；遠端 public/extensions lint 無 error，僅既有 bootstrap 函式 3 個 warning。
- `TESTED`：GitHub Actions run `46063908475`：application 4 秒；database 1 分 10 秒，16 migrations 重建、pgTAP 68/68 與 lint 全通過。
- `TESTED`：GitHub Actions run `46064343084` 全部成功；文件與部署守則變更未破壞 application/database 驗證。
- `TESTED`：`npm test` 57/57 通過；飼主／貓咪編輯角色限制、租戶條件及版本衝突檢查通過。Chrome 實際載入首頁並導覽至 21 房平面頁成功。
- `TESTED`：Chrome 實際操作「預約管理 → 住宿計價」，原版 iframe 六房型、選房計價與顧客報價複製成功；爵士房 1 夜為總價 NT$760、訂金 NT$228、尾款 NT$532。
- `TESTED`：Chrome headless 實際載入首頁、日報、物品與用藥路由；日報安全提示、庫存紀錄及用藥安全提示成功渲染。
- `TESTED`：GitHub Actions run `45722004018`：application 8 秒、database 1 分 21 秒，完整 migrations/seed 重建與 schema lint 皆通過。
- `TESTED`：GitHub Actions run `45724836518`：pgTAP 兩租戶/多角色 RLS 10/10 通過；application 與 database jobs 皆通過。
- `TESTED`：GitHub Actions run `45726110372`：11 個 migrations、seed、RLS pgTAP 與 schema lint 全部通過；application 31 秒、database 1 分 17 秒。
- `TESTED`：GitHub Actions run `45726780722`：私密照片 RPC/Storage 物件/跨租戶 pgTAP 9/9 通過；application 5 秒、database 1 分 10 秒。
- `TESTED`：GitHub Actions run `45727119199`：用藥競爭與翌日通知 pgTAP 23/23 通過；application 15 秒、database 2 分 21 秒。
- `TESTED`：GitHub Actions run `45727592893`：入住、物品歸還、退房與清潔 pgTAP 17/17 通過；application 6 秒、database 1 分 14 秒。
- `TESTED`：遠端 Supabase 測試專案已成功套用 11 個 migrations；`migration list --remote` 全數一致，遠端 schema lint 完成（`bootstrap_organization` 有型別轉換與未使用變數警告，無 error）。
- `UNVERIFIED`：遠端 Auth/RLS 行為、Realtime、Storage 實際上傳、Edge Function、PWA 安裝與正式 Pages。遠端 pgTAP 因執行環境缺少 Docker/Podman，未能啟動 pg_prove 容器。

## 重要決策

- 原始 repository 只有 `index.html`，無 localStorage key、房號、後端或未提交變更。
- 不建置離線業務寫入；斷線時保留明確失敗狀態，避免離線重播不確定用藥。
- 背景通知未宣稱可用；目前以登入/開啟應用時的補償同步產生站內提醒。

## Git 狀態

- 功能 checkpoints 持續採小步提交；精確最新提交請以 `git log -1 --oneline` 查詢。
- 已推送 `origin/feature/care-management-v2`；PR：<https://github.com/ann920129/mumao/pull/1>

## 精確下一步

1. 依 `docs/SUPABASE_SETUP.md` 建立測試專案並執行 `supabase db push`。
2. 依 `docs/SUPABASE_SETUP.md` 建立兩個測試組織與 owner/manager/staff 合成帳號，執行實際 Auth/Storage/Realtime 測試。
3. 依測試結果修 migration，再部署 Edge Functions；未核准前不套用 production 或合併 main。
