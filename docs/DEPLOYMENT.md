# V2 獨立部署

## 部署前

1. `npm test` 必須全過。
2. 完成 staging Supabase 整合測試；確認 `config.js` 只有公開 URL/key。
3. `git diff --check`、`git status`，確認沒有 `.env`、service role、照片或真實資料。
4. 推送 feature branch、開 PR；不得直接合併 production。

## 原版保護

`https://ann920129.github.io/mumao/` 目前由 `main` 根目錄的原版計價 Demo 提供。不得把 V2 合併／部署到該來源，也不得改 Pages branch/root；原版部署必須保持不變。

## 建議的獨立 V2 網址

建立獨立 repository（例如 `mumao-v2`）或獨立靜態託管專案，讓 V2 有不同網址。部署內容為本 branch 的靜態檔，但不得包含本機 `config.js`；由部署平台在建置時依 `config.example.js` 產生只含 Project URL 與 publishable key 的 `config.js`。建立 repository、網域或正式站點屬外部變更，需業主另行核准。

PR #1 核准只代表程式碼審查通過，不等於允許合併 main 或修改原版 Pages。production migrations 012–017 已由業主另行明確核准並於 2026-11-28 套用；未來 migration 仍須逐次另行核准。

驗證：登入/登出、manifest、安裝、手機/平板/桌面、Auth redirect、建立預約、跨租戶拒絕、私有照片、兩裝置 Realtime、斷線錯誤、service worker 無敏感 cache。實際成功前不得把網址標成已部署；目前沒有 V2 部署網址。

回復：前端可 revert 合併 commit 後重新部署；資料庫 migration 不可直接破壞性回滾，應新增向前修復 migration。正式資料 migration 必須先備份。
