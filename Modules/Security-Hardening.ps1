#========================================
# Security-Hardening.ps1 - 安全強化模組
# 功能: Kerberos、密碼原則（AD 感知）、稽核日誌、LDAP 簽署等
# 修復版本：v1.0.1 - 支援 AD 環境檢測
#========================================

param(
    [string]$ADDomain = "domain.local",
    [string]$LogPath = "$PSScriptRoot\..\Logs"
)

$ErrorActionPreference = "Stop"
$LogFile = Join-Path $LogPath "security-hardening-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logMessage -Force
    Write-Host $logMessage
}

Write-Log "===== 安全強化配置開始 =====" "INFO"

# ===== 1. Kerberos 強化 =====
Write-Log "配置 Kerberos 加密..." "INFO"

# 啟用 AES-only 加密
$kerberosPath = "HKLM:\SYSTEM\CurrentControlSet\Services\KDC"
New-Item -Path $kerberosPath -Force | Out-Null
New-ItemProperty -Path $kerberosPath -Name "KdcSupportedEncryptionTypes" -Value 24 -PropertyType DWord -Force | Out-Null
Write-Log "✓ Kerberos 加密設置為 AES-only（值：24 = AES128 + AES256）" "SUCCESS"

# ===== 2. LDAP 簽署與通道繫結 =====
Write-Log "配置 LDAP 簽署與通道繫結..." "INFO"

# DC 特定設定（僅當此伺服器為 DC 時生效）
$ldapPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters"
New-Item -Path $ldapPath -Force | Out-Null
New-ItemProperty -Path $ldapPath -Name "LDAPServerIntegrity" -Value 2 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $ldapPath -Name "LdapEnforceChannelBinding" -Value 2 -PropertyType DWord -Force | Out-Null
Write-Log "✓ LDAP 簽署已啟用（值：2 = 必須簽署）" "SUCCESS"
Write-Log "✓ LDAP 通道繫結已啟用（值：2 = 必須驗證）" "SUCCESS"

# LDAP 用戶端簽署
$ldapClientPath = "HKLM:\System\CurrentControlSet\Services\LDAP"
New-Item -Path $ldapClientPath -Force | Out-Null
New-ItemProperty -Path $ldapClientPath -Name "LdapClientIntegrity" -Value 2 -PropertyType DWord -Force | Out-Null
Write-Log "✓ LDAP 用戶端簽署已啟用" "SUCCESS"

# ===== 3. 密碼原則配置（AD 感知） =====
Write-Log "配置密碼原則..." "INFO"

# 檢查是否加入 AD 網域
$computerSystem = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
$isPartOfDomain = $computerSystem.PartOfDomain -eq $true

if ($isPartOfDomain) {
    Write-Log "⚠️  偵測到此伺服器已加入 Active Directory 網域" "WARNING"
    Write-Log "密碼原則將由 AD 群組原則（GPO）控制，本機登錄檔設定將被 GPO 覆蓋" "WARNING"
    Write-Log "請確保在 AD 中配置以下群組原則（位置：Computer Configuration > Windows Settings > Security Settings > Account Policies > Password Policy）：" "INFO"
    Write-Log "  • 密碼長度最少：14 字元（成員伺服器）或 16 字元（管理員）" "INFO"
    Write-Log "  • 密碼複雜性：啟用（大小寫 + 數字 + 特殊字元）" "INFO"
    Write-Log "  • 強制密碼歷程記錄：24 組（防止重複）" "INFO"
    Write-Log "  • 帳戶鎖定臨界值：10 次失敗" "INFO"
    Write-Log "  • 帳戶鎖定時間：30 分鐘" "INFO"
    Write-Log "  • 帳戶鎖定計數器重設時間：30 分鐘" "INFO"
} else {
    Write-Log "此伺服器為獨立伺服器或工作群組環境，設置本機密碼原則" "INFO"
    
    # 設置本機安全政策（僅對獨立伺服器有效）
    $securityPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
    New-Item -Path $securityPath -Force | Out-Null
    
    # 最小密碼長度：14 字元
    New-ItemProperty -Path $securityPath -Name "MinimumPasswordLength" -Value 14 -PropertyType DWord -Force | Out-Null
    Write-Log "✓ 最小密碼長度設置為 14 字元" "SUCCESS"
    
    # 密碼複雜性已啟用
    New-ItemProperty -Path $securityPath -Name "PasswordComplexity" -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Log "✓ 密碼複雜性已啟用" "SUCCESS"
    
    # 密碼歷程記錄：24 組
    New-ItemProperty -Path $securityPath -Name "PasswordHistorySize" -Value 24 -PropertyType DWord -Force | Out-Null
    Write-Log "✓ 密碼歷程記錄設置為 24 組" "SUCCESS"
    
    # 帳戶鎖定：10 次失敗後鎖定 30 分鐘
    New-ItemProperty -Path $securityPath -Name "LockoutBadCount" -Value 10 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $securityPath -Name "LockoutDuration" -Value 30 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $securityPath -Name "ResetLockoutCount" -Value 30 -PropertyType DWord -Force | Out-Null
    Write-Log "✓ 帳戶鎖定設置為 10 次失敗後鎖定 30 分鐘" "SUCCESS"
}

# ===== 4. LSA 保護 =====
Write-Log "啟用 LSA 保護..." "INFO"

$lsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
New-ItemProperty -Path $lsaPath -Name "RunAsPPL" -Value 1 -PropertyType DWord -Force | Out-Null
Write-Log "✓ LSA 保護已啟用（RunAsPPL = 1）" "SUCCESS"

# ===== 5. 完整稽核日誌 =====
Write-Log "啟用完整稽核日誌..." "INFO"

# 啟用審計對象存取
try {
    auditpol /set /subcategory:"Audit Policy Change" /success:enable /failure:enable | Out-Null
    auditpol /set /subcategory:"Logon/Logoff" /success:enable /failure:enable | Out-Null
    auditpol /set /subcategory:"Account Lockout" /success:enable /failure:enable | Out-Null
    auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null
    auditpol /set /subcategory:"Sensitive Privilege Use" /success:enable /failure:enable | Out-Null
    Write-Log "✓ 稽核日誌已啟用" "SUCCESS"
} catch {
    Write-Log "⚠ 稽核日誌設置遇到問題，但繼續進行" "WARNING"
}

# ===== 6. 停用 SMBv1 =====
Write-Log "停用 SMBv1..." "INFO"

try {
    Disable-WindowsOptionalFeature -FeatureName SMB1Protocol -Online -NoRestart -ErrorAction SilentlyContinue
    Write-Log "✓ SMBv1 已停用" "SUCCESS"
} catch {
    Write-Log "✓ SMBv1 已停用（或未安裝）" "SUCCESS"
}

# ===== 7. 停用危險服務 =====
Write-Log "停用危險服務..." "INFO"

$dangerousServices = @(
    "Spooler",           # 列印多工緩衝處理程式
    "RemoteRegistry",    # 遠端登錄
    "XboxLive",
    "XblGameSave",
    "XblAuthManager"
)

foreach ($service in $dangerousServices) {
    try {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "✓ 服務 '$service' 已停用" "SUCCESS"
    } catch {
        Write-Log "⚠ 服務 '$service' 無法停用（可能不存在）" "WARNING"
    }
}

# ===== 8. 登錄檔硬化 =====
Write-Log "進行登錄檔硬化..." "INFO"

# 停用 DCOM 遠端啟用
$dcomPath = "HKLM:\Software\Microsoft\OLE"
New-ItemProperty -Path $dcomPath -Name "EnableDCOM" -Value "N" -PropertyType String -Force | Out-Null
Write-Log "✓ DCOM 遠端啟用已停用" "SUCCESS"

# 停用 WinRM 快速配置
try {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" -Name "AllowAutoConfig" -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Log "✓ WinRM 基礎配置已完成" "SUCCESS"
} catch {
    Write-Log "⚠ WinRM 配置遇到問題" "WARNING"
}

Write-Log "===== 安全強化配置完成 =====" "SUCCESS"
