# 安全與隱私

## 已設計

- Auth session；帳號角色與停用狀態由 `organization_members` 驗證。
- 每個敏感表 RLS；工作人員只能讀所屬 organization，價格主檔只有 owner 可改。
- 邀請員工由 Edge Function 使用 server-side service role；前端不能自升權。
- Storage bucket 為 private，路徑第一段必須是可存取的 organization UUID；前端只取短效 signed URL。
- 房間衝突、用藥、庫存、通知與清潔由交易/鎖定/唯一鍵處理。
- 無 client delete policy；歷史採封存/狀態流轉並寫 audit。
- 所有 UI 的雲端文字先 HTML escape；無 innerHTML 直接插入未清理客戶內容。
- service worker 不快取 config、API、token、signed URL 或客戶資料。

## 上線前必驗

以兩個 organization、owner/manager/staff/customer 合成帳號測試每張表的 SELECT/INSERT/UPDATE/DELETE。檢查停用帳號、token 過期、Storage 越權路徑、signed URL 期限、Edge Function CORS/速率限制。將邀請函式的 `Access-Control-Allow-Origin` 收斂到正式 Pages 網域。

公開 repo 不得放 service-role、JWT、資料庫密碼、真實姓名/電話、處方或照片。若誤提交，先撤銷/輪替密鑰，再清理歷史；只刪檔案不足以保密。

資料刪除應由業主提出、先匯出/確認法規保存需求，再由受保護後端匿名化或排程刪除；不允許前端硬刪歷史。
