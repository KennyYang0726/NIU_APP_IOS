<img style="width:64px" src="https://user-images.githubusercontent.com/13403218/228755470-34ae31ec-eb1a-4c1c-9461-bdbaa04d9fef.png" />

# NIU App (iOS)
> SwiftUI project — Application for National Ilan University

---
## ☕ 贊助支持
此專案為 **開源且免費使用**，歡迎自由下載與使用。

由於 iOS 版本需每年支付 Apple Developer Program 年費（USD $99），  
才能持續在 App Store 上提供下載與更新。

如果你覺得這個專案對你有幫助，並且有餘力的話，  
下方提供 自願性支持方式，分擔專案的上架成本。

你的每一份支持，都是我持續維護與改進的動力。

### ⭐ 支持方式
 - 於右上角 Star 此專案
 - 使用 [**街口支付**](https://service.jkopay.com/r/transfer?j=Transfer:909029869) 小額贊助支持
<p>
  <a href="https://service.jkopay.com/r/transfer?j=Transfer:909029869">
    <img src="https://github.com/JamesYang0826/NIU_APP_Assets/releases/download/NIU_APP_Assets/QRCode_JKoPay.png" width="130" />
  </a>
  <!--
  <a href="https://p.ecpay.com.tw/1A38519">
    <img src="https://github.com/JamesYang0826/NIU_APP_Assets/releases/download/NIU_APP_Assets/QRCode_ECPay.png" width="130" />
  </a>
   或是 [**綠界**](https://p.ecpay.com.tw/1A38519) -->
</p>

---

這是一個給宜大學生使用的 iOS app，整合了大部分常使用到的功能，包含數位學習 M 園區、分數查詢、課表、活動報名、畢業門檻查詢、選課、請假，並提供公車動態查詢與 Zuvio。


## 目錄
- [App Store 連結](#app-store-連結)
- [更新日誌詳情](#更新日誌) 
- [安裝](#安裝)
  - [Xcode](#xcode)
  - [iOS IPA](#ios-ipa)
- [使用方式](#使用方式)
- [功能](#功能)


## App Store 連結
可以在 [App Store](https://apps.apple.com/tw/app/niu-%E5%AE%9C%E5%A4%A7%E5%AD%B8%E7%94%9Fapp/id6756336266) 下載最新版本的 app。


## 更新日誌
所有歷史版本更新日誌可以在 [GitHub 專案](https://github.com/JamesYang0826/NIU_APP_Assets) 查看。  
iOS 版本於 verCode21 正式發佈
> ⚠️ 請注意，最低要求 iOS 版本為 16.0


## 安裝
### Xcode
1. 安裝 [Xcode](https://developer.apple.com/xcode/) （建議版本：26.0.1 以上）
2. 使用以下指令將專案 clone 至本地端：
   ```bash
   git clone https://github.com/KennyYang0726/NIU_APP_IOS.git
   ```
3. 進入專案資料夾後，開啟 `com.niu.csie.edu.app.xcodeproj`
4. **Xcode 會自動根據 `Package.resolved` 下載並安裝所有依賴項目。**


### iOS IPA
- [Release 下載連結](https://github.com/KennyYang0726/NIU_APP_IOS/releases/tag/iOS)  
  可直接下載測試用 IPA 並使用 Sideloadly 或其他工具將其側載進入您的設備。


## 使用方式
1. 安裝並開啟應用程式  
2. 使用宜蘭大學帳號密碼登入  
3. 進入主畫面後即可瀏覽各項校園功能  

> ⚠️ 僅限擁有宜蘭大學帳號的學生登入。


## 功能
| 功能列表 | 功能概述 |
| -------- | -------- |
| **M園區** | 觀看上課教材、繳交作業 |
| **成績查詢** | 查詢期中、學期成績 |
| **我的課表** | 顯示上課地點、時間、授課老師 |
| **活動報名** | 報名宜大校園活動 |
| **聯絡我們** | 回報錯誤、提供建議 |
| **畢業門檻** | 查詢畢業所需條件 |
| **選課系統** | 開啟校內選課頁面 |
| **公車查詢** | 即時查詢公車動態 |
| **Zuvio** | 保留作業與簽到等常用功能 |
| **請假系統** | 進入校務行政請假頁面 |
| **校園公告** | 查看最新公告 |
| **學校行事曆** | 查看校內行事曆 |
| **成就系統** | 蒐集成就圖鑑 |
| **使用說明** | 使用指南與教學 |


<table>
  <tr>
    <th colspan="3">使用範例</th>
  </tr>
  <tr>
    <td colspan="3" align="center">
      <img src="https://github.com/JamesYang0826/NIU_APP_Assets/releases/download/NIU_APP_Assets/01_ios.gif" style="max-width: 100%; height: auto;">
    </td>
  </tr>
  <tr>
    <th>登入頁面</th>
    <th>公告系統</th>
    <th>行事曆表</th>
  </tr>
  <tr>
    <td colspan="3" align="center">
      <img src="https://github.com/JamesYang0826/NIU_APP_Assets/releases/download/NIU_APP_Assets/02_ios.gif" style="max-width: 100%; height: auto;">
    </td>
  </tr>
  <tr>
    <th>M園區</th>
    <th>成績查詢</th>
    <th>活動報名</th>
  </tr>
  <tr>
    <td colspan="3" align="center">
      <img src="https://github.com/JamesYang0826/NIU_APP_Assets/releases/download/NIU_APP_Assets/03_ios.gif" style="max-width: 100%; height: auto;">
    </td>
  </tr>
  <tr>
    <th>公車動態</th>
    <th>Zuvio</th>
    <th>成就系統</th>
  </tr>
</table>


## 問題
1. ios 16.X, 17.X, 18.X 亮色模式下，觸發 NavigationStack 返回會使得標題字顏色變黑色  
發生於 Drawer -> 問卷調查 & 說明 第二頁的返回  
( 26已修復此問題，並且這似乎是官方Bug )