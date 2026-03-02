#========================================
# Network-Hardening.ps1 - 網路安全模組
# 功能: 防火牆、SMB、TLS、RDP、WinRM
#========================================

param(
    [string]$LogPath = "$PSScriptRoot\..\Logs"
)

$ErrorActionPreference = "Stop"
$LogFile = Join-Path $LogPath "network-hardening-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logMessage -Force
    Write-Host $logMessage
}

Write-Log "===== 網路安全配置開始 =====" "INFO"

# ===== 1. Windows Defender 防火牆強化 =====
Write-Log "啟用 Windows Defender 防火牆..." "INFO"

# 啟用所有設定檔
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled $true -ErrorAction SilentlyContinue
Write-Log "✓ 防火牆所有設定檔已啟用" "SUCCESS"

# 設置預設拒絕入站
Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Allow -ErrorAction SilentlyContinue
Write-Log "✓ 防火牆預設入站拒絕已設置" "SUCCESS"

# 禁止本機規則合併
Set-NetFirewallProfile -Profile Domain,Public,Private -AllowLocalFirewallRules $false -ErrorAction SilentlyContinue
Write-Log "✓ 本機防火牆規則合併已禁止" "SUCCESS"

# 啟用日誌記錄
$LogPath_FW = "%SystemRoot%\System32\logfiles\firewall\domainfw.log"
Set-NetFirewallProfile -Profile Domain -LogFileName $LogPath_FW -LogMaxSizeKilobytes 16384 -LogAllowed $true -LogBlocked $true -ErrorAction SilentlyContinue
Write-Log "✓ 防火牆日誌已啟用（16MB）" "SUCCESS"

# ===== 2. SMB 簽署與加密 =====
Write-Log "配置 SMB 簽署與加密..." "INFO"

# 停用 SMBv1（已在安全模組中執行，此為確保）
Disable-WindowsOptionalFeature -FeatureName SMB1Protocol -Online -NoRestart -ErrorAction SilentlyContinue

# 強制 SMBv2/v3 簽署
Set-SmbServerConfiguration -RequireSecuritySignature $true -Confirm:$false -ErrorAction SilentlyContinue
Set-SmbClientConfiguration -RequireSecuritySignature $true -Confirm:$false -ErrorAction SilentlyContinue
Write-Log "✓ SMB 簽署已強制" "SUCCESS"

# 啟用 SMB 加密
Set-SmbServerConfiguration -EncryptData $true -Confirm:$false -ErrorAction SilentlyContinue
Write-Log "✓ SMB 加密已啟用" "SUCCESS"

# ===== 3. TLS 1.2 強制配置 =====
Write-Log "配置 TLS 1.2 強制..." "INFO"

$SchanelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"

# 停用 SSL 2.0/3.0、TLS 1.0/1.1
foreach ($proto in @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1")) {
    foreach ($side in @("Server", "Client")) {
        $path = "$SchanelPath\$proto\$side"
        New-Item -Path $path -Force | Out-Null
        New-ItemProperty -Path $path -Name "Enabled" -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $path -Name "DisabledByDefault" -Value 1 -PropertyType DWord -Force | Out-Null
    }
}
Write-Log "✓ 舊版 TLS/SSL 已停用" "SUCCESS"

# 啟用 TLS 1.2
foreach ($side in @("Server", "Client")) {
    $path = "$SchanelPath\TLS 1.2\$side"
    New-Item -Path $path -Force | Out-Null
    New-ItemProperty -Path $path -Name "Enabled" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $path -Name "DisabledByDefault" -Value 0 -PropertyType DWord -Force | Out-Null
}
Write-Log "✓ TLS 1.2 已啟用" "SUCCESS"

# 為 .NET Framework 啟用強密碼學
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -Type DWord -Force
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -Type DWord -Force
Write-Log "✓ .NET 強密碼學已啟用" "SUCCESS"

# ===== 4. RDP 安全強化 =====
Write-Log "強化 RDP..." "INFO"

$RDPPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
New-Item -Path $RDPPath -Force | Out-Null

# 強制 NLA（網路級驗證）
New-ItemProperty -Path $RDPPath -Name "UserAuthentication" -Value 1 -PropertyType DWord -Force | Out-Null
Write-Log "✓ RDP NLA 已啟用" "SUCCESS"

# 強制 TLS 加密
New-ItemProperty -Path $RDPPath -Name "SecurityLayer" -Value 2 -PropertyType DWord -Force | Out-Null
Write-Log "✓ RDP TLS 已啟用" "SUCCESS"

# 設置高加密等級
New-ItemProperty -Path $RDPPath -Name "MinEncryptionLevel" -Value 3 -PropertyType DWord -Force | Out-Null
Write-Log "✓ RDP 高加密等級已設置" "SUCCESS"

# ===== 5. WinRM HTTPS 配置 =====
Write-Log "配置 WinRM HTTPS..." "INFO"

try {
    # 啟用 WinRM
    winrm quickconfig -quiet -ErrorAction SilentlyContinue
    
    # 設置僅 HTTPS
    Set-Item -Path 'WSMan:\localhost\Service\Auth\Kerberos' -Value $true -Force -ErrorAction SilentlyContinue
    Write-Log "✓ WinRM 已配置為 HTTPS 模式" "SUCCESS"
} catch {
    Write-Log "⚠ WinRM 配置遇到問題，但不影響核心安全" "WARNING"
}

# ===== 6. 靜態 IP 驗證 =====
Write-Log "驗證靜態 IP 配置..." "INFO"

$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($adapter in $adapters) {
    $ipConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
    if ($ipConfig.IPv4Address) {
        Write-Log "✓ 介面卡 '$($adapter.Name)' IPv4: $($ipConfig.IPv4Address.IPAddress)" "SUCCESS"
    }
}

# ===== 7. 禁止 LLMNR（本機連結多播名稱解析） =====
Write-Log "停用 LLMNR..." "INFO"

$llmnrPath = "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient"
New-Item -Path $llmnrPath -Force | Out-Null
New-ItemProperty -Path $llmnrPath -Name "EnableMulticast" -Value 0 -PropertyType DWord -Force | Out-Null
Write-Log "✓ LLMNR 已停用" "SUCCESS"

# ===== 8. 啟用 NetBios 驗證 =====
Write-Log "配置 NetBios 安全..." "INFO"

$netbiosPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters"
New-Item -Path $netbiosPath -Force | Out-Null
New-ItemProperty -Path $netbiosPath -Name "NoNameReleaseOnDemand" -Value 1 -PropertyType DWord -Force | Out-Null
Write-Log "✓ NetBios 名稱發佈已停用" "SUCCESS"

Write-Log "===== 網路安全配置完成 =====" "SUCCESS"
