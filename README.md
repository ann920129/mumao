# 暮貓旅宿電子照護管理系統 V2

從原始單頁計價器延伸的多使用者 PWA。保留原計價規則，新增 Supabase Auth、PostgreSQL/RLS、多旅館隔離、Realtime、私有照片、預約、照護、物品、用藥、異常、交接、通知與清潔資料模型。

## 本機查看

需求：Node.js 20+、任一靜態 HTTP server。

```powershell
npm test
npx serve .
```

未設定 Supabase 時會進入「合成資料唯讀預覽」，不會把業務資料存到 localStorage。正式設定依 [Supabase 設定](docs/SUPABASE_SETUP.md) 操作。

目前 production 標記 Supabase 遠端只有 migrations 001–011；V2 的 012–016 尚未部署。原版 GitHub Pages 仍由 `main` 提供，V2 尚無獨立部署網址。

## 專案結構

- `app/domain/`：既有計價與臺北日期純函式。
- `app/services/`：雲端資料、媒體與舊版資料備份。
- `supabase/migrations/`：可執行 schema、RLS、RPC、Storage 與 Realtime。
- `supabase/functions/`：需要後端權限的人員邀請。
- `tests/`：Node 內建測試，不需第三方測試套件。
- `docs/`：架構、資料庫、安全、部署與操作文件。

目前實作/測試/部署狀態請看 [TASKS.md](TASKS.md) 與 [測試報告](docs/TEST_REPORT.md)。
