# Đường dẫn file History của Edge (profile Default)
$edgeHistory = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"

if (Test-Path $edgeHistory) {
    Add-Type -AssemblyName System.Data

    # Tạo kết nối SQLite
    $cn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$edgeHistory;Version=3;")
    $cn.Open()

    # Lấy URL, tiêu đề, số lần truy cập, thời gian
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = "SELECT url, title, visit_count, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 50;"

    $rdr = $cmd.ExecuteReader()
    while ($rdr.Read()) {
        $url   = $rdr['url']
        $title = $rdr['title']
        $count = $rdr['visit_count']
        $time  = $rdr['last_visit_time']

        # Chuyển đổi Webkit timestamp sang DateTime
        $epoch = [DateTime]::FromFileTimeUtc(10*$time + 116444736000000000)

        Write-Output "$epoch | $count lần | $title | $url"
    }

    $cn.Close()
} else {
    Write-Output "Không tìm thấy file lịch sử Edge."
}
