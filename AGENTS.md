# 開發守則

- 介面文字使用繁體中文；日期以 `Asia/Taipei`、金額以 TWD 顯示。
- 六種房型、單/多貓價格、6/13/30/90 晚門檻與 30% 訂金算法是既有商業規則；變更前必須新增回歸測試並取得業主確認。
- 業務資料只進 Supabase；不得新增 localStorage 業務儲存。舊版工具只能讀取、預覽、備份，驗證成功前不得刪除來源。
- 所有新租戶資料表都要有 `organization_id`、複合關聯與 RLS。重要動作走鎖定、冪等 RPC，不可只靠前端隱藏按鈕。
- 不提交密鑰、真實個資、處方或照片。service worker 只能快取公開殼層。
- 修改後執行 `npm test` 與瀏覽器 smoke test，更新 `TASKS.md`、`CHANGELOG.md`、`docs/TEST_REPORT.md`。
- 未取得明確核准不得合併 main、套用正式資料庫遷移或宣稱已部署。
