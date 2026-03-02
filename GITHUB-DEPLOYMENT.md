# GitHub 部署指南 - 一鍵啟動

## 第一步：上傳倉庫到 GitHub

### 使用您的 GitHub Token 上傳

在本機執行以下命令（Linux/Mac/Windows Git Bash）：

```bash
# 建立倉庫目錄
mkdir Windows-Server-2019-Golden-Image
cd Windows-Server-2019-Golden-Image

# 初始化 Git
git init

# 複製所有檔案到此目錄
# （確保 setup.ps1、Modules/、Scripts/ 等都已複製）

# 新增所有檔案
git add .

# 提交
git commit -m "Initial commit: Windows Server 2019 Enterprise Golden Image"

# 新增遠端倉庫
git remote add origin https://github.com/v0re/Windows-Server-2019-Golden-Image.git

# 推送到 GitHub（使用您的 Token）
git push -u origin main
```

### 在 GitHub 上建立倉庫（如未建立）

1. 登入 GitHub：https://github.com
2. 點擊 **+** → **New repository**
3. 倉庫名稱：`Windows-Server-2019-Golden-Image`
4. 說明：`Enterprise-grade automated golden image deployment with CIS Benchmark compliance`
5. 選擇 **Public**
6. **Create repository**

---

## 第二步：一鍵啟動命令

### 給公司的完整一鍵啟動命令

將以下命令分享給公司同事，他們只需在 **Windows Server 2019** 上以 **管理員身分** 運行：

```powershell
powershell -Command "IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/v0re/Windows-Server-2019-Golden-Image/main/setup.ps1')"
```

### 等效的本機執行方式

如果直接下載倉庫：

```powershell
# 下載倉庫
git clone https://github.com/v0re/Windows-Server-2019-Golden-Image.git
cd Windows-Server-2019-Golden-Image

# 執行部署
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
.\setup.ps1 -ADDomain "your-domain.local"
```

---

## 第三步：部署流程詳解

### 執行一鍵命令後會發生什麼？

1. **自動下載所有模組** 從 GitHub
2. **執行安全強化** (Security-Hardening.ps1)
   - Kerberos 配置
   - LDAP 簽署
   - 密碼原則
   - LSA 保護
   - ⏱️ 約 2 分鐘

3. **執行網路安全** (Network-Hardening.ps1)
   - 防火牆全配置
   - SMB 強化
   - TLS 1.2 強制
   - RDP 安全化
   - ⏱️ 約 3 分鐘

4. **執行映像完成** (Image-Finalization.ps1)
   - CIS 合規驗證
   - 系統清理
   - Sysprep 準備
   - ⏱️ 約 5 分鐘

5. **自動執行 Sysprep**
   - 系統關閉
   - 映像準備完成

**總耗時：約 10-15 分鐘**

---

## 第四步：映像轉換（Hyper-V）

部署完成後，將 VM 轉換為可復用的 VHDX 映像：

```powershell
# 在 Hyper-V 主機上執行

# 1. 確認 VM 已關閉
Stop-VM -Name "YourGoldenImageVM" -Force

# 2. 轉換為映像
$sourceVHDX = "C:\Hyper-V\VMs\YourGoldenImageVM\Virtual Hard Disks\disk.vhdx"
$targetImage = "C:\Images\WS2019-GoldenImage-v1.0.vhdx"

Copy-Item -Path $sourceVHDX -Destination $targetImage

# 3. 建立差異磁碟（快速部署用）
New-VHD -Path "C:\VMs\VM-Instance-1\disk.vhdx" -ParentPath $targetImage -Differencing

# 4. 使用映像建立 VM
New-VM -Name "VM-Instance-1" -MemoryStartupBytes 4GB -VHDPath "C:\VMs\VM-Instance-1\disk.vhdx"
```

---

## 第五步：驗證部署

### 檢查日誌

部署完成後，檢查日誌確認所有配置成功：

```powershell
# 檢查日誌目錄
Get-ChildItem -Path "C:\Windows\Temp\GoldenImage\Logs" | Sort-Object CreationTime -Descending

# 查看最新日誌
Get-Content "C:\Windows\Temp\GoldenImage\Logs\deployment-*.log" -Tail 50
```

### 手動驗證安全配置

```powershell
# 驗證 Kerberos
(Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\KDC" -Name "KdcSupportedEncryptionTypes").KdcSupportedEncryptionTypes
# 應顯示：24（代表 AES128 + AES256）

# 驗證防火牆
Get-NetFirewallProfile -Profile Domain | Select-Object Enabled, DefaultInboundAction
# 應顯示：Enabled=True, DefaultInboundAction=Block

# 驗證 TLS 1.2
(Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -Name "Enabled").Enabled
# 應顯示：1
```

---

## 常見問題

### Q：執行一鍵命令後沒有反應？
A: 確認：
1. 以 **管理員身分** 執行 PowerShell
2. 網路已連線
3. PowerShell 版本 >= 5.1：`$PSVersionTable.PSVersion`

### Q：防火牆阻止網路連線？
A: 這是正常的（預設拒絕所有入站）。需要手動新增規則：

```powershell
# 允許特定子網的 RDP
New-NetFirewallRule -DisplayName "RDP-Admin" -Direction Inbound -Protocol TCP -LocalPort 3389 -RemoteAddress 10.0.5.0/24 -Action Allow -Profile Domain
```

### Q：Sysprep 失敗？
A: 檢查 Sysprep 日誌：
```powershell
Get-Content "C:\Windows\System32\Sysprep\Panther\setuperr.log" -Tail 100
```

### Q：如何跳過 Sysprep 手動執行？
A: 使用 `-SkipSysprep` 參數：
```powershell
.\setup.ps1 -SkipSysprep
```

然後手動執行 Sysprep：
```powershell
C:\Windows\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown /quiet
```

---

## GitHub 倉庫設定（推薦）

上傳完成後，在 GitHub 倉庫設定頁面：

1. **Settings** → **General**
   - ✓ 勾選 "Require a pull request before merging"
   - ✓ 勾選 "Automatically delete head branches"

2. **Settings** → **Branches**
   - 設定 `main` 為預設分支

3. **Settings** → **About**
   - 主題：`windows`, `security`, `golden-image`, `powershell`, `cis-benchmark`

4. **Releases**
   - 建立 Release `v1.0.0`
   - 描述：企業級 Windows Server 2019 安全映像

---

## 最終一鍵啟動命令

**複製此命令並分享給公司同事：**

```powershell
# 在 Windows Server 2019 上以管理員身分執行：
powershell -Command "IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/v0re/Windows-Server-2019-Golden-Image/main/setup.ps1')"
```

---

**完成！您的企業級自動化部署系統已準備就緒。**

倉庫地址：https://github.com/v0re/Windows-Server-2019-Golden-Image
