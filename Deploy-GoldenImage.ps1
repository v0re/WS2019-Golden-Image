#========================================
# Deploy-GoldenImage.ps1 - 一鍵部署啟動腳本
# 版本: v1.0.2-Final
# 說明: 自動從 GitHub 下載最新版本並執行部署
#       無需 Git 安裝，無需金鑰，直接執行即可
# 使用方式:
#   以管理員身分執行 PowerShell，然後貼上以下指令：
#   irm https://raw.githubusercontent.com/v0re/WS2019-Golden-Image/master/Deploy-GoldenImage.ps1 | iex
#========================================

param(
    [ValidateSet("Member", "DomainController", "Standalone")]
    [string]$ServerRole = "Member",
    [string]$ADDomain = "domain.local",
    [switch]$SkipSysprep = $false,
    [string]$InstallPath = "C:\WS2019-Deploy"
)

# ===== 顯示橫幅 =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Windows Server 2019 Golden Image" -ForegroundColor Cyan
Write-Host "  一鍵自動部署腳本 v1.0.2-Final" -ForegroundColor Cyan
Write-Host "  https://github.com/v0re/WS2019-Golden-Image" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ===== 檢查管理員權限 =====
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] 請以「系統管理員身分」執行 PowerShell 後再重新執行此腳本！" -ForegroundColor Red
    Write-Host "        右鍵點擊 PowerShell -> 以系統管理員身分執行" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] 管理員權限確認" -ForegroundColor Green

# ===== 設定下載來源 =====
$REPO_URL  = "https://github.com/v0re/WS2019-Golden-Image"
$ZIP_URL   = "https://github.com/v0re/WS2019-Golden-Image/archive/refs/heads/master.zip"
$ZIP_PATH  = "$env:TEMP\WS2019-Golden-Image.zip"
$EXTRACT   = "$env:TEMP\WS2019-Extract"
$WORK_DIR  = "$InstallPath"

Write-Host ""
Write-Host "[INFO] 部署設定：" -ForegroundColor Cyan
Write-Host "  伺服器角色  : $ServerRole"
Write-Host "  AD 域名     : $(if ($ServerRole -eq 'Standalone') { '(不適用)' } else { $ADDomain })"
Write-Host "  安裝路徑    : $WORK_DIR"
Write-Host "  跳過 Sysprep: $SkipSysprep"
Write-Host "  來源倉庫    : $REPO_URL"
Write-Host ""

# ===== 確認執行 =====
Write-Host "即將開始部署，此操作將強化系統安全設定。" -ForegroundColor Yellow
Write-Host "按 Enter 繼續，或 Ctrl+C 取消..." -ForegroundColor Yellow
Read-Host | Out-Null

# ===== 步驟 1：下載最新版本 =====
Write-Host ""
Write-Host "[步驟 1/4] 從 GitHub 下載最新版本..." -ForegroundColor Cyan

# 清理舊版本
if (Test-Path $EXTRACT) { Remove-Item -Path $EXTRACT -Recurse -Force }
if (Test-Path $ZIP_PATH) { Remove-Item -Path $ZIP_PATH -Force }

try {
    # 設定 TLS 1.2 以確保 HTTPS 下載正常
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $ZIP_URL -OutFile $ZIP_PATH -UseBasicParsing
    Write-Host "[OK] 下載完成" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 下載失敗：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        請確認網路連線正常，並可存取 github.com" -ForegroundColor Yellow
    exit 1
}

# ===== 步驟 2：解壓縮 =====
Write-Host ""
Write-Host "[步驟 2/4] 解壓縮檔案..." -ForegroundColor Cyan

try {
    Expand-Archive -Path $ZIP_PATH -DestinationPath $EXTRACT -Force

    # 找到解壓縮後的資料夾（GitHub 會加上 -master 後綴）
    $extractedFolder = Get-ChildItem -Path $EXTRACT -Directory | Select-Object -First 1

    if (-not $extractedFolder) {
        Write-Host "[ERROR] 解壓縮失敗，找不到資料夾" -ForegroundColor Red
        exit 1
    }

    # 複製到工作目錄（複製資料夾「內容」，而非資料夾本身，避免多一層路徑）
    if (Test-Path $WORK_DIR) { Remove-Item -Path $WORK_DIR -Recurse -Force }
    New-Item -ItemType Directory -Path $WORK_DIR -Force | Out-Null
    Get-ChildItem -Path $extractedFolder.FullName | Copy-Item -Destination $WORK_DIR -Recurse -Force

    Write-Host "[OK] 解壓縮完成，檔案位於：$WORK_DIR" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 解壓縮失敗：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
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
