# 開發 checkpoint

更新：2026-11-26（Asia/Taipei）

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

## 目前工作

- [ ] 以 GitHub Actions 本地 Supabase 驗證全部 migration；通過後再做兩組織、多角色與 Storage 整合測試。

## 待完成

- [ ] 飼主/貓咪編輯、照護紀錄編輯、物品異動/照片與異常追蹤/結案完整畫面。
- [ ] 圖片 client 壓縮、EXIF 方向修正、縮圖與 orphan 排程清理。
- [ ] 完整 legacy preview/import UI 與錯誤 CSV。
- [ ] 月營收/住房率、授權匯出、PDF/圖像日報與可選客戶入口。
- [ ] Playwright 互動/可及性/多尺寸測試與實際 GitHub Pages 驗證。

## 阻塞

- `BLOCKED`：沒有 Supabase project URL/公開 key，遷移未實際套用，雲端整合測試未執行。
- `BLOCKED`：尚未取得合併與 production Pages 上線核准，因此維持 PR 未合併、未部署。

## 測試結果

- `TESTED`：`npm test`，28/28 通過（計價、日期/臺北時間、legacy、安全、工作流、通知、用藥、日報與庫存語意檢查）。
- `TESTED`：Chrome headless 實際載入首頁、日報與物品路由；日報安全提示及庫存紀錄成功渲染。
- `PENDING`：GitHub Actions 將以 Supabase CLI 3.4.0 / PostgreSQL 17 實際重建 migrations、seed 並執行 schema lint。
- `UNVERIFIED`：Supabase SQL 實際執行、兩租戶 RLS、Realtime、Storage、Edge Function、PWA 安裝與正式 Pages。

## 重要決策

- 原始 repository 只有 `index.html`，無 localStorage key、房號、後端或未提交變更。
- 不建置離線業務寫入；斷線時保留明確失敗狀態，避免離線重播不確定用藥。
- 背景通知未宣稱可用；目前以登入/開啟應用時的補償同步產生站內提醒。

## Git 狀態

- 功能 checkpoints 持續採小步提交；精確最新提交請以 `git log -1 --oneline` 查詢。
- 已推送 `origin/feature/care-management-v2`；PR：<https://github.com/ann920129/mumao/pull/1>

## 精確下一步

1. 依 `docs/SUPABASE_SETUP.md` 建立測試專案並執行 `supabase db push`。
2. 建立兩個測試組織與 owner/manager/staff 合成帳號，執行跨租戶/RPC/Storage 測試。
3. 依測試結果修 migration，再完成影像流程與 legacy 匯入。
