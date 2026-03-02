#========================================
# Prepare-Sysprep.ps1 - Sysprep 準備
# 功能: 驗證系統狀態、執行 Sysprep
#========================================

param(
    [string]$LogPath = "$PSScriptRoot\..\Logs"
)

$ErrorActionPreference = "Stop"
$LogFile = Join-Path $LogPath "sysprep-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logMessage -Force
    Write-Host $logMessage
}

Write-Log "===== Sysprep 最終準備開始 =====" "INFO"

# ===== 1. 檢查 Sysprep 檔案 =====
Write-Log "檢查 Sysprep 檔案..." "INFO"

$sysprepmPath = "C:\Windows\System32\Sysprep\Sysprep.exe"
if (-not (Test-Path $sysprepmPath)) {
    Write-Log "錯誤：Sysprep.exe 不存在於 $sysprepmPath" "ERROR"
    Write-Log "系統可能不是 Windows Server 或 Sysprep 已被移除" "ERROR"
    exit 1
}
Write-Log "✓ Sysprep.exe 確認存在" "SUCCESS"

# ===== 2. 檢查近期 Windows Update =====
Write-Log "檢查 Windows Update 狀態..." "INFO"

try {
    $recentUpdates = Get-HotFix | Where-Object { $_.InstalledOn -gt (Get-Date).AddHours(-2) }
    if ($recentUpdates) {
        Write-Log "⚠️  警告：檢測到最近 2 小時內安裝的更新" "WARNING"
        Write-Log "建議：在執行 Sysprep 前重啟系統，確保更新完全應用" "WARNING"
        Write-Log "按 Enter 繼續，或 Ctrl+C 取消..." "INFO"
        # Read-Host
    } else {
        Write-Log "✓ 無近期 Windows Update，系統準備就緒" "SUCCESS"
    }
} catch {
    Write-Log "⚠️  無法檢查 Windows Update 狀態，但繼續進行" "WARNING"
}

# ===== 3. 檢查磁碟空間 =====
Write-Log "檢查磁碟空間..." "INFO"

$systemDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
if ($systemDrive) {
    $freeSpaceGB = [math]::Round($systemDrive.Free / 1GB, 2)
    if ($freeSpaceGB -lt 5) {
        Write-Log "⚠️  警告：系統磁碟可用空間不足 ($freeSpaceGB GB)，Sysprep 可能失敗" "WARNING"
    } else {
        Write-Log "✓ 磁碟空間充足 ($freeSpaceGB GB 可用)" "SUCCESS"
    }
}

# ===== 4. 檢查舊版網路驅動程式 =====
Write-Log "檢查系統狀態..." "INFO"

try {
    # 檢查是否有待機重啟
    $pendingRestart = Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce\*"
    if ($pendingRestart) {
        Write-Log "⚠️  系統可能有待機重啟，建議先重啟" "WARNING"
    }
    Write-Log "✓ 系統狀態檢查完成" "SUCCESS"
} catch {
    Write-Log "⚠️  無法進行系統狀態檢查，但繼續進行" "WARNING"
}

# ===== 5. 執行 Sysprep =====
Write-Log "===== 執行 Sysprep =====" "INFO"
Write-Log "此操作將通用化系統並執行關閉" "WARNING"
Write-Log "系統將在 Sysprep 完成後自動關閉" "WARNING"
Write-Log "" "INFO"

# Sysprep 參數說明
# /oobe - 進入 Windows 歡迎體驗（OOBE）
# /generalize - 移除系統特定資訊（如 SID、驅動程式等），以便在其他硬體上部署
# /shutdown - 執行完成後關閉系統
# /quiet - 無視覺化進度
# /unattend:Unattend.xml - 可選：使用無人應答檔案

try {
    Write-Log "正在啟動 Sysprep，請勿中斷..." "INFO"
    
    # 執行 Sysprep
    & $sysprepmPath /oobe /generalize /shutdown /quiet
    
    Write-Log "✓ Sysprep 已啟動，系統將在完成後關閉" "SUCCESS"
    Write-Log "此為最後的日誌記錄。完整的 Sysprep 日誌將保存在：" "INFO"
    Write-Log "C:\Windows\System32\Sysprep\Panther\" "INFO"
    
    # 等待系統關閉
    Start-Sleep -Seconds 5
    
} catch {
    Write-Log "錯誤：執行 Sysprep 失敗" "ERROR"
    Write-Log "錯誤詳情：$($_.Exception.Message)" "ERROR"
    Write-Log "檢查 Sysprep 日誌以獲取更多資訊：C:\Windows\System32\Sysprep\Panther\setuperr.log" "ERROR"
    exit 1
}

Write-Log "===== Sysprep 準備完成 =====" "SUCCESS"
