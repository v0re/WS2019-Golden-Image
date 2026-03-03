# 部署指南

> **版本：** v1.0.3 | **倉庫：** https://github.com/v0re/WS2019-Golden-Image

---

## 一鍵啟動指令（唯一正確版本）

在 Windows Server 2019 上，以**系統管理員身分**開啟 PowerShell，貼上以下指令並按 Enter：

```powershell
irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1 | iex
```

> ⚠️ **注意：** 倉庫名稱為 `WS2019-Golden-Image`，分支為 `master`。請勿使用任何其他版本的舊指令。

---

## 進階使用（指定伺服器角色）

透過環境變數傳遞參數，在執行前設定：

```powershell
# 成員伺服器（加入 AD 網域）
$env:GI_ROLE="Member"; $env:GI_DOMAIN="corp.local"
irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1 | iex

# 獨立伺服器（不加入網域）
$env:GI_ROLE="Standalone"
irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1 | iex

# 網域控制站
$env:GI_ROLE="DomainController"; $env:GI_DOMAIN="corp.local"
irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1 | iex

# 跳過 Sysprep（測試用）
$env:GI_SKIP_SYSPREP="1"
irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1 | iex
```

| 環境變數 | 說明 | 預設值 |
|:---|:---|:---|
| `$env:GI_ROLE` | 伺服器角色（`Member` / `DomainController` / `Standalone`） | `Member` |
| `$env:GI_DOMAIN` | AD 域名 | `domain.local` |
| `$env:GI_SKIP_SYSPREP` | 設為 `1` 則跳過 Sysprep | 不跳過 |
| `$env:GI_PATH` | 安裝路徑 | `C:\WS2019-Deploy` |

---

## 部署流程說明

執行一鍵指令後，腳本自動完成以下步驟：

| 步驟 | 說明 | 約耗時 |
|:---:|:---|:---:|
| 1/4 | 從 GitHub 下載最新版本 ZIP | 1 分鐘 |
| 2/4 | 解壓縮至 `C:\WS2019-Deploy\` | < 1 分鐘 |
| 3/4 | 驗證所有必要檔案完整性 | < 1 分鐘 |
| 4/4 | 執行完整安全強化部署 | 5-10 分鐘 |

**總耗時：約 10-15 分鐘**

---

## 部署後驗證

```powershell
# 查看部署日誌
Get-ChildItem "C:\WS2019-Deploy\Logs\" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50

# 驗證 TLS 1.2 已啟用
(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -Name "Enabled").Enabled
# 應顯示：1

# 驗證防火牆已啟用
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction
# 應顯示：Enabled=True, DefaultInboundAction=Block
```

---

## 映像封裝（Hyper-V）

部署完成後，腳本會自動執行 Sysprep 並關機。關機後在 Hyper-V 主機上執行：

```powershell
# 複製 VHDX 作為黃金映像
$source = "C:\Hyper-V\VMs\GoldenImageVM\Virtual Hard Disks\disk.vhdx"
$target = "C:\Images\WS2019-Golden-v1.0.vhdx"
Copy-Item -Path $source -Destination $target

# 以差異磁碟快速建立新 VM
New-VHD -Path "C:\VMs\NewVM\disk.vhdx" -ParentPath $target -Differencing
New-VM -Name "NewVM" -MemoryStartupBytes 4GB -VHDPath "C:\VMs\NewVM\disk.vhdx"
```

---

## 常見問題

**Q：執行後沒有反應或立即結束？**
> 確認以**系統管理員身分**執行 PowerShell（右鍵 → 以系統管理員身分執行）。

**Q：下載失敗（網路錯誤）？**
> 確認伺服器可連線至 `github.com` 與 `raw.githubusercontent.com`。

**Q：Sysprep 失敗？**
> 查看日誌：`Get-Content "C:\Windows\System32\Sysprep\Panther\setuperr.log" -Tail 100`

**Q：如何手動跳過 Sysprep？**
> 執行前設定 `$env:GI_SKIP_SYSPREP="1"`，完成後手動執行：
> `C:\Windows\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown /quiet`

---

**倉庫地址：** https://github.com/v0re/WS2019-Golden-Image
