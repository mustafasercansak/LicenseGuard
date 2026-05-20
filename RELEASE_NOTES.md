# LicenseGuard Release Notes

---

## v3.1.0 - 2026-05-20

This release expands LicenseGuard from Windows software inventory checks into project, dependency, binary, and build-output license auditing.

### Highlights

- Added **NPM and NuGet dependency license auditing** for source projects.
- Added **binary/build artifact license auditing** for `.exe`, `.dll`, `.deps.json`, SBOM, JS, CSS, and WASM outputs.
- Added **CycloneDX/SPDX-style SBOM parsing** for richer dependency license metadata.
- Added HTML report filters for `NPM`, `NuGet`, and `BinaryAudit` findings.
- Added missing license/notice attribution warnings for permissive licenses such as MIT, Apache, BSD, and ISC.

### Policy Updates

- GPL and AGPL licenses are classified as prohibited.
- LGPL, MPL, EPL, CDDL, unknown, and missing-attribution findings require review.
- Commercially restrictive licenses such as SSPL, BUSL, Commons Clause, PolyForm, and Elastic License are classified as prohibited.
- Policy rules can now match fields such as `License` and `Detail` through `matchField`.

### Quality and Automation

- Added tests for dependency scanning, binary scanning, SBOM handling, build artifact detection, HTML report rendering, and policy classification.
- Added GitHub Actions CI workflow.
- Added PowerShell Gallery publish workflow for tagged releases and manual dispatch.

---

## v3.0.0 - 2026-04-06

This release introduced the professional module structure and expanded LicenseGuard into a broader enterprise compliance scanner.

### Highlights

- Added Microsoft Office license detection through `ospp.vbs` and WMI fallback.
- Added comment-based help for public commands.
- Added SARIF output support.
- Added Jira issue creation for policy violations.
- Added scheduled audit support.
- Added bilingual contribution documentation.

### Fixes

- Improved installed software filtering by excluding `SystemComponent = 1` registry entries.
- Reduced false positives for language packs, proofing tools, and internal Office components.

---

## v2.0 - 2026-03-27

This release added major scan modules, reporting improvements, and automation features.

### Highlights

- Added browser extension scanning for Chrome, Firefox, and Edge.
- Added VS Code extension scanning.
- Added startup program and running process checks.
- Added digital signature verification for executable files.
- Added EOL/end-of-support checks for common software and platforms.
- Added CSV, JSON, and SARIF exports.
- Added SMTP email reporting.
- Added Teams and Slack webhook notifications.
- Added remote machine scanning through `-ComputerName`.
- Added snapshot and delta tracking.
- Added corporate branding options for HTML reports.

---

## v1.0 - 2026-03-26

Initial public release.

### Highlights

- Added Windows activation scanning.
- Added installed software inventory.
- Added FlexLM and SaaS checks.
- Added policy checks with 79 built-in rules.
- Added bilingual HTML report output.
- Added PowerShell 5.1 compatibility.
