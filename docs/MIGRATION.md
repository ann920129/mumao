# 舊版資料移轉

原始 `index.html` 未使用 localStorage，因此目前 repository 沒有可移轉資料。為防實際使用者瀏覽器曾有其他版本，工具只掃描已知 key，流程如下：

1. 「我的 → 檢查舊版資料」查看來源與 JSON 格式錯誤。
2. 先下載完整 JSON 備份；此動作不修改或刪除來源。
3. 正式匯入器必須預覽 owner/cat/reservation 對應、缺值與價格快照。
4. 每份 bundle 計算 fingerprint，`legacy_imports` 唯一鍵避免重複。
5. 每批匯入以 transaction 驗證 organization 與 FK；輸出成功/失敗筆數與錯誤報告。
6. 抽查總筆數、金額、跨月預約與照護歷史後才標記 completed。
7. 舊資料仍保留；只有業主另行確認且備份可還原後才可手動清除。

目前 `IMPLEMENTED`：探索、JSON 驗證、原始備份、fingerprint 與資料庫批次追蹤表。`NOT STARTED`：實際欄位 mapping/import UI；不可把這部分視為已完成匯入。
