#========================================
# Deploy-GoldenImage.ps1 - 一鍵部署啟動腳本
# 版本: v1.0.4
# 說明: 自動從 GitHub 下載最新版本並執行部署
#       無需 Git 安裝，無需金鑰，直接執行即可
#
# 使用方式（一鍵執行，適合 irm | iex）：
#   irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1 | iex
#
# 進階用法（指定角色與域名，在執行前設定環境變數）：
#   $env:GI_ROLE="Member"; $env:GI_DOMAIN="corp.local"
#   irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1 | iex
#========================================

# ===== 全域錯誤處理：確保任何未捕獲的錯誤不會靜默關閉視窗 =====
$ErrorActionPreference = "Continue"
trap {
    Write-Host ""
    Write-Host "[FATAL] 發生未預期的錯誤：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        位置：$($_.InvocationInfo.ScriptName) 第 $($_.InvocationInfo.ScriptLineNumber) 行" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "按任意鍵關閉..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    break
}

# ===== 讀取環境變數參數（相容 irm | iex 執行方式）=====
$ServerRole  = if ($env:GI_ROLE)   { $env:GI_ROLE }   else { "Member" }
$ADDomain    = if ($env:GI_DOMAIN) { $env:GI_DOMAIN } else { "domain.local" }
$SkipSysprep = if ($env:GI_SKIP_SYSPREP -eq "1") { $true } else { $false }
$InstallPath = if ($env:GI_PATH)   { $env:GI_PATH }   else { "C:\WS2019-Deploy" }

# ===== 驗證角色參數 =====
if ($ServerRole -notin @("Member", "DomainController", "Standalone")) {
    Write-Host "[ERROR] 無效的伺服器角色：$ServerRole" -ForegroundColor Red
    Write-Host "        有效值：Member / DomainController / Standalone" -ForegroundColor Yellow
    exit 1
}

# ===== 顯示橫幅 =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Windows Server 2019 Golden Image" -ForegroundColor Cyan
Write-Host "  一鍵自動部署腳本 v1.0.4" -ForegroundColor Cyan
Write-Host "  https://github.com/v0re/WS2019-Golden-Image" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ===== 檢查管理員權限 =====
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] 請以「系統管理員身分」執行 PowerShell 後再重新執行此腳本！" -ForegroundColor Red
    Write-Host "        右鍵點擊 PowerShell -> 以系統管理員身分執行" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] 管理員權限確認" -ForegroundColor Green

# ===== 路徑設定 =====
$REPO_URL = "https://github.com/v0re/WS2019-Golden-Image"
$ZIP_URL  = "https://github.com/v0re/WS2019-Golden-Image/archive/refs/heads/master.zip"
$ZIP_PATH = Join-Path $env:TEMP "WS2019-GoldenImage-Download.zip"
$EXTRACT  = Join-Path $env:TEMP "WS2019-GoldenImage-Extract"
$WORK_DIR = $InstallPath

# ===== 安全路徑驗證（防止誤刪系統目錄）=====
$dangerousPaths = @("C:\", "C:\Windows", "C:\Windows\System32", $env:TEMP, $env:SystemRoot)
foreach ($dp in $dangerousPaths) {
    if ($WORK_DIR -eq $dp) {
        Write-Host "[ERROR] 安裝路徑不可為系統目錄：$WORK_DIR" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "[INFO] 部署設定：" -ForegroundColor Cyan
Write-Host "  伺服器角色  : $ServerRole"
Write-Host "  AD 域名     : $(if ($ServerRole -eq 'Standalone') { '(不適用)' } else { $ADDomain })"
Write-Host "  安裝路徑    : $WORK_DIR"
Write-Host "  跳過 Sysprep: $SkipSysprep"
Write-Host "  來源倉庫    : $REPO_URL"
Write-Host ""
Write-Host "[INFO] 開始自動部署，請稍候..." -ForegroundColor Yellow
Write-Host ""

# ===== 步驟 1：下載最新版本 =====
Write-Host "[步驟 1/4] 從 GitHub 下載最新版本..." -ForegroundColor Cyan

# 安全清理暫存檔（僅刪除明確的暫存檔案，不刪除目錄）
if (Test-Path $ZIP_PATH) {
    Remove-Item -Path $ZIP_PATH -Force -ErrorAction SilentlyContinue
    Write-Host "  清理舊版暫存檔完成" -ForegroundColor Gray
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $ZIP_URL -OutFile $ZIP_PATH -UseBasicParsing -TimeoutSec 120
    Write-Host "[OK] 下載完成（$(([System.IO.FileInfo]$ZIP_PATH).Length / 1KB -as [int]) KB）" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 下載失敗：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        請確認伺服器可連線至 github.com" -ForegroundColor Yellow
    exit 1
}

# ===== 步驟 2：解壓縮 =====
Write-Host ""
Write-Host "[步驟 2/4] 解壓縮檔案..." -ForegroundColor Cyan

try {
    # 安全清理解壓縮暫存目錄（僅清理明確的暫存子目錄）
    if (Test-Path $EXTRACT) {
        Remove-Item -Path $EXTRACT -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $EXTRACT -Force | Out-Null

    Expand-Archive -Path $ZIP_PATH -DestinationPath $EXTRACT -Force

    # GitHub ZIP 解壓縮後有一個外層資料夾（WS2019-Golden-Image-master）
    $extractedFolder = Get-ChildItem -Path $EXTRACT -Directory | Select-Object -First 1
    if (-not $extractedFolder) {
        Write-Host "[ERROR] 解壓縮後找不到任何資料夾，ZIP 可能損毀" -ForegroundColor Red
        exit 1
    }
    Write-Host "  解壓縮資料夾：$($extractedFolder.Name)" -ForegroundColor Gray

    # 建立工作目錄（若已存在則保留，用 robocopy /MIR 覆蓋更新，避免先刪除導致崩潰）
    if (-not (Test-Path $WORK_DIR)) {
        New-Item -ItemType Directory -Path $WORK_DIR -Force | Out-Null
        Write-Host "  建立安裝目錄：$WORK_DIR" -ForegroundColor Gray
    } else {
        Write-Host "  更新現有安裝目錄：$WORK_DIR" -ForegroundColor Gray
    }

    # 使用 robocopy /MIR 鏡像複製（覆蓋更新，不需先刪除目錄）
    $null = robocopy $extractedFolder.FullName $WORK_DIR /MIR /NFL /NDL /NJH /NJS /NC /NS /NP 2>&1
    # robocopy 退出碼：0=無變更, 1=複製成功, 2-7=有警告但成功, 8+=錯誤
    if ($LASTEXITCODE -ge 8) {
        Write-Host "[ERROR] 檔案複製失敗（robocopy 退出碼：$LASTEXITCODE）" -ForegroundColor Red
        exit 1
    }

    Write-Host "[OK] 解壓縮完成，檔案位於：$WORK_DIR" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 解壓縮失敗：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # 清理暫存 ZIP（無論成功或失敗都清理）
    Remove-Item -Path $ZIP_PATH -Force -ErrorAction SilentlyContinue
}

# ===== 步驟 3：驗證檔案完整性 =====
Write-Host ""
Write-Host "[步驟 3/4] 驗證檔案完整性..." -ForegroundColor Cyan

$requiredFiles = @(
    "setup.ps1",
    "Modules\Security-Hardening.ps1",
    "Modules\Network-Hardening.ps1",
    "Modules\Image-Finalization.ps1",
    "Scripts\Prepare-Sysprep.ps1"
)

$allPresent = $true
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $WORK_DIR $file
    if (Test-Path $fullPath) {
        Write-Host "  [OK] $file" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $file" -ForegroundColor Red
        $allPresent = $false
    }
}

if (-not $allPresent) {
    Write-Host "[ERROR] 部分必要檔案缺失，部署中止。請重新執行此腳本。" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] 所有必要檔案驗證通過" -ForegroundColor Green

# ===== 步驟 4：執行部署 =====
Write-Host ""
Write-Host "[步驟 4/4] 開始執行 Golden Image 部署..." -ForegroundColor Cyan
Write-Host ""

$setupScript = Join-Path $WORK_DIR "setup.ps1"

# 設定執行策略（允許執行本機腳本）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force -ErrorAction SilentlyContinue

try {
    if ($SkipSysprep) {
        & $setupScript -ServerRole $ServerRole -ADDomain $ADDomain -SkipSysprep
    } else {
        & $setupScript -ServerRole $ServerRole -ADDomain $ADDomain
    }
} catch {
    Write-Host ""
    Write-Host "[ERROR] 部署過程發生錯誤：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        請查看日誌檔案：$WORK_DIR\Logs\" -ForegroundColor Yellow
    exit 1
}

# ===== 完成 =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  部署完成！" -ForegroundColor Green
Write-Host "  日誌位置：$WORK_DIR\Logs\" -ForegroundColor Green
Write-Host "  倉庫來源：$REPO_URL" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
