[![Language](https://img.shields.io/badge/lang-PowerShell-1f5aa6.svg)]() [![License](https://img.shields.io/badge/license-MIT-green.svg)]() [![Status](https://img.shields.io/badge/status-active-success.svg)]()

# System Health Monitor (PowerShell)
Logs CPU, memory, disk, and network metrics to CSV and writes threshold-based alerts.

## How to Run
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\system-health-monitor.ps1 -OutputPath .\health_log.csv -CpuWarn 90 -MemWarn 90
```
