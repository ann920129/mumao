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
- [x] 建立多租戶 schema、複合 FK、RLS、私有 Storage、Realtime、audit 與 optimistic version。
- [x] 建立房間排他、庫存冪等、用藥 claim/追蹤、通知去重、照護工作與清潔 RPC。
- [x] 建立安全人員邀請 Edge Function 與 legacy JSON 備份/驗證/指紋。
- [x] 建立必備文件與自動測試。

## 目前工作

- [ ] 在實際 Supabase free project 套用遷移並做兩組織、多角色與 Storage 整合驗證。

## 待完成

- [ ] 飼主/貓咪編輯、照護紀錄編輯、物品異動/照片、異常追蹤/結案、交接與日報完整畫面。
- [ ] 圖片 client 壓縮、EXIF 方向修正、縮圖與 orphan 排程清理。
- [ ] 完整 legacy preview/import UI 與錯誤 CSV。
- [ ] 月營收/住房率、授權匯出、PDF/圖像日報與可選客戶入口。
- [ ] Playwright 互動/可及性/多尺寸測試與實際 GitHub Pages 驗證。

## 阻塞

- `BLOCKED`：沒有 Supabase project URL/公開 key，遷移未實際套用，雲端整合測試未執行。
- `BLOCKED`：尚未取得合併與 production Pages 上線核准，因此維持 PR 未合併、未部署。

## 測試結果

- `TESTED`：`npm test`，22/22 通過（計價、日期/臺北時間、legacy、安全與工作流 guard 靜態檢查）。
- `TESTED`：Chrome headless 390×844 實際載入，首頁與底部導覽成功渲染。
- `UNVERIFIED`：Supabase SQL 實際執行、兩租戶 RLS、Realtime、Storage、Edge Function、PWA 安裝與正式 Pages。

## 重要決策

- 原始 repository 只有 `index.html`，無 localStorage key、房號、後端或未提交變更。
- 不建置離線業務寫入；斷線時保留明確失敗狀態，避免離線重播不確定用藥。
- 背景通知未宣稱可用；目前以登入/開啟應用時的補償同步產生站內提醒。

## 最新提交

- `5c74c23` — `feat: add owner cat and room onboarding`（最近一次功能提交；本檔後續 checkpoint 提交請以 `git log -1` 查詢）
- 已推送 `origin/feature/care-management-v2`；PR：<https://github.com/ann920129/mumao/pull/1>

## 精確下一步

1. 依 `docs/SUPABASE_SETUP.md` 建立測試專案並執行 `supabase db push`。
2. 建立兩個測試組織與 owner/manager/staff 合成帳號，執行跨租戶/RPC/Storage 測試。
3. 依測試結果修 migration，再實作退房與物品歸還核對畫面。
