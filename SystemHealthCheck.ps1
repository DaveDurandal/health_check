# PowerShell Automated System Health Check Script

# Function to check disk space
function Get-DiskSpace {
    Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $freeSpacePercent = [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
        [PSCustomObject]@{
            Drive = $_.DeviceID
            FreeSpacePercent = $freeSpacePercent
            FreeSpace = [math]::Round($_.FreeSpace / 1GB, 2)
            TotalSpace = [math]::Round($_.Size / 1GB, 2)
        }
    }
}

# Function to check CPU usage
function Get-CPUUsage {
    $cpu = Get-WmiObject Win32_Processor
    [PSCustomObject]@{
        CPULoad = $cpu.LoadPercentage
        CPUName = $cpu.Name
    }
}

# Function to check memory usage
function Get-MemoryUsage {
    $os = Get-CimInstance Win32_OperatingSystem
    $memoryUsage = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 2)
    [PSCustomObject]@{
        MemoryUsagePercent = $memoryUsage
        FreeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        TotalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    }
}

# Function to check running processes
function Get-TopProcesses {
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            CPU = $_.CPU
            MemoryMB = [math]::Round($_.WorkingSet / 1MB, 2)
        }
    }
}

# Function to check network connectivity
function Test-NetworkConnectivity {
    $testResults = Test-NetConnection -ComputerName "www.google.com" -InformationLevel Quiet
    [PSCustomObject]@{
        InternetConnected = $testResults
    }
}

# Function to check Windows Update status
function Get-WindowsUpdateStatus {
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $pendingUpdates = $updateSearcher.Search("IsInstalled=0").Updates.Count
        [PSCustomObject]@{
            PendingUpdates = $pendingUpdates
        }
    }
    catch {
        [PSCustomObject]@{
            PendingUpdates = "Unable to check (might require elevation)"
        }
    }
}

# Main function to run all checks
function Invoke-SystemHealthCheck {
    $results = [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Date = Get-Date
        DiskSpace = Get-DiskSpace
        CPUInfo = Get-CPUUsage
        MemoryInfo = Get-MemoryUsage
        TopProcesses = Get-TopProcesses
        NetworkConnectivity = Test-NetworkConnectivity
        WindowsUpdateStatus = Get-WindowsUpdateStatus
    }

    # Output results
    $results | ConvertTo-Json -Depth 4 | Out-File "SystemHealthCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    Write-Output "System Health Check completed. Results saved to JSON file."
    
    # Display summary
    Write-Output "`nSystem Health Summary:"
    Write-Output "----------------------"
    Write-Output "Disk Space:"
    $results.DiskSpace | Format-Table -AutoSize
    Write-Output "`nCPU Usage: $($results.CPUInfo.CPULoad)%"
    Write-Output "Memory Usage: $($results.MemoryInfo.MemoryUsagePercent)%"
    Write-Output "`nTop 5 CPU-consuming processes:"
    $results.TopProcesses | Format-Table -AutoSize
    Write-Output "Internet Connected: $($results.NetworkConnectivity.InternetConnected)"
    Write-Output "Pending Windows Updates: $($results.WindowsUpdateStatus.PendingUpdates)"
}

# Run the health check
Invoke-SystemHealthCheck
