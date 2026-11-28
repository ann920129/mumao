# 資料庫設計

十六個 migration 依序建立 foundation、operations、security/RPC、營運 workflows、入住、退房 guard、班別/通知、用藥安全、飼主日報、庫存追蹤、私密照片、預約詢問、付款證明、暮貓 21 房、房間照護摘要，以及個人顯示偏好。所有業務主鍵為 UUID，敏感表啟用 RLS，跨資料表關係以 `(organization_id, id)` 複合外鍵驗證租戶一致。

核心原則：

- 預約與房間由 `room_allocations` 的 GiST exclusion constraint 防止 `[入住,退房)` 重疊，支援同日退房→清潔→入住。
- `price_snapshots` 永久保存伺服器驗證結果；`create_reservation` 不信任前端總額。
- 每次住宿的照護指示存於 `reservation_cats.care_snapshot`，不會被永久貓咪資料覆寫。
- 共用物品使用 `shared_group_id`；庫存移動有 idempotency key 且 row lock 防止重扣，未知數量不轉成 0。
- 庫存的「取出／提供」才扣除剩餘量；實際食用另留紀錄而不重扣。盤點修正、耗損與歸還需原因，單位不符或負庫存會被拒絕。
- 用藥以唯一排程、row lock、version 與 claim/finish 兩階段避免重複。失敗或不確定會建立高優先追蹤工作。
- 通知唯一鍵為旅館/預約/類型/日期；複製訊息只是 `message_copied`，不等於已送出。
- `stay_workflows` 保存入住/退房草稿；完成入住 RPC 會驗證逐項人工確認、鎖定預約、更新房態並建立照護日期。
- 完成退房前，所有需歸還物品必須有非 pending 核對；未付尾款需留下主管例外理由。退房交易把房間改為待清潔並建立 cleaning task。
- reservation guard 禁止 manager 修改價格/付款欄位，且入住/退房狀態必須有已完成工作流；待清潔房間不能入住。
- 班別由 owner/manager 排定，同一人時段不可重疊；重要交接未確認或工作未轉交時不能靜默下班。
- 通知狀態由鎖定 RPC 轉換；只有 `sent` 會寫入實際通知時間，且必須指定管道。
- 藥單由工作人員逐字登記為待確認，只有 owner/manager 確認後才按住宿時間產生排程。結果不確定或失敗後，只有 owner/manager 可人工決定是否重試。
- 日報草稿由資料庫從當日實際紀錄的公開欄位重建，不讀照護 notes、處方或特殊用藥指示。直接 insert/update policy 已移除；主管核准後才能標記人工傳送。
- 私密照片先由 `begin_media_upload` 產生含組織/預約/分類的伺服器路徑；前端只能上傳至自己的路徑，主圖與縮圖都存在後 `finalize_media_upload` 才標為可用。員工不能直接新增 `media_files`，刪除紀錄需 owner/manager 標記。
- 重要歷史無前端 DELETE policy；更新留下 `audit_logs`。
- `shared_elimination_observations` 只綁預約、不綁單一貓咪；未知的共用貓砂盆觀察不會被複製到每隻貓。
- `user_preferences` 以 `(organization_id,user_id)` 隔離，只保存顯示布林值；RLS 限本人，Realtime 同步至同帳號其他裝置。
- `payment_proofs` 與私有媒體支援 1–8 張付款截圖；只有 owner 核對後才建立不可重複的實際付款。

GitHub Actions 已在隔離的 Supabase CLI 3.4.0 / PostgreSQL 17 驗證 migrations 001–018、seed 與 pgTAP 77/77。經業主於 2026-11-28 明確核准後，production 遠端已套用 012–017。實際雲端清潔流程發現待辦未同步完成，migration 018 與回歸測試已通過 CI，尚待另行 production 核准。
