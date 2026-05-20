function Send-LGMailReport {
    <#
    .SYNOPSIS
        Sends the HTML report as an email attachment.
    .EXAMPLE
        Send-LGMailReport -ReportPath .\license-report.html -Summary "3 issues found"
    #>
    [CmdletBinding()]
    param(
        [string]$ReportPath = '',
        [Parameter(Mandatory)][string]$Summary,
        [object]$EmailConfig = $null
    )

    $cfg    = Get-LGEffectiveConfig
    $email  = if ($EmailConfig) { $EmailConfig } else { $cfg.Email }

    if (-not $email) {
        Write-Warning 'Email config (lg-config.json -> Email) not found.'
        return
    }
    try {
        $params = @{
            SmtpServer = $email.SmtpServer
            Port       = [int]$email.Port
            From       = $email.From
            To         = $email.To
            Subject    = "LicenseGuard v$($script:LGVersion) -- $env:COMPUTERNAME -- $(Get-Date -Format 'yyyy-MM-dd')"
            Body       = $Summary
            UseSsl     = [bool]$email.UseSsl
        }
        if ($ReportPath -and (Test-Path $ReportPath)) { $params.Attachments = $ReportPath }
        if ($null -ne $email.Credential -and $null -ne $email.Credential.User) {
            $pw = ConvertTo-SecureString $email.Credential.Password -AsPlainText -Force
            $params.Credential = New-Object System.Management.Automation.PSCredential($email.Credential.User, $pw)
        }
        Send-MailMessage @params
        Write-Host "  Email sent to: $($email.To -join ', ')" -ForegroundColor Green
    } catch {
        Write-Warning "Email failed: $($_.Exception.Message)"
    }
}

function Send-LGWebhookNotification {
    <#
    .SYNOPSIS
        Posts a notification to Teams and/or Slack webhooks.
    .EXAMPLE
        Send-LGWebhookNotification -Title "Scan complete" -Summary "No issues" -Color "00CC44"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Summary,
        [string]$Color         = 'FF0000',
        [object]$WebhookConfig = $null
    )

    $cfg     = Get-LGEffectiveConfig
    $webhook = if ($WebhookConfig) { $WebhookConfig } else { $cfg.Webhook }
    if (-not $webhook) { return }

    if ($webhook.Teams) {
        try {
            $payload = [PSCustomObject]@{
                '@type'    = 'MessageCard'
                '@context' = 'http://schema.org/extensions'
                themeColor = $Color
                summary    = $Title
                title      = "LicenseGuard v$($script:LGVersion) -- $Title"
                text       = $Summary
            } | ConvertTo-Json -Depth 4
            Invoke-RestMethod -Uri $webhook.Teams -Method POST -Body $payload `
                -ContentType 'application/json' -TimeoutSec 10
            Write-Host '  Teams notification sent.' -ForegroundColor Green
        } catch { Write-Warning "Teams webhook: $($_.Exception.Message)" }
    }

    if ($webhook.Slack) {
        try {
            $emoji   = if ($Color -eq 'FF0000') { ':red_circle:' } elseif ($Color -eq 'FFA500') { ':warning:' } else { ':white_check_mark:' }
            $payload = [PSCustomObject]@{ text = "$emoji *LicenseGuard -- $Title*`n$Summary" } | ConvertTo-Json
            Invoke-RestMethod -Uri $webhook.Slack -Method POST -Body $payload `
                -ContentType 'application/json' -TimeoutSec 10
            Write-Host '  Slack notification sent.' -ForegroundColor Green
        } catch { Write-Warning "Slack webhook: $($_.Exception.Message)" }
    }
}

function New-LGJiraIssues {
    <#
    .SYNOPSIS
        Creates Jira issues for each PROHIBITED / REQUIRES_LICENSE policy violation.
    .EXAMPLE
        $policy = Invoke-LGPolicyCheck -PolicyPath .\lg-policy.json
        New-LGJiraIssues -PolicyFindings $policy
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$PolicyFindings,
        [object]$JiraConfig = $null
    )

    $cfg    = Get-LGEffectiveConfig
    $jira   = if ($JiraConfig) { $JiraConfig } else { $cfg.Jira }

    if ($null -eq $jira -or -not $jira.BaseUrl) {
        Write-Warning 'Jira config (lg-config.json -> Jira) not found.'
        return
    }

    $violations = @($PolicyFindings | Where-Object { $_.PolicyStatus -in @('PROHIBITED','REQUIRES_LICENSE') })
    if (-not $violations) { Write-Host '  Jira: No violations to report.' -ForegroundColor DarkGray; return }

    $auth    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($jira.User):$($jira.Token)"))
    $headers = @{ Authorization = "Basic $auth"; 'Content-Type' = 'application/json' }
    $created = 0

    foreach ($v in $violations) {
        try {
            $pri  = if ($v.PolicyStatus -eq 'PROHIBITED') { 'High' } else { 'Medium' }
            $body = [PSCustomObject]@{
                fields = [PSCustomObject]@{
                    project     = [PSCustomObject]@{ key = $jira.ProjectKey }
                    summary     = "[LicenseGuard] $($v.Name) -- $($v.PolicyStatus)"
                    description = "$($v.Detail)`n`nMachine: $env:COMPUTERNAME`nCategory: $($v.Category)`nAlternative: $($v.Alternative)"
                    issuetype   = [PSCustomObject]@{ name = 'Bug' }
                    priority    = [PSCustomObject]@{ name = $pri }
                }
            } | ConvertTo-Json -Depth 5
            $resp = Invoke-RestMethod -Uri "$($jira.BaseUrl)/rest/api/2/issue" `
                -Method POST -Body $body -Headers $headers -TimeoutSec 15
            Write-Host "  Jira ticket created: $($resp.key)" -ForegroundColor Green
            $created++
        } catch { Write-Warning "Jira ($($v.Name)): $($_.Exception.Message)" }
    }
    if ($created -gt 0) { Write-Host "  $created Jira ticket(s) created." -ForegroundColor Green }
}
