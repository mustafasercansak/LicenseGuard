# LicenseGuard

[![PowerShell CI](https://github.com/mustafasercansak/LicenseGuard/actions/workflows/ci.yml/badge.svg)](https://github.com/mustafasercansak/LicenseGuard/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**LicenseGuard** is an enterprise-grade license compliance and security auditing module for Windows environments. It enables sysadmins to scan installed software, browser extensions, and running processes against a corporate policy to identify prohibited or unlicensed software.

## Features

- 🛡️ **Policy-Based Auditing**: Define allowed and prohibited software in a simple JSON policy.
- 🏢 **Active Directory Integration**: Automatically discover and scan workstations across your domain.
- 🚀 **Parallel Remote Scanning**: High-performance multi-machine scanning via WinRM.
- 📦 **Project & Build License Auditing**: Scan NPM, NuGet, compiled outputs, `.deps.json`, and CycloneDX SBOM files for permissive, copyleft, restricted, unknown, and missing-attribution licenses.
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

### Project and Build License Audit

Use `-ProjectPath` to scan source dependency folders and build outputs. LicenseGuard reads NPM `package.json` files under `node_modules`, NuGet metadata from local package cache or `.deps.json`, CycloneDX SBOM files such as `bom.json`, and bundled Node build artifacts such as `dist/*.js`.

```powershell
Import-Module .\LicenseGuard\LicenseGuard.psd1 -Force

Invoke-LicenseGuard `
  -ProjectPath .\examples\dummy-node-project, .\examples\dummy-bin-project `
  -PolicyPath .\lg-policy.json `
  -OutputPath .\license-report.html `
  -Language tr `
  -NoUpdateCheck
```

The HTML report separates raw audit status from policy compliance:

- `GPL` / `AGPL` and restricted source-available licenses such as `SSPL` or `BUSL` are treated as prohibited.
- `LGPL`, `MPL`, `EPL`, `CDDL`, and unknown licenses require manual review.
- Permissive licenses such as `MIT` are allowed only when required attribution files are present; missing `LICENSE`, `NOTICE`, or `3rdpartylicenses.txt` files are flagged.
- If an SBOM contains the same package/version as `.deps.json`, the SBOM row is preferred because it carries richer license metadata.

Before shipping a Node build, generate or include attribution output next to the built assets, for example `dist/3rdpartylicenses.txt`, `NOTICE`, or an SBOM.

For more advanced scenarios, check the [examples/](examples/) folder.

## Project Structure

- `LicenseGuard/`: The core PowerShell module.
- `examples/`: Guided scripts for common use cases.
- `lg-policy.json`: A comprehensive starter policy for software compliance.
- `.github/workflows/`: Continuous integration via GitHub Actions.

## Testing

```powershell
Invoke-Pester -Path .\LicenseGuard\Tests -Output Detailed
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
