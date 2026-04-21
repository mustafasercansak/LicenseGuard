function Get-LGFlexLMStatus {
    <#
    .SYNOPSIS
        Queries FlexLM/FlexNet license servers defined in lg-config.json.
    .EXAMPLE
        Get-LGFlexLMStatus
    #>
    [CmdletBinding()]
    param()

    $L   = Get-LGEffectiveStrings
    $cfg = Get-LGEffectiveConfig
    Write-LGHeader $L['hdrFlexLM']

    if (-not $cfg.FlexLM -or $cfg.FlexLM.Count -eq 0) {
        Write-Host '  No FlexLM entries in configuration. Add them to lg-config.json.' -ForegroundColor DarkGray
        return @()
    }

    $lmutil = (Get-Command 'lmutil.exe' -ErrorAction SilentlyContinue)?.Source
    if (-not $lmutil) {
        $candidates = @(
            'C:\Program Files\FLEXlm\lmutil.exe'
            'C:\Program Files\Flexera Software\FlexNet Publisher\lmutil.exe'
            'C:\Program Files (x86)\Common Files\Macrovision Shared\FLEXnet Publisher\lmutil.exe'
        )
        $lmutil = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($entry in $cfg.FlexLM) {
        $name   = $entry.Name
        $server = $entry.Server
        if (-not $lmutil) {
            Write-LGStatus $name 'lmutil.exe not found' 'ERROR'
            $rows.Add([PSCustomObject]@{
                Module = 'FlexLM'; Name = $name; Server = $server; Status = 'ERROR'; Detail = 'lmutil.exe not found'
            })
            continue
        }
        try {
            $output = & $lmutil lmstat -a -c $server 2>&1 | Out-String
            if ($output -match 'license server UP') {
                $used = ([regex]::Matches($output, 'in use')).Count
                Write-LGStatus $name "Server UP -- $used feature(s) in use" 'OK'
                $rows.Add([PSCustomObject]@{
                    Module = 'FlexLM'; Name = $name; Server = $server
                    Status = 'OK'; Detail = "Server UP -- $used features active"
                })
            } elseif ($output -match 'Cannot connect|Connection refused|not respond') {
                Write-LGStatus $name "Cannot reach server: $server" 'ERROR'
                $rows.Add([PSCustomObject]@{
                    Module = 'FlexLM'; Name = $name; Server = $server; Status = 'ERROR'; Detail = 'Connection error'
                })
            } else {
                Write-LGStatus $name 'Unknown status' 'WARN'
                $rows.Add([PSCustomObject]@{
                    Module = 'FlexLM'; Name = $name; Server = $server; Status = 'WARN'; Detail = 'Unexpected output'
                })
            }
        } catch {
            Write-LGStatus $name 'lmutil execution error' 'ERROR'
            $rows.Add([PSCustomObject]@{
                Module = 'FlexLM'; Name = $name; Server = $server; Status = 'ERROR'; Detail = $_.Exception.Message
            })
        }
    }
    $rows
}
