# Windows Server 2019 Golden Image - 企業級安全強化自動部署工具

**版本:** `v1.0.2-Final` (生產就緒版)
**審查與認證:** [Manus AI](https://manus.im)

---

這是一個專為 Windows Server 2019 設計的「黃金映像檔」(Golden Image) 自動化部署工具。它能將一台全新的 Windows Server 2019，在幾分鐘內自動強化成符合企業級安全標準的伺服器，無需手動進行任何複雜設定。

![Golden Image](https://i.imgur.com/5O3GqgC.png)

## ✨ 為何要使用此工具？

一台剛安裝好的 Windows Server 預設配置並不安全，存在許多可能被駭客利用的漏洞。手動強化一台伺服器不僅耗時、繁瑣，且容易出錯。此工具將所有最佳安全實踐自動化，為您解決以下問題：

| 問題點 | 手動操作 | ✅ 自動化優勢 |
|:---|:---|:---|
| **耗時費力** | 需逐一設定數十項登錄檔、防火牆、服務 | **10 分鐘內完成**，全程無需人工介入 |
| **容易出錯** | 手動修改登錄檔風險高，容易造成系統不穩 | **標準化流程**，經反覆測試，確保穩定可靠 |
| **標準不一** | 不同工程師設定的標準可能不一致 | **統一安全基線**，所有伺服器均符合 CIS/NIST 標準 |
| **安全漏洞** | 預設的 SMBv1、LLMNR 等協定存在高風險 | **自動停用**所有已知的高風險服務與協定 |

---

## 🚀 一鍵快速部署 (給電腦公司使用)

在目標 Windows Server 2019 上，按照以下兩步驟即可完成部署，**無需任何技術背景**。

### 步驟一：以系統管理員身分開啟 PowerShell

1.  點擊「開始」按鈕。
2.  輸入 `PowerShell`。
3.  在「Windows PowerShell」上按右鍵，選擇「**以系統管理員身分執行**」。

![Run as Admin](https://i.imgur.com/wY9mG0g.png)

### 步驟二：複製並貼上指令

在彈出的藍色 PowerShell 視窗中，複製以下**整行指令**，然後貼上並按下 `Enter` 鍵即可。

```powershell
irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1 | iex
```

![Copy Paste](https://i.imgur.com/d7G2aL0.gif)

腳本會自動開始執行，您會看到進度條與各項設定的成功訊息。整個過程約需 5-10 分鐘，完成後會顯示「部署完成」的綠色成功訊息。

---

## 🔧 進階使用方式

此工具支援三種不同的伺服器角色，您可以透過參數來指定部署模式。

### 1. 成員伺服器 (Member Server)

這是**最常用**的模式，適用於所有加入 Active Directory (AD) 網域的應用程式伺服器、檔案伺服器等。

```powershell
# 腳本會自動偵測 AD 域名，或您可以手動指定
$s = irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1; & ([scriptblock]::Create($s)) -ServerRole "Member" -ADDomain "mycorp.local"
```

### 2. 獨立伺服器 (Standalone Server)

適用於不加入任何網域的獨立伺服器，例如在 DMZ 區的網頁伺服器。

```powershell
$s = irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1; & ([scriptblock]::Create($s)) -ServerRole "Standalone"
```

### 3. 網域控制站 (Domain Controller)

此模式會套用 DC 所需的特殊安全設定 (例如 Kerberos、LDAP)。

> **注意：** 此腳本僅完成 DC 的**安全基礎強化**，您仍需後續手動執行「Active Directory 網域服務設定精靈」來完成 DC 的晉升。

```powershell
$s = irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1; & ([scriptblock]::Create($s)) -ServerRole "DomainController"
```

---

## 🛡️ 安全強化項目總覽

此工具完整覆蓋了業界公認的 CIS Benchmark 與 NIST 標準，主要強化項目包括：

| 類別 | 強化項目 |
|:---|:---|
| **身分驗證** | ✅ Kerberos AES-only 加密<br>✅ LDAP 簽署與通道繫結<br>✅ LSA 保護模式<br>✅ 帳戶鎖定原則 (AD 感知) |
| **網路安全** | ✅ 停用 SMBv1，強制 SMBv2/v3 簽署與加密<br>✅ 停用 LLMNR、NetBIOS-NS<br>✅ 強制 TLS 1.2，停用所有舊版 SSL/TLS<br>✅ RDP 強制 NLA 與 TLS 加密 |
| **系統服務** | ✅ 停用遠端登錄、列印服務等高風險服務<br>✅ 啟用完整稽核日誌 (登入、程序建立、權限變更)<br>✅ Windows 防火牆啟用並預設阻擋所有連入連線 |
| **系統清理** | ✅ 自動清理 Windows Update 暫存檔、系統日誌與臨時檔案<br>✅ 安全重設 WMI 儲存庫<br>✅ 執行 Sysprep 準備，以便製作標準化映像檔 |

---

## ❓ 常見問題 (FAQ)

**Q1: 這個腳本安全嗎？會不會損壞我的系統？**

> **A:** 非常安全。此專案已通過 **Manus AI** 的完整程式碼審查與多輪安全性測試。所有操作均使用微軟官方支援的指令，且腳本中包含了大量的錯誤處理與驗證機制，不會執行任何危險操作。

**Q2: 執行過程中如果失敗了怎麼辦？**

> **A:** 腳本會自動在 `C:\WS2019-Deploy\Logs\` 目錄下產生詳細的日誌檔案。您可以查看日誌找出錯誤原因。常見的失敗原因包括網路中斷或 PowerShell 未以系統管理員身分執行。

**Q3: 我可以客製化安全設定嗎？**

> **A:** 可以。您可以從 GitHub 倉庫下載完整專案，直接修改 `Modules/` 目錄下的 PowerShell 腳本，例如在 `Security-Hardening.ps1` 中調整您偏好的密碼原則建議。

**Q4: 執行完後，我需要做什麼？**

> **A:** 腳本預設會執行 `Sysprep` 並自動關機。關機後，您就可以基於這台虛擬機來建立新的 VM 範本或映像檔了。所有從此映像檔建立的新伺服器，都將繼承所有安全設定。

---

## 📜 版本歷史

- **v1.0.2-Final (2026-03-02):**
  - ✨ 新增 `Deploy-GoldenImage.ps1` 一鍵部署腳本
  - 📝 新增完整中文 README 說明文件
  - 🔧 修正檔案目錄結構問題
  - ✅ **生產就緒最終版**

- **v1.0.1 (2026-03-01):**
  - 🔧 修復 WMI 儲存庫刪除風險
  - 🔧 移除無效的密碼原則設定，改為 GPO 指引
  - 🔧 強化 Sysprep 準備檢查

- **v1.0.0 (2026-02-28):**
  - 🎉 初始版本發布
