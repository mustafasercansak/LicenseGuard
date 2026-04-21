function Get-LGVsCodeExtensions {
    <#
    .SYNOPSIS
        Lists installed VS Code extensions from the user profile.
    .EXAMPLE
        Get-LGVsCodeExtensions
    #>
    [CmdletBinding()]
    param()

    $L = Get-LGEffectiveStrings
    Write-LGHeader $L['hdrVsCode']

    $extPath = "$env:USERPROFILE\.vscode\extensions"
    $rows    = [System.Collections.Generic.List[PSCustomObject]]::new()

    if (-not (Test-Path $extPath)) {
        Write-LGStatus 'VS Code' 'Extensions folder not found' 'OK'
        return $rows
    }

    Get-ChildItem $extPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $pkg = Join-Path $_.FullName 'package.json'
        if (-not (Test-Path $pkg)) { return }
        try {
            $p    = Get-Content $pkg -Raw | ConvertFrom-Json
            $name = if ($p.displayName) { $p.displayName } else { $p.name }
            Write-LGStatus $name "v$($p.version) -- $($p.publisher)" 'OK'
            $rows.Add([PSCustomObject]@{
                Module    = 'VSCodeExt'; Name = $name; Status = 'OK'
                Detail    = "$($p.publisher) v$($p.version)"
                Publisher = $p.publisher; Version = $p.version
                ComputerName = $env:COMPUTERNAME
            })
        } catch {
            $rows.Add([PSCustomObject]@{
                Module = 'VSCodeExt'; Name = $_.Name; Status = 'OK'; Detail = '-'
                ComputerName = $env:COMPUTERNAME
            })
        }
    }

    if ($rows.Count -eq 0) { Write-LGStatus 'VS Code' 'No extensions found' 'OK' }
    $rows
}
