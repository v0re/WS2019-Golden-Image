# Windows Server 2019 Golden Image - 企業級自動化部署

🔐 **企業級安全強化 | CIS Benchmark 合規 | 一鍵自動化部署**

---

## 📋 快速開始

### ⚡ 一鍵啟動命令

在 **Windows Server 2019** 上以 **管理員身分** 執行以下命令：

```powershell
powershell -Command "IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/v0re/Windows-Server-2019-Golden-Image/main/setup.ps1')"
```

**或**（如已下載倉庫）：

```powershell
cd C:\Path\To\Windows-Server-2019-Golden-Image
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
.\setup.ps1 -ADDomain "your-domain.local"
```

---

## 🛡️ 安全配置概覽

| 配置項目 | 狀態 | 說明 |
|----------|------|------|
| **Kerberos** | ✓ AES-only | 停用 RC4 與弱加密 |
| **LDAP 簽署** | ✓ 強制 | 防止中間人攻擊 |
| **密碼原則** | ✓ NIST Rev 4 | 14 字元 + 複雜性檢查 |
| **防火牆** | ✓ 全啟用 | 預設拒絕入站流量 |
| **SMBv1** | ✓ 停用 | 消除 EternalBlue 風險 |
| **SMB 簽署/加密** | ✓ 強制 | SMBv2/v3 保護 |
| **TLS 1.2** | ✓ 強制 | 停用 SSL/TLS 1.0/1.1 |
| **RDP NLA** | ✓ 啟用 | 需要網路級驗證 |
| **LSA 保護** | ✓ 啟用 | 虛擬化安全隔離 |
| **稽核日誌** | ✓ 完整 | 審計所有安全事件 |
| **BitLocker** | ✗ 不需要 | 不包含加密（按需求） |

---

## 📦 部署流程

```
1. 執行 setup.ps1
   ↓
2. 安全強化模組 (Security-Hardening.ps1)
   - Kerberos 配置
   - 密碼原則設置
   - LDAP 簽署啟用
   ↓
3. 網路安全模組 (Network-Hardening.ps1)
   - 防火牆全配置
   - SMB 強化
   - TLS 1.2 強制
   ↓
4. 映像完成模組 (Image-Finalization.ps1)
   - 系統清理
   - CIS 合規檢查
   - Sysprep 準備
   ↓
5. 系統關閉
   ↓
6. 轉換為 VHDX/Azure 映像
```

---

## 🔧 前置需求

- ✅ Windows Server 2019（Standard 或 Datacenter）
- ✅ 管理員權限
- ✅ PowerShell 5.1+
- ✅ 網路連線（下載倉庫）
- ✅ 至少 50GB 可用磁碟空間

---

## 📁 倉庫結構

```
Windows-Server-2019-Golden-Image/
├── setup.ps1                      # 一鍵啟動主指令碼
├── Unattend.xml                   # 無人安裝應答檔
├── README.md                       # 本檔案
├── SECURITY-BASELINE.md            # 安全配置說明
├── DEPLOYMENT-GUIDE.md             # 詳細部署指南
│
├── Modules/
│   ├── Security-Hardening.ps1     # 安全強化模組
│   ├── Network-Hardening.ps1      # 網路安全模組
│   └── Image-Finalization.ps1     # 映像完成模組
│
├── Hyper-V/
│   ├── Create-GoldenImage-VM.ps1  # VM 建立腳本
│   └── Convert-To-Image.ps1       # 映像轉換
│
├── Scripts/
│   └── Prepare-Sysprep.ps1        # Sysprep 準備
│
├── Validation/
│   ├── CIS-Compliance-Check.ps1   # CIS 檢查
│   └── Security-Verification.ps1  # 安全驗證
│
└── Logs/                           # 自動生成日誌
```

---

## 🚀 進階用法

### 自訂伺服器角色與 AD 域名

```powershell
# 成員伺服器（預設）
.\setup.ps1 -ServerRole "Member" -ADDomain "mycompany.local"

# 網域控制站
.\setup.ps1 -ServerRole "DomainController" -ADDomain "mycompany.local"

# 獨立伺服器（不加入 AD）
.\setup.ps1 -ServerRole "Standalone"
```

### 自訂日誌路徑

```powershell
.\setup.ps1 -LogPath "C:\CustomLogs"
```

### 跳過 Sysprep

```powershell
.\setup.ps1 -SkipSysprep
```

### 驗證安全態勢

```powershell
.\Validation\CIS-Compliance-Check.ps1
```

---

## 📊 CIS Benchmark 合規性

本部署套件遵循 **CIS Microsoft Windows Server 2019 Benchmark** 的核心建議：

- ✓ Level 1（基礎安全要求）
- ✓ Level 2（進階安全強化，某些項目）
- ✓ NIST SP 800-63B Rev 4（密碼政策）
- ✓ NIST SP 800-52r2（TLS 配置）

**驗證報告** 位於 `Logs/` 目錄。

---

## ⚠️ 注意事項

1. **備份**：部署前請備份重要資料
2. **測試**：建議先在測試環境執行
3. **網路變更**：靜態 IP 配置需手動設置（DHCP 被禁用）
4. **Sysprep**：執行 Sysprep 後系統將關閉，無法回滾
5. **日誌**：所有操作日誌保存在 `Logs/` 目錄供審核

---

## 🆘 常見問題

### Q: 執行報錯 "拒絕存取"？
A: 確認以 **管理員身分** 執行 PowerShell。

### Q: 防火牆阻止 RDP？
A: 手動新增規則：
```powershell
New-NetFirewallRule -DisplayName "RDP-Admin" -Direction Inbound -Protocol TCP -LocalPort 3389 -RemoteAddress 10.0.5.0/24 -Action Allow
```

### Q: Sysprep 失敗？
A: 檢查 `C:\Windows\System32\Sysprep\Panther\` 目錄下的日誌。

### Q: AD 域加入失敗？
A: 確認網路連接與 DNS 解析：
```powershell
nslookup your-domain.local
```

---

## 📧 支援與反饋

- 📝 查閱 `TROUBLESHOOTING.md` 獲取更多幫助
- 🔗 GitHub Issues：報告問題
- 📋 查看 `DEPLOYMENT-GUIDE.md` 獲取詳細說明

---

## 📄 授權

MIT License - 詳見 LICENSE 檔案

---

## 版本歷史

### v1.0.0（2025-02-28）
- ✨ 初始發佈
- 🔐 完整的企業級安全強化
- ⚡ 一鍵自動化部署

---

**最後更新**：2025-02-28  
**維護者**：v0re  
**倉庫**：https://github.com/v0re/Windows-Server-2019-Golden-Image
