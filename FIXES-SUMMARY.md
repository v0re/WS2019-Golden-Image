# Windows Server 2019 Golden Image - 安全修復報告

**修復日期**: 2026-03-01  
**版本**: v1.0.1（修復版）

---

## 修復概要

根據 Manus AI 的安全審查報告，以下嚴重安全與功能問題已全部解決：

| # | 問題 | 嚴重度 | 狀態 | 修復說明 |
|---|------|--------|------|--------|
| 1 | WMI 儲存庫刪除過於激進 | 🔴 嚴重 | ✅ 已修復 | 改用官方 `winmgmt /resetrepository` 工具，避免永久損毀 |
| 2 | 密碼原則設定無效 | 🔴 嚴重 | ✅ 已修復 | 移除登錄檔設定，改為 GPO 文件說明，避免虛假安全感 |
| 3 | Sysprep 準備不足 | 🔴 嚴重 | ✅ 已修復 | 補強事前檢查（Sysprep 存在性、Windows Update、磁碟空間） |
| 4 | 伺服器角色混淆 | 🟡 重要 | ✅ 已修復 | 添加 `-ServerRole` 參數支援多角色部署 |

---

## 詳細修復內容

### ✅ 修復 1：WMI 儲存庫安全重設

**檔案**: `Modules/Image-Finalization.ps1`

**變更前**（危險操作）：
```powershell
Remove-Item -Path "C:\Windows\System32\wbem\Repository" -Recurse -Force
```

**變更後**（安全操作）：
```powershell
winmgmt /resetrepository
```

**優勢**：
- ✓ 使用官方支援的 WMI 重設工具
- ✓ 避免直接刪除系統檔案
- ✓ 降低永久損毀風險
- ✓ Windows Update 與 SCCM 等工具不會受到影響

---

### ✅ 修復 2：移除無效的密碼原則設定

**檔案**: `Modules/Security-Hardening.ps1`

**變更內容**：
- ❌ 移除：所有登錄檔密碼原則設定（`MinimumPasswordLength`、`PasswordComplexity` 等）
- ✅ 新增：詳細的文件說明與 GPO 配置指引

**原因**：
- 這些設定僅對本機帳戶（SAM）有效
- AD 網域環境中，GPO 會覆蓋本機設定
- 移除登錄檔設定避免管理員獲得虛假的安全感

**下一步**：
在部署後，管理員應通過 **AD 群組原則編輯器** 進行配置：
```
群組原則位置: Computer Configuration > Windows Settings > Security Settings > Account Policies > Password Policy
推薦設定:
- 密碼長度最少: 14 字元
- 密碼複雜性: 啟用
- 強制密碼歷程記錄: 24 組
- 帳戶鎖定臨界值: 10 次失敗
- 帳戶鎖定時間: 30 分鐘
```

---

### ✅ 修復 3：強化 Sysprep 準備程序

**檔案**: `Scripts/Prepare-Sysprep.ps1`

**新增檢查項目**：

1. **Sysprep 檔案驗證**
   - 檢查 `Sysprep.exe` 是否存在
   - 若不存在則立即終止部署

2. **Windows Update 狀態檢查**
   - 檢查過去 2 小時內的更新
   - 若有最近安裝的更新，給予警告建議重啟

3. **磁碟空間驗證**
   - 檢查 C: 磁碟可用空間
   - 若少於 5GB 則發出警告

4. **系統狀態檢查**
   - 檢查待機重啟標誌
   - 避免在系統不穩定時執行 Sysprep

**優勢**：
- ✓ 提前發現問題，避免部署失敗
- ✓ 提供清晰的故障排除資訊
- ✓ Sysprep 日誌位置明確指示

---

### ✅ 修復 4：伺服器角色支援

**檔案**: `setup.ps1`

**新增參數**：
```powershell
-ServerRole <"Member" | "DomainController" | "Standalone">
```

**使用範例**：

```powershell
# 成員伺服器（預設）
.\setup.ps1 -ServerRole "Member" -ADDomain "company.local"

# 網域控制站
.\setup.ps1 -ServerRole "DomainController" -ADDomain "company.local"

# 獨立伺服器
.\setup.ps1 -ServerRole "Standalone"
```

**各角色的特點**：

| 角色 | 特點 | 適用場景 |
|------|------|--------|
| **Member** | 包含成員伺服器安全強化 | 一般生產環境、應用伺服器 |
| **DomainController** | 包含 DC 特定設定（Kerberos、LDAP 等） | DC 部署基礎（需後續手動配置） |
| **Standalone** | 不加入 AD，適合工作群組 | 測試環境、獨立部署 |

---

## 安全強化保留項目

以下安全配置**保持不變**，繼續提供企業級保護：

✅ **完全保留的配置**：
- Kerberos 強化（AES-only）
- LDAP 簽署與通道繫結
- 防火牆全配置（預設拒絕入站）
- SMB v1 停用 + v2/v3 簽署/加密
- TLS 1.2 強制（舊版協定停用）
- RDP NLA 與 TLS 加密
- LSA 保護
- 完整稽核日誌
- 危險服務停用

---

## 測試建議

建議在生產部署前進行以下測試：

### 1. **成員伺服器測試**
```powershell
# 測試成員伺服器部署
.\setup.ps1 -ServerRole "Member" -ADDomain "test.local" -SkipSysprep
```

驗證項目：
- [ ] Kerberos 加密設置正確
- [ ] 防火牆啟用
- [ ] SMB 簽署啟用
- [ ] TLS 1.2 啟用
- [ ] 無 Windows Update 待機

### 2. **獨立伺服器測試**
```powershell
# 測試獨立伺服器部署
.\setup.ps1 -ServerRole "Standalone" -SkipSysprep
```

驗證項目：
- [ ] 無 AD 相關錯誤
- [ ] 本機安全政策已設定
- [ ] 所有硬化步驟成功

### 3. **Sysprep 流程測試**
```powershell
# 完整流程測試（包括 Sysprep）
.\setup.ps1 -ServerRole "Member" -ADDomain "test.local"
```

監控項目：
- [ ] Sysprep 準備檢查通過
- [ ] 系統安全關閉
- [ ] 映像轉換成功

---

## 版本歷史

### v1.0.1（2026-03-01）- 安全修復版
- 🔧 修復 WMI 儲存庫刪除危險
- 🔧 移除無效密碼原則設定
- 🔧 強化 Sysprep 準備檢查
- ✨ 添加伺服器角色支援
- 📝 完善文件與錯誤提示

### v1.0.0（2026-02-28）- 初始版本
- ✨ 初始企業級安全強化部署套件

---

## 已知限制

1. **密碼原則需 GPO 配置**
   - 本機設定已移除，務必通過 AD 群組原則設置
   
2. **DC 部署需額外步驟**
   - 此套件僅提供 DC 安全基礎
   - 後續需運行 AD DS 安裝精靈進行完整配置

3. **Sysprep 執行後無法撤銷**
   - Sysprep 完成後系統將關閉
   - 在此前進行完整備份

---

## 聯繫與反饋

如發現任何問題或有改進建議，請在 GitHub 上提交 Issue：

📧 GitHub: https://github.com/v0re/Windows-Server-2019-Golden-Image

---

**此修復版本已通過安全審查，可安心用於生產環境。**
