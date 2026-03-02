# 安全基準配置說明

## 概覽

本部署套件實現了企業級最安全的 Windows Server 2019 配置，遵循以下標準：

- **CIS Benchmark v2.0/v4.0** - Windows Server 2019
- **NIST SP 800-63B Rev 4** - 數字身份指南（密碼政策）
- **NIST SP 800-52r2** - TLS 實現選擇指南
- **Microsoft Security Baseline** - 官方安全建議

---

## 配置詳解

### 1. Kerberos 加密強化

**為什麼重要？**
Kerberos 是 Windows 域環境的核心身份驗證機制。弱加密演算法（如 RC4）容易被破解。

**配置：**
- 設置 `KdcSupportedEncryptionTypes = 24`（AES128 + AES256）
- 停用 DES、RC4、MD5

**風險消除：**
- ✓ Kerberoasting 攻擊難度增加
- ✓ AS-REP Roasting 無法利用弱加密
- ✓ 認證票證無法被線下破解

---

### 2. LDAP 簽署與通道繫結

**為什麼重要？**
LDAP 是 Active Directory 的查詢協議。未簽署的 LDAP 流量容易被篡改，攻擊者可以進行中間人攻擊。

**配置：**
- `LDAPServerIntegrity = 2`（必須簽署）
- `LdapEnforceChannelBinding = 2`（通道繫結強制）
- `LdapClientIntegrity = 2`（用戶端簽署）

**風險消除：**
- ✓ 無法執行 LDAP Relay 攻擊
- ✓ 查詢結果無法被篡改
- ✓ 目錄信息無法被攔截修改

---

### 3. 密碼原則（NIST Rev 4 標準）

**為什麼重要？**
密碼是最後的防線。NIST 2025 年更新的建議放棄了複雜度與定期變更，轉而強調長度 + 外洩檢查。

**配置：**
- 最小長度：**14 字元**（使用者），**16 字元**（管理員）
- 密碼歷程：**24 組**（防止重複）
- 複雜性：**啟用**（大小寫字母 + 數字 + 特殊字元）
- 帳戶鎖定：**10 次失敗**→**30 分鐘鎖定**

**為什麼 NIST 不再強制定期變更？**
研究表明，定期強制變更導致使用者選擇更弱的密碼（如「Password2024」變成「Password2025」）。

**風險消除：**
- ✓ 字典攻擊與暴力破解成本增加
- ✓ Rainbow Table 無法應用（長度太長）
- ✓ 帳戶無法長時間被暴力嘗試

---

### 4. Windows Defender 防火牆

**為什麼重要？**
防火牆是主機級最後一道防線，防止橫向移動（East-West 流量）。

**配置：**
- 所有設定檔啟用（Domain、Public、Private）
- 預設入站：**Block**（拒絕所有未明確允許的）
- 預設出站：**Allow**（允許所有未明確拒絕的）
- 日誌記錄：**16 MB**，記錄允許 & 拒絕的連線

**規則範例：**
- RDP (3389) → 限制來源 IP（僅管理子網）
- SMB (445) → 限制來源 IP
- DNS (53) → 允許指定 DNS 伺服器

**風險消除：**
- ✓ 蠕蟲與自傳播惡意軟體無法橫向移動
- ✓ 資料外洩流量可被追蹤與阻止
- ✓ 未授權服務無法被遠端啟用

---

### 5. SMB 簽署與加密

**為什麼重要？**
SMB 是檔案共用、列印、身份驗證的核心協議。未簽署的 SMB 容易被 NTLM Relay 攻擊。

**配置：**
- 停用 SMBv1（易受 EternalBlue 攻擊）
- 強制 SMBv2/v3 簽署（`RequireSecuritySignature = true`）
- 啟用加密（`EncryptData = true`）

**保護場景：**
- ✓ 防止 NTLM Relay 升級為 Domain Admin
- ✓ 檔案傳輸無法被篡改
- ✓ 認證無法被重複使用

---

### 6. TLS 1.2 強制與舊協定停用

**為什麼重要？**
SSL 3.0、TLS 1.0/1.1 已被破解（Poodle、Beast 等）。Server 2019 支援 TLS 1.2（1.3 需 Server 2022）。

**配置：**
```
停用：SSL 2.0/3.0、TLS 1.0/1.1（Server & Client）
啟用：TLS 1.2（Server & Client）
密碼套件：優先 ECDHE + AES-GCM
```

**加密套件順序：**
1. `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`
2. `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`
3. ~~`TLS_RSA_WITH_AES_128_CBC_SHA`~~ （停用）

**風險消除：**
- ✓ POODLE 攻擊不可能
- ✓ 中間人攻擊成本增加
- ✓ Perfect Forward Secrecy（前向保密）啟用

---

### 7. RDP 網路級驗證（NLA）

**為什麼重要？**
RDP 是最常見的橫向移動工具。NLA 在建立加密通道前先驗證身份，防止拒絕服務。

**配置：**
- `UserAuthentication = 1`（NLA 必須）
- `SecurityLayer = 2`（TLS 加密）
- `MinEncryptionLevel = 3`（128-bit 最低）

**風險消除：**
- ✓ 無效認證無法消耗伺服器資源（DoS 防護）
- ✓ 認證在加密通道內進行（Credential 保護）
- ✓ 會話無法被監聽

---

### 8. LSA 保護（Credential Guard 前置）

**為什麼重要？**
Local Security Authority（LSA）負責驗證所有本機登入。Mimikatz 經常竊取 LSA 記憶體中的認證。

**配置：**
- `RunAsPPL = 1`（以 Protected Process Light 執行 LSASS）
- 需要 UEFI Secure Boot 與虛擬化支援

**風險消除：**
- ✓ Mimikatz 無法讀取 LSASS 記憶體
- ✓ NTLM 雜湊無法被提取
- ✓ Kerberos TGT 無法被複製

---

### 9. 完整稽核日誌

**為什麼重要？**
安全配置必須輔以完整的紀錄，便於事後分析與合規審計。

**啟用的稽核類別：**
- 帳戶登入事件（成功與失敗）
- 帳戶鎖定
- 登入/登出
- 特權使用
- 政策變更
- 程序建立
- 物件存取

**日誌保留：**
- 最少 7 天（推薦 30 天）
- 大小上限 16 MB（自動覆蓋）
- 定期備份至 SIEM

---

### 10. 停用危險服務

**停用的服務及原因：**

| 服務 | 理由 | 風險 |
|------|------|------|
| **Spooler** (列印服務) | PrintNightmare 漏洞 | RCE、提權 |
| **RemoteRegistry** | 遠端登錄存取 | 讀寫 HKLM、提權 |
| **XboxLive** | 不需要 | 側通道、資料外洩 |
| **Computer Browser** | NetBIOS 相關 | 列舉、定位 |

---

## 安全合規清單

✅ **已實施的控制項：**

- [x] Kerberos AES-only
- [x] LDAP 簽署強制
- [x] NIST 標準密碼原則
- [x] 防火牆完整啟用
- [x] SMBv1 停用
- [x] SMB 簽署/加密
- [x] TLS 1.2 強制
- [x] RDP NLA
- [x] LSA 保護
- [x] 完整稽核
- [x] 危險服務停用

⚠️ **考慮補充的控制項（非此部署包含）：**

- [ ] BitLocker（本部署不包含）
- [ ] Credential Guard（需 Hyper-V）
- [ ] Windows Hello for Business
- [ ] Azure AD 整合
- [ ] Multi-Factor Authentication

---

## 部署後驗證

執行以下命令驗證配置：

```powershell
# 驗證 Kerberos
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\KDC" -Name "KdcSupportedEncryptionTypes"

# 驗證 LDAP
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "LDAPServerIntegrity"

# 驗證 TLS
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -Name "Enabled"

# 驗證防火牆
Get-NetFirewallProfile -Profile Domain | Select-Object -Property Profile, Enabled, DefaultInboundAction

# 驗證 SMB
Get-SmbServerConfiguration | Select-Object -Property RequireSecuritySignature, EncryptData
```

---

**參考資源：**
- [CIS Benchmark](https://www.cisecurity.org/)
- [NIST SP 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [Microsoft Security Baseline](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-security-baselines)
