# 資料庫設計

十一個 migration 依序建立 foundation、operations、security/RPC、營運 workflows、入住、退房 guard、班別/通知、用藥安全、飼主日報、庫存追蹤，以及私密照片工作流。所有業務主鍵為 UUID，敏感表啟用 RLS，跨資料表關係以 `(organization_id, id)` 複合外鍵驗證租戶一致。

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

GitHub Actions 已在隔離的本地 Supabase CLI 3.4.0 / PostgreSQL 17 執行 `supabase db start`、`supabase db reset --local` 與 schema lint；11 個 migrations、seed 與 RLS pgTAP 均可從零套用。尚未對任何遠端或正式雲端資料庫執行。
