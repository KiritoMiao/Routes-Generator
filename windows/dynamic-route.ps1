# Script to dynamically update BIRD routing configuration based on active connections
# Usage: ./dynamic-route.ps1 [-Verbose] [-DryRun] [-Dynamic]

param (
    [switch]$Verbose,
    [switch]$DryRun,
    [switch]$Dynamic
)

# CONFIGURATION
$ProcessNames = @("chrome.exe", "ssh.exe")  # Replace with your target processes
$interface = "eth0"                        # Interface for bird config
$tempFile = "$env:TEMP\bird-routes.conf"  # Temp local file
$remoteUser = ""                   # SSH user
$remoteHost = ""            # SSH host
$remotePath = "/etc/bird/bird-dynamic-ips.conf"  # Target file on server
$sshPort = 22                              # SSH port
$birdReloadCommand = "dos2unix $remotePath && birdc configure"     # Remote reload command
$dynamicInterval = 10                    # Dynamic interval in seconds


# Function to output information based on verbosity level
function Write-Information {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info", "Verbose", "Warning", "Error")]
        [string]$Level = "Info",

        [Parameter(Mandatory=$false)]
        [string]$Module = "Undefined"

    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Level) {
        
        "Info" {
            # Always output Info level messages
            Write-Host "ℹ️ [${timestamp}][${Module}]: $Message"
        }
        "Verbose" {
            # Only output if Verbose switch is enabled
            if ($Verbose) {
                Write-Host "🔍 [${timestamp}][${Module}]: $Message" -ForegroundColor Cyan
            }
        }
        "Warning" {
            Write-Host "⚠️ [${timestamp}][${Module}]: $Message" -ForegroundColor Yellow
        }
        "Error" {
            Write-Host "❌ [${timestamp}][${Module}]: $Message" -ForegroundColor Red
        }
    }
}

function Get-TargetProcess {
    param (
        [Parameter(Mandatory=$true)]
        [string]$processName
    )
    Write-Information "Getting PIDs for $processName" -Level "Verbose" -Module "Process Finder"
    return Get-Process | Where-Object { $_.ProcessName -eq ($processName -replace ".exe$", "") } | Select-Object -ExpandProperty Id
}

function Get-AllTargetProcesses {
    $allPids = @()
    foreach ($proc in $ProcessNames) {
        $pids = Get-TargetProcess -processName $proc
        $allPids += $pids

        Write-Information "Found $($pids.Count) instances of $proc, PIDs: $($pids)" -Level "Verbose" -Module "Process Finder"
    }
        
    Write-Information "All target processes PIDs: $($allPids)" -Level "Verbose" -Module "Process Finder"
    return $allPids
}

function Get-ConnectedIPs {
    param (
        [Parameter(Mandatory=$true)]
        [array]$ProcessIds
    )
    
    Write-Information "Gathering connected remote IPs" -Level "Verbose" -Module "IP Scanner"
    
    # Gather all connected remote IPs
    $ips = @()
    foreach ($procId in $ProcessIds) {
        $conns = Get-NetTCPConnection | Where-Object {
            $_.OwningProcess -eq $procId -and $_.State -eq 'Established'
        }
        $ips += $conns.RemoteAddress
    }
    # Filter for valid IPv4 addresses and remove duplicates
    $ips = $ips | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' } | Sort-Object -Unique
    Write-Information "Found $($ips.Count) unique IPs" -Level "Info" -Module "IP Scanner"
    Write-Information "IPs: $($ips)" -Level "Verbose" -Module "IP Scanner"
    return $ips
}

function New-BirdRouteConfig {
    param (
        [Parameter(Mandatory=$true)]
        [array]$IPs,
        
        [Parameter(Mandatory=$true)]
        [string]$Interface,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputFile
    )
    
    $routes = $IPs | ForEach-Object { "route $_/32 via `"$Interface`";" }
    Set-Content -Path $OutputFile -Value $routes
    Write-Information "Generated route file: $OutputFile" -Level "Verbose" -Module "Bird Config Generator"
}

function Invoke-Command {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$false)]
        [string]$Description = "command"
    )
    
    Write-Information "Executing ${Description}: $Command" -Level "Verbose" -Module "Command Executor"
    
    if ($DryRun) {
        Write-Information "DRY RUN: Would execute: $Command" -Level "Warning" -Module "Command Executor"
        return "DRY RUN - Command execution skipped"
    } else {
        $output = Invoke-Expression $Command 2>&1
        Write-Information "Command Output: $output" -Level "Verbose" -Module "Command Executor"
        return $output
    }
}

function Send-FileToRemoteServer {
    param (
        [Parameter(Mandatory=$true)]
        [string]$LocalFile,
        
        [Parameter(Mandatory=$true)]
        [string]$RemoteHost,
        
        [Parameter(Mandatory=$true)]
        [string]$RemoteUser,
        
        [Parameter(Mandatory=$true)]
        [string]$RemotePath,
        
        [Parameter(Mandatory=$true)]
        [int]$SshPort
    )
    
    $scpCmd = "scp -P $SshPort `"$LocalFile`" ${RemoteUser}@${RemoteHost}:`"$RemotePath`""
    Write-Information "Uploading to server..." -Level "Verbose" -Module "File Uploader"
    Write-Information "Executing: $scpCmd" -Level "Verbose" -Module "File Uploader"
    $output = Invoke-Command -Command $scpCmd -Description "SCP"
    Write-Information "SCP Output: $output" -Level "Verbose" -Module "File Uploader"
}

function Invoke-RemoteBirdReload {
    param (
        [Parameter(Mandatory=$true)]
        [string]$RemoteHost,
        
        [Parameter(Mandatory=$true)]
        [string]$RemoteUser,
        
        [Parameter(Mandatory=$true)]
        [string]$BirdReloadCommand,
        
        [Parameter(Mandatory=$true)]
        [int]$SshPort
    )
    
    $sshCmd = "ssh -p $SshPort ${RemoteUser}@${RemoteHost} '$BirdReloadCommand'"
    Write-Information "Reloading bird remotely..." -Level "Verbose" -Module "Bird Reloader"
    Write-Information "Executing: $sshCmd" -Level "Verbose" -Module "Bird Reloader"
    $output = Invoke-Command -Command $sshCmd -Description "SSH"
    if ($LASTEXITCODE -ne 0) {
        Write-Information "SSH command failed with exit code $LASTEXITCODE" -Level "Error" -Module "Bird Reloader"
    }
    Write-Information "SSH Output: $output" -Level "Verbose" -Module "Bird Reloader"
    Write-Information "Remote BIRD config updated and reloaded." -Level "Info" -Module "Bird Reloader"

}

function Merge-IPs {
    param (
        [Parameter(Mandatory=$true)]
        [array]$IPs,
        
        [Parameter(Mandatory=$false)]
        [array]$PriviousIPs = @()
    )
    
    $mergedIPs = $IPs + $PriviousIPs
    # deduplicate the merged IPs
    $mergedIPs = $mergedIPs | Sort-Object -Unique
    # check if the merged IPs are the same as the previous IPs
    if (($null -ne $PriviousIPs) -and (Compare-Object $mergedIPs $PriviousIPs -SyncWindow 0).Count -eq 0) {
        Write-Information "No new IPs to add" -Level "Verbose" -Module "IP Merger"
        return $PriviousIPs, '0'
    } else {
        $newIPs = if ($null -ne $PriviousIPs -and $PriviousIPs.Count -gt 0) {
            Compare-Object $mergedIPs $PriviousIPs | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject
        } else {
            $mergedIPs
        }
        Write-Information "New IPs to add: $newIPs" -Level "Verbose" -Module "IP Merger"
        return $mergedIPs, '1'
    }
}


Write-Information "Windows Dynamic Route Script" -Level "Info" -Module "Core"
Write-Information "Author: @KiritoMiao" -Level "Info" -Module "Core"
Write-Information "Version: 1.0.0" -Level "Info" -Module "Core"
Write-Information "Date: $(Get-Date -Format 'yyyy-MM-dd')" -Level "Info" -Module "Core"
# if verbose or debug is enabled, output the current date and time using the Write-Information function
Write-Information "Verbose is enabled" -Level "Verbose" -Module "Core"

if (-not $Dynamic) {
    Write-Information "Static mode is enabled" -Level "Info" -Module "Core"
    $allPids = Get-AllTargetProcesses

    # Get connected IPs for the target process
    $ips = Get-ConnectedIPs -ProcessIds $allPids
    # Generate and deploy BIRD configuration
    New-BirdRouteConfig -IPs $ips -Interface $interface -OutputFile $tempFile
    Send-FileToRemoteServer -LocalFile $tempFile -RemoteHost $remoteHost -RemoteUser $remoteUser -RemotePath $remotePath -SshPort $sshPort
    Invoke-RemoteBirdReload -RemoteHost $remoteHost -RemoteUser $remoteUser -BirdReloadCommand $birdReloadCommand -SshPort $sshPort
    Write-Information "Done. Remote BIRD config updated and reloaded." -Level "Info" -Module "Core"
} else {
    Write-Information "Dynamic mode is enabled" -Level "Info" -Module "Core"
    # Start a while loop to check if the target process is running
    $PriviousIPs = @()
    while ($true) {
        $allPids = Get-AllTargetProcesses
        $ips = Get-ConnectedIPs -ProcessIds $allPids
        $mergedIPs, $IPsChanged = Merge-IPs -IPs $ips -PriviousIPs $PriviousIPs
        $PriviousIPs = $mergedIPs
        if ($IPsChanged -eq '1') {
            # Generate and deploy BIRD configuration
            New-BirdRouteConfig -IPs $ips -Interface $interface -OutputFile $tempFile
            Send-FileToRemoteServer -LocalFile $tempFile -RemoteHost $remoteHost -RemoteUser $remoteUser -RemotePath $remotePath -SshPort $sshPort
            Invoke-RemoteBirdReload -RemoteHost $remoteHost -RemoteUser $remoteUser -BirdReloadCommand $birdReloadCommand -SshPort $sshPort
        }
        Start-Sleep -Seconds $dynamicInterval
    }
}





