# 開發守則

## 原版訂房計價 Demo 永久保護

- `main`、原版 GitHub Pages 與原版 `index.html` 永久唯讀；不得修改、搬移、重新命名、刪除、覆寫、合併 V2、force-push 或變更預設分支。
- V2 只能在 `feature/care-management-v2` 開發；所有整合使用原版的獨立副本、adapter 或 wrapper，不得讓原版依賴 V2 或 Supabase。
- 不得修改或刪除 `backup/pre-care-management-v2`；每次提交與推送前確認目前分支，推送後確認 main SHA 與原版檔案 hash 未變。
- 原版保護基準、Pages 設定與雜湊記錄於 `docs/ORIGINAL_DEMO_BASELINE.md`。若基準與遠端不一致，先停止並查明是否為業主的合法變更，不得直接回復。
- V2 必須使用獨立部署 URL；未取得明確核准不得變更原版 Pages、套用正式環境 migration、合併 main 或宣稱正式部署。

- 介面文字使用繁體中文；日期以 `Asia/Taipei`、金額以 TWD 顯示。
- 六種房型、單/多貓價格、6/13/30/90 晚門檻與 30% 訂金算法是既有商業規則；變更前必須新增回歸測試並取得業主確認。
- 業務資料只進 Supabase；不得新增 localStorage 業務儲存。舊版工具只能讀取、預覽、備份，驗證成功前不得刪除來源。
- 所有新租戶資料表都要有 `organization_id`、複合關聯與 RLS。重要動作走鎖定、冪等 RPC，不可只靠前端隱藏按鈕。
- 不提交密鑰、真實個資、處方或照片。service worker 只能快取公開殼層。
- 修改後執行 `npm test` 與瀏覽器 smoke test，更新 `TASKS.md`、`CHANGELOG.md`、`docs/TEST_REPORT.md`。
- 未取得明確核准不得合併 main、套用正式資料庫遷移或宣稱已部署。
