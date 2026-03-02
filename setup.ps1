#========================================
# Windows Server 2019 Golden Image - 一鍵自動化部署
# 版本: 1.0.0
# 說明: 管理員執行此腳本，系統自動化完成所有安全強化配置
#========================================

param(
    [ValidateSet("Member", "DomainController", "Standalone")]
    [string]$ServerRole = "Member",
    [string]$ADDomain = "domain.local",
    [string]$LogPath = "$PSScriptRoot\Logs",
    [switch]$SkipSysprep = $false
)

# ===== 基礎設定 =====
$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"
$VerbosePreference = "Continue"

# 建立日誌目錄
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$LogFile = Join-Path $LogPath "deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$StartTime = Get-Date

# ===== 日誌函數 =====
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logMessage
    Write-Host $logMessage -ForegroundColor $(if ($Level -eq "ERROR") { "Red" } elseif ($Level -eq "SUCCESS") { "Green" } else { "White" })
}

# ===== 檢查管理員權限 =====
function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ===== 檢查 PowerShell 版本 =====
function Test-PowerShellVersion {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log "PowerShell 版本過低（需 5.1+）" "ERROR"
        return $false
    }
    return $true
}

# ===== 主部署邏輯 =====
function Start-Deployment {
    Write-Log "========================================" "INFO"
    Write-Log "Windows Server 2019 Golden Image 部署開始" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "伺服器角色: $ServerRole" "INFO"
    Write-Log "AD 域名: $ADDomain" "INFO"
    Write-Log "日誌路徑: $LogFile" "INFO"
    Write-Log "========================================" "INFO"
    
    # 驗證伺服器角色
    if ($ServerRole -eq "Member" -and [string]::IsNullOrEmpty($ADDomain)) {
        Write-Log "警告：您選擇了『成員伺服器』但未指定 AD 域名。將使用預設值：$ADDomain" "WARNING"
    }
    
    if ($ServerRole -eq "Standalone") {
        Write-Log "提示：您選擇了『獨立伺服器』，此映像不會加入 AD 網域。" "INFO"
    }
    
    if ($ServerRole -eq "DomainController") {
        Write-Log "⚠️  重要：您選擇了『網域控制站』模式。" "WARNING"
        Write-Log "此映像將包含 DC 特定的安全強化設定（Kerberos、LDAP 等）" "WARNING"
        Write-Log "DC 部署需要額外的手動配置（使用 AD DS 安裝精靈）" "WARNING"
    }
    
    # 檢查管理員權限
    if (-not (Test-AdminPrivileges)) {
        Write-Log "錯誤：必須以管理員身分執行此腳本" "ERROR"
        exit 1
    }
    Write-Log "✓ 已確認管理員權限" "SUCCESS"
    
    # 檢查 PowerShell 版本
    if (-not (Test-PowerShellVersion)) {
        Write-Log "錯誤：PowerShell 版本不符要求" "ERROR"
        exit 1
    }
    Write-Log "✓ PowerShell 版本檢查通過" "SUCCESS"
    
    # 設置執行策略
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force -ErrorAction SilentlyContinue
        Write-Log "✓ 執行策略設置為 RemoteSigned" "SUCCESS"
    } catch {
        Write-Log "警告：無法設置執行策略 $_" "WARNING"
    }
    
    # 執行安全強化模組
    Write-Log "開始執行安全強化配置..." "INFO"
    try {
        & "$PSScriptRoot\Modules\Security-Hardening.ps1" -ADDomain $ADDomain -LogPath $LogPath
        Write-Log "✓ 安全強化配置完成" "SUCCESS"
    } catch {
        Write-Log "錯誤：安全強化失敗 $_" "ERROR"
        exit 1
    }
    
    # 執行網路安全模組
    Write-Log "開始執行網路安全配置..." "INFO"
    try {
        & "$PSScriptRoot\Modules\Network-Hardening.ps1" -LogPath $LogPath
        Write-Log "✓ 網路安全配置完成" "SUCCESS"
    } catch {
        Write-Log "錯誤：網路安全失敗 $_" "ERROR"
        exit 1
    }
    
    # 執行映像完成模組
    Write-Log "開始執行映像完成配置..." "INFO"
    try {
        & "$PSScriptRoot\Modules\Image-Finalization.ps1" -LogPath $LogPath
        Write-Log "✓ 映像完成配置完成" "SUCCESS"
    } catch {
        Write-Log "錯誤：映像完成失敗 $_" "ERROR"
        exit 1
    }
    
    # Sysprep 準備
    if (-not $SkipSysprep) {
        Write-Log "準備執行 Sysprep..." "INFO"
        try {
            & "$PSScriptRoot\Scripts\Prepare-Sysprep.ps1" -LogPath $LogPath
            Write-Log "✓ Sysprep 準備完成 - 系統將重啟" "SUCCESS"
        } catch {
            Write-Log "警告：Sysprep 準備失敗 $_" "WARNING"
        }
    }
    
    $ElapsedTime = $(Get-Date) - $StartTime
    Write-Log "========================================" "INFO"
    Write-Log "部署完成（耗時：$($ElapsedTime.TotalMinutes) 分鐘）" "SUCCESS"
    Write-Log "========================================" "INFO"
}

# ===== 執行主程序 =====
Start-Deployment
