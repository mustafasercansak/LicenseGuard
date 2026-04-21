function Get-LGStartupAudit {
    <#
    .SYNOPSIS
        Lists programs registered to run at startup (registry + Startup folders).
    .EXAMPLE
        Get-LGStartupAudit
    #>
    [CmdletBinding()]
    param()

    $L    = Get-LGEffectiveStrings
    $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
    Write-LGHeader $L['hdrStartup']

    foreach ($entry in @(
        [PSCustomObject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';     Scope = 'HKLM' }
        [PSCustomObject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Scope = 'HKLM-Once' }
        [PSCustomObject]@{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';     Scope = 'HKCU' }
        [PSCustomObject]@{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Scope = 'HKCU-Once' }
    )) {
        if (-not (Test-Path $entry.Path)) { continue }
        Get-ItemProperty $entry.Path | ForEach-Object {
            $_.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
                Write-LGStatus $_.Name "[$($entry.Scope)]" 'OK'
                $rows.Add([PSCustomObject]@{
                    Module = 'Startup'; Name = $_.Name; Status = 'OK'
                    Detail = "[$($entry.Scope)] $($_.Value)"; Scope = $entry.Scope
                    ComputerName = $env:COMPUTERNAME
                })
            }
        }
    }

    foreach ($folder in @(
        [PSCustomObject]@{ Path = [Environment]::GetFolderPath('Startup');       Scope = 'User' }
        [PSCustomObject]@{ Path = [Environment]::GetFolderPath('CommonStartup'); Scope = 'AllUsers' }
    )) {
        if (-not (Test-Path $folder.Path)) { continue }
        Get-ChildItem $folder.Path -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @('.lnk','.exe','.bat','.cmd','.vbs') } |
            ForEach-Object {
                Write-LGStatus $_.BaseName "[Folder-$($folder.Scope)]" 'OK'
                $rows.Add([PSCustomObject]@{
                    Module = 'Startup'; Name = $_.BaseName; Status = 'OK'
                    Detail = "[Folder-$($folder.Scope)] $($_.FullName)"; Scope = "Folder-$($folder.Scope)"
                    ComputerName = $env:COMPUTERNAME
                })
            }
    }

    if ($rows.Count -eq 0) { Write-LGStatus 'Startup' 'No entries found' 'OK' }
    $rows
}
