# Supabase 初次設定（新手步驟）

> 目前狀態（2026-11-28）：CLI 已連結 production `agmehbmjdymyjoyesbbl`。經業主明確核准後，migrations 012–017 已成功套用。雲端整合測試新增 migration 018 修正清潔待辦未關閉，尚未套用；需另行取得 production 核准。

1. 開啟 [Supabase Dashboard](https://supabase.com/dashboard)，按 **New project**，選 free plan；區域選離臺灣近且免費方案可用的區域。記下 database password，勿放進 GitHub。
2. 不必全域安裝 CLI；PowerShell 直接執行 `npx --yes supabase@3.4.0 login`。若已登入可略過。
3. Dashboard 專案網址中的 ref 形如 `abcdefghijklmnop`。在本資料夾執行：

   ```powershell
   npx --yes supabase@3.4.0 link --project-ref YOUR_PROJECT_REF
   npx --yes supabase@3.4.0 migration list --remote
   npx --yes supabase@3.4.0 db push --remote --dry-run
   ```

   建議先建立獨立 staging 專案並把 `YOUR_PROJECT_REF` 換成 staging ref。CI 已從零套用 17 份 migration 並通過 76/76 pgTAP。只有確認目標是 staging，或業主另行明確核准 production 後，才執行：

   ```powershell
   npx --yes supabase@3.4.0 db push --remote
   npx --yes supabase@3.4.0 functions deploy invite-staff
   npx --yes supabase@3.4.0 functions deploy manage-staff
   ```

   `db push` 會改動遠端資料庫；production 執行前必須先有可還原備份、維護時段與明確核准。

4. Dashboard → **Project Settings → API**，複製 Project URL 與 **publishable/anon key**。將 `config.example.js` 複製內容到 `config.js` 並只替換這兩值。絕對不要填 service_role。
5. Dashboard → **Authentication → URL Configuration**：Site URL 填「獨立 V2 測試／正式網址」，Redirect URLs 加該網址與本機 `http://localhost:3000/**`。原版 `https://ann920129.github.io/mumao/` 目前仍由 main 提供，不應改指向 V2。
6. **Authentication → Email Templates** 確認 Invite/Reset Password 使用正確 redirect。正式營運建議自訂 SMTP；免費內建寄信有速率限制，不保證大量寄送。
7. SQL migration 會建立 private bucket `private-media`、Storage policies 與 Realtime publication。到 **Storage** 確認 bucket 顯示 Private；不要改成 Public。
8. 開啟應用，第一個帳號先在 Auth 建立/登入，畫面會出現「建立第一間旅館」。輸入名稱與唯一英文 slug；系統建立 owner、六種歷史計價房型/價格、物品分類及暮貓核定 21 房。
9. 到「我的 → 系統設定」按「建立／核對 21 房」，確認爵1–爵7、升1–升7、頭1–頭5、小總、大總共 21 間。東海標準房只保留歷史計價，不加入暮貓實體配置。
10. 部署後由 owner 使用邀請功能呼叫 `invite-staff`，選 manager 或 staff；不要在前端直接寫 organization_members。
11. 使用兩個測試旅館與不同瀏覽器帳號驗證跨租戶拒絕、不同角色、停用帳號、密碼重設。
12. 上傳合成照片，確認 Storage 物件路徑為 `organization/reservation/category/uuid.ext`，未登入與另一旅館都不能讀取。
13. 兩台裝置同時開啟，新增預約/待辦並確認 Realtime 更新；斷網後確認畫面顯示失敗而不是假裝儲存。

Free tier 容量、頻寬、Realtime 連線、寄信與專案暫停政策可能調整，正式使用前以 Dashboard 顯示的當期限制為準。背景排程/推播尚未部署；開啟應用會補產明日站內提醒。

## production migration 完成後的精確下一步

1. migration list、Data API、anon RLS 與登入頁已驗證。
2. 用兩個組織、owner/manager/staff 合成帳號與兩台裝置驗證登入後 Auth、RLS、Realtime、Storage、完整入住退房與用藥競爭。
3. 通過雲端整合測試後再部署 `invite-staff`、`manage-staff` Edge Functions。
4. V2 必須使用獨立網址；不得合併 main 或改動原版 GitHub Pages。
