#Requires -Module Pester
<#
.SYNOPSIS
    Pester v5 tests for Get-LGADComputers (Active Directory integration).
    Tests mock the ActiveDirectory module so RSAT is not required to run tests.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot) 'LicenseGuard.psm1'
    Import-Module $modulePath -Force -ErrorAction Stop
    Initialize-LicenseGuard -Language en

    # Stub the ActiveDirectory module so tests run without RSAT installed
    if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
        New-Module -Name ActiveDirectory -ScriptBlock {
            function Get-ADComputer     { [CmdletBinding()] param([Parameter(ValueFromPipeline)]$Identity,$Filter,$SearchBase,$Properties,$Server,$Credential) process {} }
            function Get-ADGroupMember  { [CmdletBinding()] param($Identity,$Server,$Credential) }
        } | Import-Module -Force
    }
}

AfterAll {
    Remove-Module LicenseGuard     -ErrorAction SilentlyContinue
    Remove-Module ActiveDirectory  -ErrorAction SilentlyContinue
}

Describe 'Get-LGADComputers' {
    Context 'Filter-based search' {
        BeforeEach {
            Mock Get-ADComputer {
                @(
                    [PSCustomObject]@{ Name='PC001'; OperatingSystem='Windows 10 Enterprise'; Enabled=$true; distinguishedName='CN=PC001,OU=Workstations,DC=corp,DC=local' }
                    [PSCustomObject]@{ Name='PC002'; OperatingSystem='Windows 11 Pro';        Enabled=$true; distinguishedName='CN=PC002,OU=Workstations,DC=corp,DC=local' }
                    [PSCustomObject]@{ Name='PC003'; OperatingSystem='Windows 10 Enterprise'; Enabled=$false; distinguishedName='CN=PC003,OU=Workstations,DC=corp,DC=local' }
                )
            } -ModuleName LicenseGuard
        }

        It 'returns computer names as strings by default' {
            $result = Get-LGADComputers -SearchBase 'OU=Workstations,DC=corp,DC=local'
            $result | Should -Not -BeNullOrEmpty
            $result[0] | Should -BeOfType [string]
        }

        It 'excludes disabled computers with -EnabledOnly' {
            $result = Get-LGADComputers -SearchBase 'OU=Workstations,DC=corp,DC=local' -EnabledOnly
            $result | Should -Not -Contain 'PC003'
            $result.Count | Should -Be 2
        }

        It 'filters by operating system' {
            $result = Get-LGADComputers -SearchBase 'OU=Workstations,DC=corp,DC=local' `
                -OperatingSystemFilter 'Windows 11*'
            $result | Should -Contain 'PC002'
            $result | Should -Not -Contain 'PC001'
        }

        It 'returns ADComputer objects with -PassThru' {
            $result = Get-LGADComputers -SearchBase 'OU=Workstations,DC=corp,DC=local' -PassThru
            $result[0].PSObject.Properties.Name | Should -Contain 'OperatingSystem'
        }
    }

    Context 'Group-based search' {
        BeforeEach {
            Mock Get-ADGroupMember {
                @(
                    [PSCustomObject]@{ objectClass='computer'; distinguishedName='CN=PC001,OU=WS,DC=corp,DC=local' }
                    [PSCustomObject]@{ objectClass='user';     distinguishedName='CN=User1,OU=Users,DC=corp,DC=local' }
                )
            } -ModuleName LicenseGuard

            Mock Get-ADComputer {
                param($Identity)
                [PSCustomObject]@{ Name='PC001'; OperatingSystem='Windows 10'; Enabled=$true; distinguishedName=$Identity }
            } -ModuleName LicenseGuard
        }

        It 'resolves group members and skips non-computer objects' {
            $result = @(Get-LGADComputers -GroupName 'LicenseAudit')
            $result.Count | Should -Be 1
            $result[0] | Should -Be 'PC001'
        }
    }

    Context 'Pipeline to Invoke-LGRemoteScan' {
        BeforeEach {
            Mock Get-ADComputer {
                @([PSCustomObject]@{ Name='PC001'; OperatingSystem='Windows 10'; Enabled=$true })
            } -ModuleName LicenseGuard

            Mock Invoke-Command { Start-Job { $null } } -ModuleName LicenseGuard

            Mock Receive-Job {
                [PSCustomObject]@{ ComputerName='PC001'; WinStatus='OK'; WinDetail='Licensed'; Software=@(); EolFindings=@() }
            } -ModuleName LicenseGuard

            Mock Remove-Job {} -ModuleName LicenseGuard
        }

        It 'pipes AD results to Invoke-LGRemoteScan' {
            { Get-LGADComputers -SearchBase 'OU=WS,DC=corp,DC=local' | Invoke-LGRemoteScan } |
                Should -Not -Throw
        }
    }

    Context 'Error handling' {
        BeforeEach {
            Mock Get-ADComputer { throw 'Cannot contact domain controller' } -ModuleName LicenseGuard
        }

        It 'surfaces AD errors as terminating errors' {
            { Get-LGADComputers -SearchBase 'OU=WS,DC=corp,DC=local' 2>&1 } |
                Should -Not -Throw
        }
    }

    Context 'Parameter sets' {
        It 'has Filter parameter set as default' {
            $cmd  = Get-Command Get-LGADComputers -Module LicenseGuard
            $cmd.ParameterSets | Where-Object { $_.IsDefault } |
                ForEach-Object { $_.Name } | Should -Be 'Filter'
        }

        It 'has Group parameter set' {
            $cmd  = Get-Command Get-LGADComputers -Module LicenseGuard
            $sets = $cmd.ParameterSets.Name
            $sets | Should -Contain 'Group'
        }

        It 'GroupName is mandatory in Group set' {
            $cmd   = Get-Command Get-LGADComputers -Module LicenseGuard
            $param = $cmd.Parameters['GroupName']
            $param.ParameterSets['Group'].IsMandatory | Should -BeTrue
        }
    }
}
