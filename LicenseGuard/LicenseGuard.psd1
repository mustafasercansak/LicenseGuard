@{
    ModuleVersion     = '3.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Mustafa Sercan Sak'
    CompanyName       = 'mustafasercansak'
    Copyright         = '(c) 2026 Mustafa Sercan Sak. MIT License.'
    Description       = 'Enterprise license compliance scanner for Windows environments with multi-machine and AD support.'
    PowerShellVersion = '5.1'
    RootModule        = 'LicenseGuard.psm1'

    FunctionsToExport = @(
        'Initialize-LicenseGuard'
        'Get-LGWindowsActivation'
        'Get-LGOfficeLicense'
        'Get-LGInstalledSoftware'
        'Get-LGEolStatus'
        'Get-LGFlexLMStatus'
        'Get-LGSaaSStatus'
        'Get-LGBrowserExtensions'
        'Get-LGVsCodeExtensions'
        'Get-LGStartupAudit'
        'Get-LGRunningProcesses'
        'Get-LGSignatureAudit'
        'Invoke-LGPolicyCheck'
        'Invoke-LGRemoteScan'
        'Get-LGADComputers'
        'Export-LGHtmlReport'
        'Export-LGCsvReport'
        'Export-LGJsonReport'
        'Export-LGSarifReport'
        'Send-LGMailReport'
        'Send-LGWebhookNotification'
        'New-LGJiraIssues'
        'Save-LGSnapshot'
        'Get-LGDelta'
        'Invoke-LicenseGuard'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('License', 'Compliance', 'Security', 'Audit', 'ActiveDirectory', 'Windows', 'Enterprise')
            ProjectUri   = 'https://github.com/mustafasercansak/LicenseGuard'
            LicenseUri   = 'https://github.com/mustafasercansak/LicenseGuard/blob/master/LICENSE'
            ReleaseNotes = 'v3.0: Converted to module. Added AD integration, parallel multi-machine scan, Pester tests.'
        }
    }
}
