# LicenseGuard

[![PowerShell CI](https://github.com/mustafasercansak/LicenseGuard/actions/workflows/ci.yml/badge.svg)](https://github.com/mustafasercansak/LicenseGuard/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**LicenseGuard** is an enterprise-grade license compliance and security auditing module for Windows environments. It enables sysadmins to scan installed software, browser extensions, and running processes against a corporate policy to identify prohibited or unlicensed software.

## Features

- 🛡️ **Policy-Based Auditing**: Define allowed and prohibited software in a simple JSON policy.
- 🏢 **Active Directory Integration**: Automatically discover and scan workstations across your domain.
- 🚀 **Parallel Remote Scanning**: High-performance multi-machine scanning via WinRM.
- 📊 **Interactive HTML Reports**: Beautiful, bilingual (TR/EN) dashboards with search and filtering.
- ⏰ **Automated Scheduling**: Built-in function to register daily compliance audits as a Windows Scheduled Task.
- 🔗 **Integrations**: Support for Jira ticket creation, Webhooks (Slack/Teams), and SMTP email notifications.

## Installation

### Local Development
Clone this repository and import the module folder:
```powershell
Import-Module .\LicenseGuard -Force
```

### From PowerShell Gallery (Planned)
```powershell
Install-Module -Name LicenseGuard
```

## Quick Start

```powershell
# Run a local scan with default policy
Invoke-LicenseGuard -PolicyPath .\lg-policy.json

# Scan a remote machine
Invoke-LicenseGuard -ComputerName "RECP-01"

# Schedule a daily scan
Register-LGScheduledTask -RunAt "07:00" -Language en
```

For more advanced scenarios, check the [examples/](examples/) folder.

## Project Structure

- `LicenseGuard/`: The core PowerShell module.
- `examples/`: Guided scripts for common use cases.
- `lg-policy.json`: A comprehensive starter policy for software compliance.
- `.github/workflows/`: Continuous integration via GitHub Actions.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
