function Get-LGSignatureAudit {
    <#
    .SYNOPSIS
        Verifies Authenticode signatures for executables of prohibited/flagged software.
    .EXAMPLE
        $policy = Invoke-LGPolicyCheck -PolicyPath .\lg-policy.json
        Get-LGSignatureAudit -PolicyFindings $policy
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$PolicyFindings
    )

    $L = Get-LGEffectiveStrings
    Write-LGHeader $L['hdrSignature']

    $toCheck = @($PolicyFindings | Where-Object { $_.PolicyStatus -in @('PROHIBITED','REQUIRES_LICENSE') })
    if (-not $toCheck) {
        Write-LGStatus 'Signature check' 'Nothing to verify' 'OK'
        return @()
    }

    $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($sw in $toCheck) {
        $keyword = ($sw.Name -split '[\s\-_]+')[0]
        $exe     = Get-ChildItem 'C:\Program Files','C:\Program Files (x86)' `
                       -Filter "$keyword*.exe" -Recurse -Depth 3 `
                       -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) {
            $sig    = Get-AuthenticodeSignature $exe.FullName
            $status = switch ($sig.Status) { 'Valid' { 'OK' } 'NotSigned' { 'WARN' } default { 'EXPIRED' } }
            $subj   = if ($sig.SignerCertificate) {
                ($sig.SignerCertificate.Subject -replace 'CN=', '').Split(',')[0]
            } else { 'Unsigned' }
            Write-LGStatus $sw.Name "$($sig.Status) -- $subj" $status
            $rows.Add([PSCustomObject]@{
                Module    = 'Signature'; Name = $sw.Name; Status = $status
                Detail    = "$($sig.Status): $subj"; SignatureStatus = $sig.Status
                Signer    = $subj; ComputerName = $env:COMPUTERNAME
            })
        } else {
            $rows.Add([PSCustomObject]@{
                Module = 'Signature'; Name = $sw.Name; Status = 'WARN'
                Detail = 'Executable not found'; ComputerName = $env:COMPUTERNAME
            })
        }
    }
    $rows
}
