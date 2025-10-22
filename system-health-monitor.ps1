<#
System Health Monitor
------------------------------------------------------------
This PowerShell script monitors key system performance metrics:
- CPU utilization
- Memory usage
- Disk space
- Network throughput (Mbps)

It logs all readings to a CSV file and records alerts for values
that exceed defined warning thresholds.
Ideal for Help Desk or Cybersecurity monitoring scripts.
#>

# === PARAMETERS ===
# User-configurable settings with default values
param(
  [string]$OutputPath = ".\health_log.csv",   # CSV file for regular logs
  [int]$SampleInterval = 1,                   # Sampling interval (seconds)
  [int]$CpuWarn = 85,                         # CPU % threshold for warning
  [int]$MemWarn = 85,                         # Memory % threshold for warning
  [int]$DiskFreeWarnGB = 5,                   # Minimum free disk space in GB
  [int]$NetWarnMbps = 200                     # Network throughput warning (Mbps)
)

# === FUNCTION: CPU USAGE ===
# Reads CPU usage using performance counters.
function Get-Cpu() { 
  (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval $SampleInterval -MaxSamples 1).CounterSamples.CookedValue 
}

# === FUNCTION: MEMORY USAGE ===
# Returns total, used, and free memory (in MB) plus percentage used.
function Get-Mem() { 
  $os = Get-CimInstance Win32_OperatingSystem
  $t = [math]::Round($os.TotalVisibleMemorySize / 1024, 2)
  $f = [math]::Round($os.FreePhysicalMemory / 1024, 2)
  $u = [math]::Round($t - $f, 2)
  $p = if ($t) { [math]::Round(($u / $t) * 100, 2) } else { 0 }
  [pscustomobject]@{
    TotalMB = $t
    UsedMB  = $u
    FreeMB  = $f
    PctUsed = $p
  }
}

# === FUNCTION: DISK USAGE ===
# Gets details for all logical drives (DriveType = 3 means local disks).
# Calculates used, free, and total space in GB and percentage used.
function Get-Disks() { 
  Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | ForEach-Object {
    $s = [math]::Round($_.Size / 1GB, 2)
    $f = [math]::Round($_.FreeSpace / 1GB, 2)
    $u = [math]::Round($s - $f, 2)
    $p = if ($s) { [math]::Round(($u / $s) * 100, 2) } else { 0 }
    [pscustomobject]@{
      Drive   = $_.DeviceID
      SizeGB  = $s
      UsedGB  = $u
      FreeGB  = $f
      PctUsed = $p
    }
  }
}

# === FUNCTION: NETWORK THROUGHPUT ===
# Measures total bytes sent/received across all interfaces and converts to Mbps.
function Get-Net() { 
  $s = (Get-Counter '\Network Interface(*)\Bytes Total/sec' -SampleInterval $SampleInterval -MaxSamples 1).CounterSamples
  if (-not $s) { return 0 }
  $bps = ($s | Measure-Object -Property CookedValue -Sum).Sum
  [math]::Round(($bps * 8) / 1MB, 2)
}

# === FUNCTION: ALERT LOGGING ===
# Writes alerts to a separate ".alerts.log" file with timestamps.
function Alert($m) { 
  $p = [System.IO.Path]::ChangeExtension($OutputPath, ".alerts.log")
  "$((Get-Date).ToString('s')) | $m" | Out-File -Append -FilePath $p -Encoding UTF8
  Write-Host "[ALERT] $m"
}

# === MAIN DATA COLLECTION ===
# Capture timestamp and system metrics
$ts = (Get-Date).ToString("s")
$cpu = [math]::Round((Get-Cpu), 2)
$mem = Get-Mem
$disks = Get-Disks
$net = Get-Net

# === ALERT CONDITIONS ===
# Trigger alerts for any resource exceeding thresholds
if ($cpu -ge $CpuWarn) { 
  Alert "High CPU usage: $cpu% (>= $CpuWarn%)" 
}
if ($mem.PctUsed -ge $MemWarn) { 
  Alert "High Memory usage: $($mem.PctUsed)% (>= $MemWarn%)" 
}
$disks | ForEach-Object { 
  if ($_.FreeGB -le $DiskFreeWarnGB) { 
    Alert "Low Disk Space: $($_.Drive) has $($_.FreeGB) GB free (<= $DiskFreeWarnGB GB)" 
  } 
}
if ($net -ge $NetWarnMbps) { 
  Alert "High Network Throughput: $net Mbps (>= $NetWarnMbps Mbps)" 
}

# === CREATE CSV HEADER IF NEEDED ===
if (-not (Test-Path $OutputPath)) { 
  "Timestamp,CPU_Percent,Mem_Total_MB,Mem_Used_MB,Mem_Free_MB,Mem_Pct_Used,Net_Mbps,Disk_Free_Summary" | 
    Out-File $OutputPath -Encoding UTF8 
}

# === BUILD DISK SUMMARY STRING ===
$driveSummary = ($disks | ForEach-Object { "$($_.Drive)=$($_.FreeGB)GB" }) -join ';'

# === APPEND DATA TO LOG ===
"$ts,$cpu,$($mem.TotalMB),$($mem.UsedMB),$($mem.FreeMB),$($mem.PctUsed),$net,$driveSummary" | 
  Out-File -Append -FilePath $OutputPath -Encoding UTF8

# === OUTPUT TO CONSOLE ===
Write-Output "[$ts] CPU=$cpu% | Mem=$($mem.PctUsed)% | Net=$net Mbps | Disks: $driveSummary"
