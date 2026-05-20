#Requires -Module Pester
<#
.SYNOPSIS
    Pester v5 tests for policy engine edge cases.
#>

Describe 'Policy Logic' {
    BeforeAll {
        $modulePath = Join-Path (Split-Path $PSScriptRoot) 'LicenseGuard.psm1'
        Import-Module $modulePath -Force -ErrorAction Stop
        Initialize-LicenseGuard -Language en

        $script:policyContent = @'
{
  "rules": [
    { "id":"R001","category":"P2P","pattern":"BitTorrent","matchType":"contains","status":"PROHIBITED","reason":"P2P not permitted","severity":"HIGH","alternative":"None","referenceUrl":"" },
    { "id":"R002","category":"Remote","pattern":"^TeamViewer$","matchType":"regex","status":"REQUIRES_LICENSE","reason":"License required","severity":"MEDIUM","alternative":"","referenceUrl":"" },
    { "id":"R003","category":"Dev","pattern":"Python 3","matchType":"startsWith","status":"ALLOWED","reason":"Approved","severity":"LOW","alternative":"","referenceUrl":"" },
    { "id":"R004","category":"Exact","pattern":"ExactMatch","matchType":"exact","status":"PROHIBITED","reason":"Exact match test","severity":"HIGH","alternative":"","referenceUrl":"" }
  ]
}
'@
    $script:policyFile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
    $script:policyContent | Out-File $script:policyFile -Encoding UTF8
}

AfterAll {
    Remove-Item $script:policyFile -ErrorAction SilentlyContinue
    Remove-Module LicenseGuard -ErrorAction SilentlyContinue
}

Describe 'Invoke-LGPolicyCheck — match types' {
    It 'contains match: detects partial name' {
        $sw     = @([PSCustomObject]@{ Name='µTorrent BitTorrent Client'; Version='3.6'; Publisher='BitTorrent' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:policyFile -SoftwareCache $sw
        ($result | Where-Object { $_.RuleId -eq 'R001' }).PolicyStatus | Should -Be 'PROHIBITED'
    }

    It 'regex match: does not match partial name with ^ anchor' {
        $sw     = @([PSCustomObject]@{ Name='TeamViewer Host'; Version='15'; Publisher='TeamViewer GmbH' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:policyFile -SoftwareCache $sw
        # "TeamViewer Host" does NOT match ^TeamViewer$ — should be unmatched
        ($result | Where-Object { $_.RuleId -eq 'N/A' }) | Should -Not -BeNullOrEmpty
    }

    It 'regex match: matches exact name' {
        $sw     = @([PSCustomObject]@{ Name='TeamViewer'; Version='15'; Publisher='TeamViewer GmbH' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:policyFile -SoftwareCache $sw
        ($result | Where-Object { $_.RuleId -eq 'R002' }).PolicyStatus | Should -Be 'REQUIRES_LICENSE'
    }

    It 'startsWith match: matches prefix' {
        $sw     = @([PSCustomObject]@{ Name='Python 3.11.0'; Version='3.11.0'; Publisher='Python Software Foundation' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:policyFile -SoftwareCache $sw
        ($result | Where-Object { $_.RuleId -eq 'R003' }).PolicyStatus | Should -Be 'ALLOWED'
    }

    It 'exact match: does not match partial string' {
        $sw     = @([PSCustomObject]@{ Name='ExactMatch Suite'; Version='1'; Publisher='Co' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:policyFile -SoftwareCache $sw
        # "ExactMatch Suite" is NOT an exact match for "ExactMatch"
        ($result | Where-Object { $_.RuleId -eq 'N/A' }) | Should -Not -BeNullOrEmpty
    }

    It 'exact match: matches exactly' {
        $sw     = @([PSCustomObject]@{ Name='ExactMatch'; Version='1'; Publisher='Co' })
        $result = Invoke-LGPolicyCheck -PolicyPath $script:policyFile -SoftwareCache $sw
        ($result | Where-Object { $_.RuleId -eq 'R004' }).PolicyStatus | Should -Be 'PROHIBITED'
    }
}

Describe 'Invoke-LGPolicyCheck — severity mapping' {
    It 'maps PROHIBITED to HIGH severity when not explicit' {
        $minimalPolicy = '{"rules":[{"id":"X1","category":"Test","pattern":"Malware","matchType":"contains","status":"PROHIBITED","reason":"Bad","alternative":""}]}'
        $tmp = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
        $minimalPolicy | Out-File $tmp -Encoding UTF8
        $sw     = @([PSCustomObject]@{ Name='Malware Tool'; Version='1'; Publisher='Bad' })
        $result = Invoke-LGPolicyCheck -PolicyPath $tmp -SoftwareCache $sw
        ($result | Where-Object { $_.RuleId -eq 'X1' }).Severity | Should -Be 'HIGH'
        Remove-Item $tmp
    }

    It 'maps REQUIRES_LICENSE to MEDIUM severity when not explicit' {
        $minimalPolicy = '{"rules":[{"id":"X2","category":"Test","pattern":"LicApp","matchType":"contains","status":"REQUIRES_LICENSE","reason":"Needs lic","alternative":""}]}'
        $tmp = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
        $minimalPolicy | Out-File $tmp -Encoding UTF8
        $sw     = @([PSCustomObject]@{ Name='LicApp 2.0'; Version='2'; Publisher='Lic' })
        $result = Invoke-LGPolicyCheck -PolicyPath $tmp -SoftwareCache $sw
        ($result | Where-Object { $_.RuleId -eq 'X2' }).Severity | Should -Be 'MEDIUM'
        Remove-Item $tmp
    }
}

Describe 'Get-LGRunningProcesses' {
    BeforeEach {
        Mock Get-Process {
            @(
                [PSCustomObject]@{ ProcessName = 'bittorrent' }
                [PSCustomObject]@{ ProcessName = 'chrome'     }
            )
        } -ModuleName LicenseGuard
    }

    It 'detects prohibited process running' {
        $findings = @([PSCustomObject]@{ Name='BitTorrent Client'; PolicyStatus='PROHIBITED' })
        $result   = Get-LGRunningProcesses -PolicyFindings $findings
        $result   | Should -Not -BeNullOrEmpty
        $result[0].Status | Should -Be 'EXPIRED'
    }

    It 'returns empty when prohibited process not running' {
        $findings = @([PSCustomObject]@{ Name='WireShark'; PolicyStatus='PROHIBITED' })
        $result   = Get-LGRunningProcesses -PolicyFindings $findings
        $result   | Should -BeNullOrEmpty
    }

    It 'returns empty when no prohibited software defined' {
        $findings = @([PSCustomObject]@{ Name='Chrome'; PolicyStatus='ALLOWED' })
        $result   = Get-LGRunningProcesses -PolicyFindings $findings
        $result   | Should -BeNullOrEmpty
    }
}

} # End Policy Logic
