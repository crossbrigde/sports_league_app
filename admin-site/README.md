# 體育聯盟管理系統 - 開發指南

## Firebase OAuth 授權域名設置

當您在本地開發環境（localhost 或 127.0.0.1）運行此應用程序時，如果遇到以下錯誤：

```
FirebaseError: Firebase: This domain is not authorized for OAuth operations for your Firebase project. Edit the list of authorized domains from the Firebase console. (auth/unauthorized-domain).
```

這表示您需要在 Firebase 控制台中添加您的開發域名到授權域名列表中。請按照以下步驟操作：

### 添加授權域名的步驟

1. 登入 [Firebase 控制台](https://console.firebase.google.com/)
2. 選擇您的專案 `sports-league-app-d25e2`
3. 在左側導航欄中，點擊 **Authentication**
4. 點擊頂部的 **Settings** 標籤
5. 滾動到 **Authorized domains** 部分
6. 點擊 **Add domain** 按鈕
7. 添加 `localhost` 和 `127.0.0.1` 作為授權域名
8. 點擊 **Add** 保存更改

### 部署注意事項

當您將應用程序部署到生產環境時，請確保將您的生產域名也添加到 Firebase 授權域名列表中。例如，如果您使用 Firebase Hosting 部署，您需要添加以下域名：

- `kali-admin-panel.web.app`
- `kali-admin-panel.firebaseapp.com`

## 本地開發

我們已經更新了 Google 登入功能，以便在本地開發環境中使用 `signInWithRedirect` 方法，這樣可以避免某些與彈窗相關的問題。在生產環境中，系統將使用 `signInWithPopup` 方法。

## 故障排除

如果您在設置授權域名後仍然遇到問題，請嘗試以下步驟：

1. 清除瀏覽器緩存和 cookies
2. 使用無痕/隱私模式瀏覽器窗口測試
3. 確保您的 Firebase 配置中的 `authDomain` 設置正確
4. 檢查 Firebase 專案的 API 密鑰是否啟用了必要的 Google 服務

如有任何問題，請參考 [Firebase Authentication 文檔](https://firebase.google.com/docs/auth)。
firebase deploy --only hosting:kali-admin-panel