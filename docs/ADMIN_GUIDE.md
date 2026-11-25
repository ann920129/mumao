# 業主管理指南

- 第一位 owner 登入後建立旅館；建立結果含既有六種房型與價格，但實體房名需依現場新增。
- 邀請 manager/staff 必須透過 `invite-staff` Edge Function；角色調整、停用與復用使用 `manage-staff`。停用後 RLS 立即拒絕既有 session 的資料存取；正式管理 UI 尚待完成。
- owner 才能修改房型/價格與檢視付款/audit。任何價格變更只影響新預約，舊預約看 price snapshot。
- 每月檢查未結案異常、未確認用藥、庫存修正、通知紀錄、付款差異與 audit。
- 匯出檔含個資時使用加密儲存與受控分享，完成目的後刪除；不要上傳 GitHub。
- 備份：免費方案保證範圍依 Supabase 當期政策；重要營運前定期以 CLI/pg_dump 做加密備份並實際演練還原。
- 更換公開 key 後更新 `config.js`；service_role 只存在 Supabase Edge runtime secrets，絕不進前端。
- 上線/遷移/還原與事故處理參考 `SUPABASE_SETUP.md`、`DEPLOYMENT.md`、`SECURITY.md`。
