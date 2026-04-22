function Get-LGBrowserExtensions {
    <#
    .SYNOPSIS
        Enumerates installed Chrome, Edge, and Firefox browser extensions.
    .EXAMPLE
        Get-LGBrowserExtensions
    #>
    [CmdletBinding()]
    param()

    $L = Get-LGEffectiveStrings
    Write-LGHeader $L['hdrBrowser']

    $rows = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($br in @(
        [PSCustomObject]@{ Tag = 'Chrome'; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions" }
        [PSCustomObject]@{ Tag = 'Edge';   Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions" }
    )) {
        if (-not (Test-Path $br.Path)) { continue }
        Get-ChildItem $br.Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $mf = Get-ChildItem $_.FullName -Filter 'manifest.json' -Recurse -Depth 2 `
                      -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $mf) { return }
            try {
                $m    = Get-Content $mf.FullName -Raw | ConvertFrom-Json
                $name = $m.name
                if ($name -like '__MSG_*') {
                    $key = $name -replace '^__MSG_|__$', ''
                    foreach ($loc in @('en_US','en','tr')) {
                        $lf = Join-Path (Split-Path $mf.FullName) "_locales\$loc\messages.json"
                        if (Test-Path $lf) {
                            $msgs = Get-Content $lf -Raw | ConvertFrom-Json
                            if ($msgs.$key?.message) { $name = $msgs.$key.message; break }
                        }
                    }
                    if ($name -like '__MSG_*') { $name = $_.Name }
                }
                Write-LGStatus "[$($br.Tag)] $name" "v$($m.version)" 'OK'
                $rows.Add([PSCustomObject]@{
                    Module  = 'BrowserExt'; Name = $name; Status = 'OK'
                    Detail  = "[$($br.Tag)] v$($m.version)"; Browser = $br.Tag
                    Version = $m.version; ComputerName = $env:COMPUTERNAME
                })
            } catch {}
        }
    }

    # Firefox
    $ffBase = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ffBase) {
        Get-ChildItem $ffBase -Directory |
            Where-Object { $_.Name -match '\.default' } |
            ForEach-Object {
                $extFile = Join-Path $_.FullName 'extensions.json'
                if (-not (Test-Path $extFile)) { return }
                try {
                    $exts = (Get-Content $extFile -Raw | ConvertFrom-Json).addons |
                                Where-Object { $_.type -eq 'extension' -and $_.location -ne 'app-builtin' }
                    foreach ($ext in $exts) {
                        $name = if ($ext.defaultLocale?.name) { $ext.defaultLocale.name } else { $ext.id }
                        Write-LGStatus "[Firefox] $name" "v$($ext.version)" 'OK'
                        $rows.Add([PSCustomObject]@{
                            Module  = 'BrowserExt'; Name = $name; Status = 'OK'
                            Detail  = "[Firefox] v$($ext.version)"; Browser = 'Firefox'
                            Version = $ext.version; ComputerName = $env:COMPUTERNAME
                        })
                    }
                } catch {}
            }
    }

    if ($rows.Count -eq 0) { Write-LGStatus 'Browser' 'No extensions found' 'OK' }
    $rows
}
