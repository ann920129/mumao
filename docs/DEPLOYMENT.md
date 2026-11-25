# GitHub Pages 部署

## 部署前

1. `npm test` 必須全過。
2. 完成非正式 Supabase 專案整合測試；確認 `config.js` 只有公開 URL/key。
3. `git diff --check`、`git status`，確認沒有 `.env`、service role、照片或真實資料。
4. 推送 feature branch、開 PR；不得直接合併 production。

## Pages

PR 核准並明確同意上線後，合併至 `main`。GitHub repository → **Settings → Pages → Build and deployment → Deploy from a branch**，選 `main`、`/(root)`、**Save**。等待 Actions/Pages 顯示成功後開啟 `https://ann920129.github.io/mumao/`。

驗證：登入/登出、manifest、安裝、手機/平板/桌面、Auth redirect、建立預約、跨租戶拒絕、私有照片、兩裝置 Realtime、斷線錯誤、service worker 無敏感 cache。實際成功前不得把網址標成已部署。

回復：前端可 revert 合併 commit 後重新部署；資料庫 migration 不可直接破壞性回滾，應新增向前修復 migration。正式資料 migration 必須先備份。
