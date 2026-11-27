# 原版訂房計價 Demo 保護基準

記錄日期：2026-11-28（Asia/Taipei）

## Git 基準

- Repository：`ann920129/mumao`
- 預設分支：`main`
- `origin/main`：`70226ecd16f650f3fa6691fb306316fe7104ceb5`
- 歷史參考 SHA：`70226ecd16f650f3fa6691fb306316fe7104ceb5`（相符）
- `backup/pre-care-management-v2`：`70226ecd16f650f3fa6691fb306316fe7104ceb5`
- V2 開發分支：`feature/care-management-v2`

## 原版檔案雜湊

原版 main 僅包含 `index.html`：

- Git blob SHA-1：`3f42a50ae45da4e28a252f0e08603daf66836373`
- SHA-256：`21f23ad100a38e048596971c98a000d3db3b40e3a7a960fea1a4725e49893d94`

備份分支的 `index.html` 與 `origin/main` 無差異。

## GitHub Pages 基準

- URL：<https://ann920129.github.io/mumao/>
- 狀態：`built`
- Build type：`legacy`
- Source：`main` / `/`
- Custom domain：無
- HTTPS enforced：是

V2 不得修改上述設定，且必須使用獨立 URL。

## 提交前後檢查

1. `git branch --show-current` 必須為 `feature/care-management-v2`。
2. `git status --short` 不得意外包含本機 `config.js` 或任何密鑰、個資、處方、照片。
3. 重新核對 `origin/main`、備份 SHA、原版 blob hash 與 Pages source。
4. 執行原版對 V2 計價 parity 測試。
5. 只推送開發分支；不合併 main、不改 Pages。
