function Initialize-LicenseGuard {
    <#
    .SYNOPSIS
        Loads configuration and sets the active language for the module.
    .EXAMPLE
        Initialize-LicenseGuard -ConfigPath .\lg-config.json -Language en
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = '.\lg-config.json',
        [ValidateSet('tr','en')]
        [string]$Language   = 'tr'
    )

    $script:LGConfig  = $script:LGDefaultConfig.Clone()
    $script:LGStrings = Get-LGDefaultStrings -Language $Language

    if (Test-Path $ConfigPath) {
        try {
            $loaded = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $keys = @(
                'FlexLM','SaaS','WarnDaysBeforeExpiry','Whitelist','SnapshotPath',
                'EolCheck','Email','Webhook','Jira','Branding',
                'ScanBrowserExtensions','ScanVsCodeExtensions','ScanStartup'
            )
            foreach ($k in $keys) {
                if ($null -ne $loaded.$k) { $script:LGConfig[$k] = $loaded.$k }
            }
            Write-Verbose "Configuration loaded: $ConfigPath"
        } catch {
            Write-Warning "Could not read configuration: $($_.Exception.Message)"
        }
    }
}
