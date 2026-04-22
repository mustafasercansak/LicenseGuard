function Get-LGSaaSStatus {
    <#
    .SYNOPSIS
        Pings SaaS / API key endpoints defined in lg-config.json.
    .EXAMPLE
        Get-LGSaaSStatus
    #>
    [CmdletBinding()]
    param()

    $L   = Get-LGEffectiveStrings
    $cfg = Get-LGEffectiveConfig
    Write-LGHeader $L['hdrSaaS']

    if (-not $cfg.SaaS -or $cfg.SaaS.Count -eq 0) {
        Write-Host '  No SaaS entries in configuration. Add them to lg-config.json.' -ForegroundColor DarkGray
        return @()
    }

    $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($svc in $cfg.SaaS) {
        $name     = $svc.Name
        $endpoint = $svc.Endpoint
        $expect   = if ($svc.ExpectStatus) { [int]$svc.ExpectStatus } else { 200 }
        try {
            $headers = @{ $svc.Header = $svc.Key }
            $resp    = Invoke-WebRequest -Uri $endpoint -Headers $headers -Method GET `
                           -TimeoutSec 10 -UseBasicParsing
            if ($resp.StatusCode -eq $expect) {
                Write-LGStatus $name "HTTP $($resp.StatusCode) -- Active" 'OK'
                $rows.Add([PSCustomObject]@{
                    Module = 'SaaS'; Name = $name; Endpoint = $endpoint
                    Status = 'OK'; Detail = "HTTP $($resp.StatusCode)"
                })
            } else {
                Write-LGStatus $name "HTTP $($resp.StatusCode) -- Unexpected" 'WARN'
                $rows.Add([PSCustomObject]@{
                    Module = 'SaaS'; Name = $name; Endpoint = $endpoint
                    Status = 'WARN'; Detail = "HTTP $($resp.StatusCode)"
                })
            }
        } catch {
            $httpCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            $detail   = switch ($httpCode) {
                401     { '401 Unauthorized -- API key invalid/expired' }
                403     { '403 Forbidden -- Insufficient permissions'   }
                0       { "Connection error: $($_.Exception.Message)"  }
                default { "HTTP $httpCode" }
            }
            $status = if ($httpCode -in @(401, 403)) { 'EXPIRED' } else { 'ERROR' }
            Write-LGStatus $name $detail $status
            $rows.Add([PSCustomObject]@{
                Module = 'SaaS'; Name = $name; Endpoint = $endpoint; Status = $status; Detail = $detail
            })
        }
    }
    $rows
}
