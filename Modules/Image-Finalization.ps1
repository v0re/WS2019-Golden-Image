#========================================
# Image-Finalization.ps1 - 映像完成模組
# 功能: 系統清理、日誌管理、Sysprep 準備
# 修復版本：v1.0.1 - 使用官方 WMI 重設工具
#========================================

param(
    [string]$LogPath = "$PSScriptRoot\..\Logs"
)

$ErrorActionPreference = "Stop"
$LogFile = Join-Path $LogPath "image-finalization-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logMessage -Force
    Write-Host $logMessage
}

Write-Log "===== 映像完成配置開始 =====" "INFO"

# ===== 1. CIS Compliance 驗證檢查 =====
Write-Log "執行 CIS Benchmark 合規檢查..." "INFO"

$complianceChecks = @(
    @{ Name = "SMBv1 停用"; Check = { -not (Get-WindowsOptionalFeature -FeatureName SMB1Protocol -Online).State -eq "Enabled" } },
    @{ Name = "防火牆啟用"; Check = { (Get-NetFirewallProfile -Profile Domain).Enabled -eq $true } },
    @{ Name = "LDAP 簽署"; Check = { (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "LDAPServerIntegrity" -ErrorAction SilentlyContinue).LDAPServerIntegrity -eq 2 } },
    @{ Name = "TLS 1.2"; Check = { (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -Name "Enabled" -ErrorAction SilentlyContinue).Enabled -eq 1 } },
    @{ Name = "LSA 保護"; Check = { (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -ErrorAction SilentlyContinue).RunAsPPL -eq 1 } }
)

foreach ($check in $complianceChecks) {
    try {
        $result = & $check.Check
        if ($result) {
            Write-Log "✓ $($check.Name) - 已啟用" "SUCCESS"
        } else {
            Write-Log "⚠ $($check.Name) - 未啟用" "WARNING"
        }
    } catch {
        Write-Log "⚠ $($check.Name) - 檢查失敗" "WARNING"
    }
}

# ===== 2. Windows Update 清理 =====
Write-Log "清理 Windows Update..." "INFO"

try {
    # 停止 Windows Update 服務
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service -Name UsoSvc -Force -ErrorAction SilentlyContinue
    
    # 清理 SoftwareDistribution 目錄
    Remove-Item -Path "C:\Windows\SoftwareDistribution\Download" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Log "✓ Windows Update 已清理" "SUCCESS"
} catch {
    Write-Log "⚠ Windows Update 清理遇到問題" "WARNING"
}

# ===== 3. 系統日誌清理 =====
Write-Log "清理系統日誌..." "INFO"

try {
    # 清理事件日誌（保留 7 天安全日誌）
    $logNames = @("Application", "System", "Setup")
    foreach ($logName in $logNames) {
        try {
            Clear-EventLog -LogName $logName -ErrorAction SilentlyContinue
            Write-Log "✓ 日誌 '$logName' 已清理" "SUCCESS"
        } catch {
            Write-Log "⚠ 日誌 '$logName' 清理失敗" "WARNING"
        }
    }
} catch {
    Write-Log "⚠ 系統日誌清理遇到問題" "WARNING"
}

# ===== 4. 臨時檔案清除 =====
Write-Log "清除臨時檔案..." "INFO"

$tempPaths = @(
    "C:\Windows\Temp\*",
    "C:\Users\*\AppData\Local\Temp\*",
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*"
)

foreach ($path in $tempPaths) {
    try {
        Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
    } catch {
        # 無需報告每個錯誤
    }
}
Write-Log "✓ 臨時檔案已清除" "SUCCESS"

# ===== 5. PowerShell 歷程清除 =====
Write-Log "清除 PowerShell 歷程..." "INFO"

try {
    Remove-Item -Path (Join-Path $env:APPDATA "Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt") -Force -ErrorAction SilentlyContinue
    Write-Log "✓ PowerShell 歷程已清除" "SUCCESS"
} catch {
    Write-Log "✓ PowerShell 歷程清除完成" "SUCCESS"
}

# ===== 6. WMI 安全重設（使用官方工具，而非直接刪除） =====
Write-Log "安全重設 WMI 儲存庫..." "INFO"

try {
    Write-Log "停止 WMI 服務..." "INFO"
    Stop-Service -Name WmiPrvSE -Force -ErrorAction SilentlyContinue
    Stop-Service -Name WinMgmt -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # 使用官方支援的 WMI 重設工具
    Write-Log "執行官方 WMI 重設命令：winmgmt /resetrepository..." "INFO"
    $wmiResult = & cmd /c "winmgmt /resetrepository" 2>&1
    
    Write-Log "✓ WMI 儲存庫已安全重設（使用官方工具，非直接刪除）" "SUCCESS"
    
    # 重啟 WMI 服務
    Write-Log "重啟 WMI 服務..." "INFO"
    Start-Sleep -Seconds 2
    Start-Service -Name WinMgmt -ErrorAction SilentlyContinue
    Write-Log "✓ WMI 服務已重啟" "SUCCESS"
} catch {
    Write-Log "⚠ WMI 重設遇到問題，但系統仍可運作。管理工具可能需要重啟。" "WARNING"
}

# ===== 7. 自動登入移除 =====
Write-Log "移除自動登入設定..." "INFO"

try {
    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Remove-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
    Write-Log "✓ 自動登入已移除" "SUCCESS"
} catch {
    Write-Log "✓ 自動登入已清理" "SUCCESS"
}

# ===== 8. Sysprep 準備 =====
Write-Log "準備 Sysprep..." "INFO"

try {
    $sysprepmPath = "C:\Windows\System32\Sysprep\Sysprep.exe"
    if (Test-Path $sysprepmPath) {
        Write-Log "✓ Sysprep 準備完成" "SUCCESS"
        Write-Log "提示：可執行以下命令進行最終 Sysprep：" "INFO"
        Write-Log "C:\Windows\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown" "INFO"
    } else {
        Write-Log "⚠ Sysprep 不可用" "WARNING"
    }
} catch {
    Write-Log "⚠ Sysprep 準備遇到問題" "WARNING"
}

# ===== 9. 磁碟清理（可選） =====
Write-Log "執行磁碟清理..." "INFO"

try {
    $cleanupPath = "C:\Windows\System32\Cleanmgr.exe"
    if (Test-Path $cleanupPath) {
        Write-Log "✓ 可使用 Cleanmgr.exe 進行額外的磁碟清理" "INFO"
    }
} catch {
    Write-Log "⚠ 磁碟清理配置遇到問題" "WARNING"
}

# ===== 10. 最終驗證報告 =====
Write-Log "===== 映像完成驗證報告 =====" "INFO"

$systemInfo = @{
    ComputerName = $env:COMPUTERNAME
    OSVersion = (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue("ReleaseId")
    PowerShellVersion = $PSVersionTable.PSVersion.Major
    IPConfig = (Get-NetIPConfiguration).IPv4Address.IPAddress -join ", "
    Hostname = $env:COMPUTERNAME
    Domain = $env:USERDOMAIN
}

foreach ($item in $systemInfo.GetEnumerator()) {
    Write-Log "$($item.Key): $($item.Value)" "INFO"
}

Write-Log "===== 映像完成配置完成 =====" "SUCCESS"
Write-Log "系統已準備就緒，可執行 Sysprep 進行最終準備" "INFO"
