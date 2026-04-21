#Requires -Module Pester
<#
.SYNOPSIS
    Pester v5 tests for core LicenseGuard module functions.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot) 'LicenseGuard.psm1'
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module LicenseGuard -ErrorAction SilentlyContinue
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Initialize-LicenseGuard' {
    It 'sets module strings to English' {
        Initialize-LicenseGuard -Language en
        $strings = & (Get-Module LicenseGuard) { Get-LGEffectiveStrings }
        $strings['allowed'] | Should -Be 'COMPLIANT'
    }

    It 'sets module strings to Turkish' {
        Initialize-LicenseGuard -Language tr
        $strings = & (Get-Module LicenseGuard) { Get-LGEffectiveStrings }
        $strings['allowed'] | Should -Be 'UYUMLU'
    }

    It 'loads config defaults when config file does not exist' {
        Initialize-LicenseGuard -ConfigPath 'C:\DoesNotExist\lg-config.json'
        $cfg = & (Get-Module LicenseGuard) { Get-LGEffectiveConfig }
        $cfg.WarnDaysBeforeExpiry | Should -Be 30
    }
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Get-LGWindowsActivation' {
    Context 'Licensed machine' {
        BeforeEach {
            Mock Get-CimInstance {
                [PSCustomObject]@{
                    LicenseStatus        = 1
                    GracePeriodRemaining = 0
                    Name                 = 'Windows(R) Operating System, VOLUME_KMSCLIENT channel'
                }
            } -ModuleName LicenseGuard
        }

        It 'returns Status OK for licensed machine' {
            $result = Get-LGWindowsActivation
            $result.Status | Should -Be 'OK'
        }

        It 'returns correct module name' {
            $result = Get-LGWindowsActivation
            $result.Module | Should -Be 'WindowsActivation'
        }

        It 'includes ComputerName property' {
            $result = Get-LGWindowsActivation
            $result.ComputerName | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Unlicensed machine' {
        BeforeEach {
            Mock Get-CimInstance {
                [PSCustomObject]@{ LicenseStatus = 0; GracePeriodRemaining = 0 }
            } -ModuleName LicenseGuard
        }

        It 'returns Status EXPIRED for unlicensed machine' {
            $result = Get-LGWindowsActivation
            $result.Status | Should -Be 'EXPIRED'
        }
    }

    Context 'Grace period' {
        BeforeEach {
            Mock Get-CimInstance {
                [PSCustomObject]@{ LicenseStatus = 2; GracePeriodRemaining = 43200 }
            } -ModuleName LicenseGuard
        }

        It 'returns Status WARN for grace period' {
            $result = Get-LGWindowsActivation
            $result.Status | Should -Be 'WARN'
        }

        It 'mentions remaining days in detail' {
            $result = Get-LGWindowsActivation
            $result.Detail | Should -Match 'Remaining'
        }
    }

    Context 'WMI failure' {
        BeforeEach {
            Mock Get-CimInstance { throw 'Access denied' } -ModuleName LicenseGuard
        }

        It 'returns Status ERROR on WMI failure' {
            $result = Get-LGWindowsActivation
            $result.Status | Should -Be 'ERROR'
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Get-LGInstalledSoftware' {
    BeforeAll {
        Initialize-LicenseGuard -Language en
        Mock Get-LGSoftwareRegistryRows {
            @(
                [PSCustomObject]@{ Name='TestApp'; Version='1.0'; Publisher='TestCo'; Status='OK'; ExpireInfo=''; InstallDate='2023-01-01' }
                [PSCustomObject]@{ Name='OldApp';  Version='2.5'; Publisher='OldCo';  Status='EXPIRED'; ExpireInfo='EXPIRED (30 days ago)'; InstallDate='2020-01-01' }
                [PSCustomObject]@{ Name='WarnApp'; Version='3.0'; Publisher='WarnCo'; Status='WARN'; ExpireInfo='Expires: 2026-05-01 (10 days)'; InstallDate='2024-01-01' }
            )
        } -ModuleName LicenseGuard
    }

    It 'returns PSCustomObject array' {
        $result = Get-LGInstalledSoftware
        $result | Should -Not -BeNullOrEmpty
        $result[0] | Should -BeOfType [PSCustomObject]
    }

    It 'includes required properties' {
        $result = Get-LGInstalledSoftware
        $props  = $result[0].PSObject.Properties.Name
        $props  | Should -Contain 'Name'
        $props  | Should -Contain 'Status'
        $props  | Should -Contain 'Version'
        $props  | Should -Contain 'Publisher'
        $props  | Should -Contain 'Module'
    }

    It 'correctly reflects EXPIRED status' {
        $result  = Get-LGInstalledSoftware
        $expired = $result | Where-Object { $_.Status -eq 'EXPIRED' }
        $expired | Should -Not -BeNullOrEmpty
        $expired[0].Name | Should -Be 'OldApp'
    }

    It 'sets Module to Software' {
        $result = Get-LGInstalledSoftware
        $result | ForEach-Object { $_.Module | Should -Be 'Software' }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Get-LGEolStatus' {
    BeforeAll {
        Initialize-LicenseGuard -Language en
    }

    It 'detects Internet Explorer as EOL' {
        $sw     = @([PSCustomObject]@{ Name='Internet Explorer 11'; Version='11.0'; Publisher='Microsoft'; Status='OK'; ExpireInfo=''; InstallDate='-' })
        $result = Get-LGEolStatus -SoftwareCache $sw
        $result | Should -Not -BeNullOrEmpty
        $result[0].Status | Should -Be 'EXPIRED'
        $result[0].Module | Should -Be 'EOL'
    }

    It 'detects Office 2013 as EOL' {
        $sw     = @([PSCustomObject]@{ Name='Microsoft Office 2013'; Version='15.0'; Publisher='Microsoft'; Status='OK'; ExpireInfo=''; InstallDate='-' })
        $result = Get-LGEolStatus -SoftwareCache $sw
        $result | Should -Not -BeNullOrEmpty
        $result[0].Status | Should -Be 'EXPIRED'
    }

    It 'returns empty for modern software' {
        $sw     = @([PSCustomObject]@{ Name='ModernApp 2025'; Version='1.0'; Publisher='ModernCo'; Status='OK'; ExpireInfo=''; InstallDate='-' })
        $result = Get-LGEolStatus -SoftwareCache $sw
        $result | Should -BeNullOrEmpty
    }

    It 'includes EolDate property' {
        $sw     = @([PSCustomObject]@{ Name='Adobe Flash Player'; Version='32.0'; Publisher='Adobe'; Status='OK'; ExpireInfo=''; InstallDate='-' })
        $result = Get-LGEolStatus -SoftwareCache $sw
        $result[0].EolDate | Should -Be '2020-12-31'
    }
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Invoke-LGPolicyCheck' {
    BeforeAll {
        Initialize-LicenseGuard -Language en

        $policyJson = @'
{
  "rules": [
    { "id":"R001","category":"P2P","pattern":"BitTorrent","matchType":"contains","status":"PROHIBITED","reason":"P2P not allowed","severity":"HIGH","alternative":"N/A","referenceUrl":"" },
    { "id":"R002","category":"Remote","pattern":"TeamViewer","matchType":"contains","status":"REQUIRES_LICENSE","reason":"License required","severity":"MEDIUM","alternative":"","referenceUrl":"" },
    { "id":"R003","category":"Browser","pattern":"Google Chrome","matchType":"contains","status":"ALLOWED","reason":"Approved","severity":"LOW","alternative":"","referenceUrl":"" }
  ]
}
'@
        $script:tmpPolicy = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
        $policyJson | Out-File $script:tmpPolicy -Encoding UTF8
    }

    AfterAll {
        Remove-Item $script:tmpPolicy -ErrorAction SilentlyContinue
    }

    It 'marks BitTorrent as PROHIBITED' {
        $sw     = @([PSCustomObject]@{ Name='BitTorrent 7.10'; Version='7.10'; Publisher='BitTorrent Inc' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:tmpPolicy -SoftwareCache $sw
        $hit    = $result | Where-Object { $_.PolicyStatus -eq 'PROHIBITED' }
        $hit | Should -Not -BeNullOrEmpty
    }

    It 'marks TeamViewer as REQUIRES_LICENSE' {
        $sw     = @([PSCustomObject]@{ Name='TeamViewer 15'; Version='15'; Publisher='TeamViewer GmbH' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:tmpPolicy -SoftwareCache $sw
        $hit    = $result | Where-Object { $_.PolicyStatus -eq 'REQUIRES_LICENSE' }
        $hit | Should -Not -BeNullOrEmpty
    }

    It 'marks Google Chrome as ALLOWED' {
        $sw     = @([PSCustomObject]@{ Name='Google Chrome'; Version='120'; Publisher='Google LLC' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:tmpPolicy -SoftwareCache $sw
        $hit    = $result | Where-Object { $_.PolicyStatus -eq 'ALLOWED' }
        $hit | Should -Not -BeNullOrEmpty
    }

    It 'marks unmatched software as ALLOWED with N/A rule' {
        $sw     = @([PSCustomObject]@{ Name='Unknown App 1.0'; Version='1.0'; Publisher='NoCo' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:tmpPolicy -SoftwareCache $sw
        $hit    = $result | Where-Object { $_.RuleId -eq 'N/A' }
        $hit | Should -Not -BeNullOrEmpty
        $hit[0].PolicyStatus | Should -Be 'ALLOWED'
    }

    It 'honours whitelist in config' {
        & (Get-Module LicenseGuard) { $script:LGConfig.Whitelist = @('BitTorrent') }
        $sw     = @([PSCustomObject]@{ Name='BitTorrent 7.10'; Version='7.10'; Publisher='BitTorrent Inc' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:tmpPolicy -SoftwareCache $sw
        $result[0].PolicyStatus | Should -Be 'ALLOWED'
        $result[0].RuleId       | Should -Be 'WL'
        & (Get-Module LicenseGuard) { $script:LGConfig.Whitelist = @() }
    }

    It 'returns empty array when policy file not found' {
        $result = Invoke-LGPolicyCheck -PolicyPath 'C:\DoesNotExist\policy.json'
        @($result).Count | Should -Be 0
    }
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Save-LGSnapshot and Get-LGDelta' {
    BeforeAll {
        Initialize-LicenseGuard
        $script:snapPath = [System.IO.Path]::GetTempFileName()
        & (Get-Module LicenseGuard) { param($p) $script:LGConfig.SnapshotPath = $p } -p $script:snapPath
    }
    AfterAll { Remove-Item $script:snapPath -ErrorAction SilentlyContinue }

    It 'saves snapshot without error' {
        $results  = @([PSCustomObject]@{ Name='App1'; Status='EXPIRED' })
        $findings = @([PSCustomObject]@{ Name='App2'; PolicyStatus='PROHIBITED' })
        { Save-LGSnapshot -AllResults $results -PolicyFindings $findings } | Should -Not -Throw
        Test-Path $script:snapPath | Should -BeTrue
    }

    It 'detects new issues in delta' {
        # Previous snapshot: App1 EXPIRED
        # Current: App1 + App3 EXPIRED
        $results  = @(
            [PSCustomObject]@{ Name='App1'; Status='EXPIRED' }
            [PSCustomObject]@{ Name='App3'; Status='EXPIRED' }
        )
        $findings = @([PSCustomObject]@{ Name='App2'; PolicyStatus='ALLOWED' })
        $delta    = Get-LGDelta -CurrentResults $results -CurrentPolicyFindings $findings
        $delta              | Should -Not -BeNullOrEmpty
        $delta.NewIssues    | Should -Contain 'App3'
    }

    It 'detects resolved issues in delta' {
        $results  = @()   # App1 resolved
        $findings = @([PSCustomObject]@{ Name='App2'; PolicyStatus='ALLOWED' })
        $delta    = Get-LGDelta -CurrentResults $results -CurrentPolicyFindings $findings
        $delta.ResolvedIssues | Should -Contain 'App1'
    }

    It 'returns null when no snapshot exists' {
        $delta = Get-LGDelta -SnapshotPath 'C:\DoesNotExist\snap.json' `
            -CurrentResults @() -CurrentPolicyFindings @()
        $delta | Should -BeNullOrEmpty
    }
}
