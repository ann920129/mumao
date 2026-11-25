# 資料庫設計

六個 migration 依序建立 foundation、operations、security/RPC、營運 workflows、入住流程與退房/狀態 guard。所有業務主鍵為 UUID，敏感表啟用 RLS，跨資料表關係以 `(organization_id, id)` 複合外鍵驗證租戶一致。

核心原則：

- 預約與房間由 `room_allocations` 的 GiST exclusion constraint 防止 `[入住,退房)` 重疊，支援同日退房→清潔→入住。
- `price_snapshots` 永久保存伺服器驗證結果；`create_reservation` 不信任前端總額。
- 每次住宿的照護指示存於 `reservation_cats.care_snapshot`，不會被永久貓咪資料覆寫。
- 共用物品使用 `shared_group_id`；庫存移動有 idempotency key 且 row lock 防止重扣，未知數量不轉成 0。
- 用藥以唯一排程、row lock、version 與 claim/finish 兩階段避免重複。失敗或不確定會建立高優先追蹤工作。
- 通知唯一鍵為旅館/預約/類型/日期；複製訊息只是 `message_copied`，不等於已送出。
- `stay_workflows` 保存入住/退房草稿；完成入住 RPC 會驗證逐項人工確認、鎖定預約、更新房態並建立照護日期。
- 完成退房前，所有需歸還物品必須有非 pending 核對；未付尾款需留下主管例外理由。退房交易把房間改為待清潔並建立 cleaning task。
- reservation guard 禁止 manager 修改價格/付款欄位，且入住/退房狀態必須有已完成工作流；待清潔房間不能入住。
- 重要歷史無前端 DELETE policy；更新留下 `audit_logs`。

實際套用前先在非正式專案執行 `supabase db reset` 與整合測試。本專案目前只有準備好的 migration，尚未對任何雲端資料庫執行。
