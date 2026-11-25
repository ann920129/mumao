# Supabase 初次設定（新手步驟）

> 目前狀態：SQL 與函式已準備，但沒有實際套用至雲端。

1. 開啟 [Supabase Dashboard](https://supabase.com/dashboard)，按 **New project**，選 free plan；區域選離臺灣近且免費方案可用的區域。記下 database password，勿放進 GitHub。
2. 安裝 [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)：`npm install -g supabase`，再執行 `supabase login`。
3. Dashboard 專案網址中的 ref 形如 `abcdefghijklmnop`。在本資料夾執行：

   ```powershell
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   supabase functions deploy invite-staff
   supabase functions deploy manage-staff
   ```

4. Dashboard → **Project Settings → API**，複製 Project URL 與 **publishable/anon key**。將 `config.example.js` 複製內容到 `config.js` 並只替換這兩值。絕對不要填 service_role。
5. Dashboard → **Authentication → URL Configuration**：Site URL 填 `https://ann920129.github.io/mumao/`；Redirect URLs 加同一網址與本機測試網址 `http://localhost:3000/**`。
6. **Authentication → Email Templates** 確認 Invite/Reset Password 使用正確 redirect。正式營運建議自訂 SMTP；免費內建寄信有速率限制，不保證大量寄送。
7. SQL migration 會建立 private bucket `private-media`、Storage policies 與 Realtime publication。到 **Storage** 確認 bucket 顯示 Private；不要改成 Public。
8. 開啟應用，第一個帳號先在 Auth 建立/登入，畫面會出現「建立第一間旅館」。輸入名稱與唯一英文 slug；系統建立 owner、原始房型/價格與物品分類。
9. 在建立實體房間前核對六種房型與所有價目。房號/房名原始專案沒有資料，請依現場名稱新增，不要由系統猜測。
10. 部署後由 owner 使用邀請功能呼叫 `invite-staff`，選 manager 或 staff；不要在前端直接寫 organization_members。
11. 使用兩個測試旅館與不同瀏覽器帳號驗證跨租戶拒絕、不同角色、停用帳號、密碼重設。
12. 上傳合成照片，確認 Storage 物件路徑為 `organization/reservation/category/uuid.ext`，未登入與另一旅館都不能讀取。
13. 兩台裝置同時開啟，新增預約/待辦並確認 Realtime 更新；斷網後確認畫面顯示失敗而不是假裝儲存。

Free tier 容量、頻寬、Realtime 連線、寄信與專案暫停政策可能調整，正式使用前以 Dashboard 顯示的當期限制為準。背景排程/推播尚未部署；開啟應用會補產明日站內提醒。
