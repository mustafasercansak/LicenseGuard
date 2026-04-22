function Get-LGADComputers {
    <#
    .SYNOPSIS
        Retrieves computer names from Active Directory for use with Invoke-LGRemoteScan.

    .DESCRIPTION
        Wraps Get-ADComputer (requires RSAT ActiveDirectory module) with common
        LicenseGuard patterns: search by OU, AD group, or a custom LDAP filter.
        Returns strings (computer names) that can be piped directly to Invoke-LGRemoteScan.

    .PARAMETER SearchBase
        Distinguished Name of the OU to search. Example: 'OU=Workstations,DC=corp,DC=local'

    .PARAMETER Filter
        LDAP filter string passed to Get-ADComputer. Default: all enabled computers.

    .PARAMETER GroupName
        Returns members of this AD security group (resolved via Get-ADGroupMember).

    .PARAMETER Server
        Domain controller to query. If omitted, uses the default DC.

    .PARAMETER Credential
        Credential for the AD query.

    .PARAMETER EnabledOnly
        Exclude disabled computer accounts (on by default).

    .PARAMETER OperatingSystemFilter
        Wildcard pattern(s) to restrict by OperatingSystem attribute.
        Example: 'Windows 10*','Windows 11*'

    .PARAMETER PassThru
        Return full ADComputer objects instead of bare computer name strings.

    .EXAMPLE
        # Scan all enabled workstations in an OU
        Get-LGADComputers -SearchBase 'OU=Workstations,DC=corp,DC=local' |
            Invoke-LGRemoteScan

    .EXAMPLE
        # Scan members of a specific group
        Get-LGADComputers -GroupName 'LicenseAudit-Targets' |
            Invoke-LGRemoteScan -ThrottleLimit 20 -IncludeEol

    .EXAMPLE
        # Filter by OS and return ADComputer objects
        Get-LGADComputers -OperatingSystemFilter 'Windows Server*' -PassThru

    .EXAMPLE
        # Custom filter
        Get-LGADComputers -Filter "OperatingSystem -like 'Windows 10*' -and Enabled -eq 'True'"
    #>
    [CmdletBinding(DefaultParameterSetName = 'Filter')]
    [OutputType([string], ParameterSetName = 'Filter')]
    [OutputType([string], ParameterSetName = 'Group')]
    param(
        [Parameter(ParameterSetName = 'Filter')]
        [string]$SearchBase,

        [Parameter(ParameterSetName = 'Filter')]
        [string]$Filter = '*',

        [Parameter(Mandatory, ParameterSetName = 'Group')]
        [string]$GroupName,

        [string]$Server,
        [pscredential]$Credential,
        [switch]$EnabledOnly,
        [string[]]$OperatingSystemFilter,
        [switch]$PassThru
    )

    # Verify the ActiveDirectory module is available (check loaded session first, then installed)
    $adLoaded = Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue
    if (-not $adLoaded) {
        $adAvail = Get-Module -Name ActiveDirectory -ListAvailable -ErrorAction SilentlyContinue
        if (-not $adAvail) {
            throw "ActiveDirectory module not found. Install RSAT: Install-WindowsFeature RSAT-AD-PowerShell  (server) or Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0  (client)"
        }
        Import-Module ActiveDirectory -ErrorAction Stop
    }

    $commonParams = @{}
    if ($Server)     { $commonParams.Server     = $Server     }
    if ($Credential) { $commonParams.Credential = $Credential }

    $computers = [System.Collections.Generic.List[object]]::new()

    if ($PSCmdlet.ParameterSetName -eq 'Group') {
        # Resolve group members
        try {
            $members = Get-ADGroupMember -Identity $GroupName @commonParams -ErrorAction Stop |
                           Where-Object { $_.objectClass -eq 'computer' }
            foreach ($m in $members) {
                $adParams = @{ Identity = $m.distinguishedName; Properties = 'OperatingSystem,Enabled' }
                $adParams += $commonParams
                $c = Get-ADComputer @adParams -ErrorAction SilentlyContinue
                if ($c) { $computers.Add($c) }
            }
        } catch {
            Write-Error "Failed to query group '$GroupName': $($_.Exception.Message)"
            return
        }
    } else {
        # Filter-based search
        $adParams = @{
            Filter     = $Filter
            Properties = 'OperatingSystem,Enabled'
        }
        if ($SearchBase) { $adParams.SearchBase = $SearchBase }
        $adParams += $commonParams
        try {
            Get-ADComputer @adParams -ErrorAction Stop | ForEach-Object { $computers.Add($_) }
        } catch {
            Write-Error "AD query failed: $($_.Exception.Message)"
            return
        }
    }

    # Apply EnabledOnly filter
    if ($EnabledOnly -or $Filter -eq '*') {
        $computers = [System.Collections.Generic.List[object]]($computers | Where-Object { $_.Enabled })
    }

    # Apply OS filter
    if ($OperatingSystemFilter) {
        $computers = [System.Collections.Generic.List[object]]($computers | Where-Object {
            $os = $_.OperatingSystem
            $OperatingSystemFilter | Where-Object { $os -like $_ }
        })
    }

    Write-Verbose "Found $($computers.Count) computer(s) from AD"

    if ($PassThru) {
        $computers
    } else {
        $computers | ForEach-Object { $_.Name }
    }
}
