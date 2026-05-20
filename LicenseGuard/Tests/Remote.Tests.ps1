#Requires -Module Pester
<#
.SYNOPSIS
    Pester v5 tests for Invoke-LGRemoteScan (multi-machine parallel scanning).
#>

Describe 'Remote Scan' {
BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot) 'LicenseGuard.psm1'
    Import-Module $modulePath -Force -ErrorAction Stop
    Initialize-LicenseGuard -Language en
}

AfterAll {
    Remove-Module LicenseGuard -ErrorAction SilentlyContinue
}

Describe 'Invoke-LGRemoteScan' {
    Context 'Successful single-machine scan' {
        BeforeEach {
            # Mock Invoke-Command to return a fake data object (simulates remote job)
            Mock Invoke-Command {
                param($ComputerName, $ScriptBlock, $ArgumentList, $AsJob)
                # Return a fake job-like object with the result embedded
                $fakeResult = [PSCustomObject]@{
                    ComputerName = $ComputerName
                    WinStatus    = 'OK'
                    WinDetail    = 'Licensed'
                    Software     = @(
                        [PSCustomObject]@{ Name='FakeApp'; Version='1.0'; Publisher='FakeCo'; Status='OK'; ExpireInfo='' }
                    )
                    EolFindings  = @()
                }
                $job = Start-Job { $using:fakeResult }
                return $job
            } -ModuleName LicenseGuard

            Mock Receive-Job {
                param($Job)
                [PSCustomObject]@{
                    ComputerName = 'TESTPC'
                    WinStatus    = 'OK'
                    WinDetail    = 'Licensed'
                    Software     = @(
                        [PSCustomObject]@{ Name='FakeApp'; Version='1.0'; Publisher='FakeCo'; Status='OK'; ExpireInfo='' }
                    )
                    EolFindings  = @()
                }
            } -ModuleName LicenseGuard

            Mock Remove-Job {} -ModuleName LicenseGuard
        }

        It 'accepts computer names from parameter' {
            $result = Invoke-LGRemoteScan -ComputerName 'TESTPC'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'accepts computer names from pipeline' {
            $result = 'TESTPC' | Invoke-LGRemoteScan
            $result | Should -Not -BeNullOrEmpty
        }

        It 'returns WindowsActivation entry' {
            $result = Invoke-LGRemoteScan -ComputerName 'TESTPC'
            $winRow = $result | Where-Object { $_.Module -eq 'WindowsActivation' }
            $winRow | Should -Not -BeNullOrEmpty
        }

        It 'returns Software entries' {
            $result  = Invoke-LGRemoteScan -ComputerName 'TESTPC'
            $swRows  = $result | Where-Object { $_.Module -eq 'Software' }
            $swRows  | Should -Not -BeNullOrEmpty
        }

        It 'sets ComputerName on each result row' {
            $result = Invoke-LGRemoteScan -ComputerName 'TESTPC'
            $result | ForEach-Object { $_.ComputerName | Should -Not -BeNullOrEmpty }
        }
    }

    Context 'Failed connection' {
        BeforeEach {
            Mock Invoke-Command { throw 'The WinRM client cannot connect to the destination.' } -ModuleName LicenseGuard
        }

        It 'returns ERROR row for unreachable machine' {
            $result = Invoke-LGRemoteScan -ComputerName 'BADPC'
            $errRow = $result | Where-Object { $_.Status -eq 'ERROR' }
            $errRow | Should -Not -BeNullOrEmpty
        }

        It 'includes the computer name in error row' {
            $result = Invoke-LGRemoteScan -ComputerName 'BADPC'
            $errRow = $result | Where-Object { $_.ComputerName -eq 'BADPC' }
            $errRow | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Multiple machines' {
        BeforeEach {
            $script:callCount = 0
            Mock Invoke-Command {
                param($ComputerName)
                $script:callCount++
                $job = Start-Job { $null }
                return $job
            } -ModuleName LicenseGuard

            Mock Receive-Job {
                [PSCustomObject]@{
                    ComputerName = 'TESTPC'; WinStatus='OK'; WinDetail='Licensed'
                    Software=@(); EolFindings=@()
                }
            } -ModuleName LicenseGuard

            Mock Remove-Job {} -ModuleName LicenseGuard
        }

        It 'launches one job per machine' {
            $result = Invoke-LGRemoteScan -ComputerName 'PC1','PC2','PC3'
            $script:callCount | Should -Be 3
        }
    }

    Context 'Parameter validation' {
        It 'ComputerName is mandatory' {
            { Invoke-LGRemoteScan } | Should -Throw
        }

        It 'ThrottleLimit accepts valid integers' {
            Mock Invoke-Command { Start-Job { $null } } -ModuleName LicenseGuard
            Mock Receive-Job { [PSCustomObject]@{ ComputerName='X';WinStatus='OK';WinDetail='';Software=@();EolFindings=@() } } -ModuleName LicenseGuard
            Mock Remove-Job {} -ModuleName LicenseGuard
            { Invoke-LGRemoteScan -ComputerName 'PC1' -ThrottleLimit 5 } | Should -Not -Throw
        }
    }
}

} # End Remote Scan
