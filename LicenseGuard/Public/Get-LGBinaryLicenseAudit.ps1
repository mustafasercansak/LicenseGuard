function Get-LGBinaryLicenseAudit {
    <#
    .SYNOPSIS
        Performs a comprehensive license compliance audit on compiled binaries (.exe, .dll).
        Inspects PE metadata, parses .NET .deps.json files, checks for SBOM files, and verifies local attribution files.
    .EXAMPLE
        Get-LGBinaryLicenseAudit -Path "C:\Projects\MyApp\bin\Release"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Path
    )

    $L = Get-LGEffectiveStrings
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $seenResults = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $nugetLicenseCache = @{}
    $licenseFilePatterns = @("LICENSE*", "LICENSES*", "COPYING*", "NOTICE*", "3rdpartylicenses*", "THIRD-PARTY-NOTICES*")
    $buildArtifactPatterns = @("*.js", "*.mjs", "*.cjs", "*.css", "*.wasm")

    function Add-LGUniqueResult {
        param(
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Item
        )

        $key = "{0}|{1}|{2}|{3}|{4}" -f $Item.Name, $Item.Version, $Item.Publisher, $Item.License, $Item.Detail
        if ($seenResults.Add($key)) {
            $results.Add($Item)
        }
    }

    function Resolve-LGNuGetLicenseFromApi {
        param(
            [Parameter(Mandatory = $true)][string]$PackageId,
            [Parameter(Mandatory = $true)][string]$Version
        )

        $cacheKey = "$($PackageId.ToLowerInvariant())/$Version"
        if ($nugetLicenseCache.ContainsKey($cacheKey)) {
            return $nugetLicenseCache[$cacheKey]
        }

        $license = "Unknown"
        try {
            $pkg = $PackageId.ToLowerInvariant()
            $ver = $Version.ToLowerInvariant()
            $uri = "https://api.nuget.org/v3/registration5-semver1/$pkg/$ver.json"
            $resp = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 5
            $entry = $resp.catalogEntry

            if ($entry -and $entry.licenseExpression) {
                $license = [string]$entry.licenseExpression
            } elseif ($entry -and $entry.licenseUrl) {
                $url = [string]$entry.licenseUrl
                if ($url -match "licenses.nuget.org/([^/?#]+)") {
                    $license = $Matches[1]
                } else {
                    $license = $url
                }
            }
        } catch {
            # Keep Unknown on network/API failures.
        }

        $nugetLicenseCache[$cacheKey] = $license
        return $license
    }

    function Get-LGSbomComponents {
        param([string]$Directory)

        $components = [System.Collections.Generic.List[PSCustomObject]]::new()
        $sbomFiles = Get-ChildItem -Path $Directory -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*sbom*.json" -or $_.Name -like "*bom*.json" -or $_.Name -like "*spdx*.json" }

        foreach ($sbom in $sbomFiles) {
            Write-Host "    Found SBOM file: $($sbom.Name), parsing..." -ForegroundColor DarkGray
            try {
                $sbomData = Get-Content $sbom.FullName -Raw | ConvertFrom-Json

                if ($sbomData.bomFormat -eq "CycloneDX" -and $sbomData.components) {
                    foreach ($comp in $sbomData.components) {
                        $compLicense = "Unknown"
                        if ($comp.licenses -and $comp.licenses.Count -gt 0) {
                            $lic = $comp.licenses[0]
                            if ($lic.license) {
                                $compLicense = if ($lic.license.id) { $lic.license.id } else { $lic.license.name }
                            } elseif ($lic.expression) {
                                $compLicense = $lic.expression
                            }
                        }

                        $components.Add([PSCustomObject]@{
                            Source    = $sbom.Name
                            Name      = $comp.name
                            Version   = $comp.version
                            Publisher = if ($comp.publisher) { $comp.publisher } else { "Unknown" }
                            License   = $compLicense
                        })
                    }
                }
            } catch {
                # Skip invalid SBOMs
            }
        }

        $components
    }

    foreach ($targetPath in $Path) {
        if (-not (Test-Path $targetPath)) {
            Write-Warning "Binary path not found: $targetPath"
            continue
        }

        # Resolve directory if a file path was passed
        $dir = $targetPath
        $specificFiles = @()
        if (Test-Path $targetPath -PathType Leaf) {
            $dir = Split-Path $targetPath
            $specificFiles = @((Get-Item $targetPath))
        }

        # 1. Verify if the directory has a LICENSE or 3rd Party Notice file (Attribution Check)
        $rootLicenseFiles = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue | 
                            Where-Object { $_.Name -like "LICENSE*" -or $_.Name -like "3rdpartylicenses*" -or $_.Name -like "LICENSES*" -or $_.Name -like "NOTICE*" }
        
        $hasRootLicense = ($rootLicenseFiles.Count -gt 0)
        $sbomComponents = @(Get-LGSbomComponents -Directory $dir)
        $sbomPackageKeys = @{}
        foreach ($component in $sbomComponents) {
            if ($component.Name -and $component.Version) {
                $key = "{0}|{1}" -f $component.Name.ToLowerInvariant(), $component.Version
                $sbomPackageKeys[$key] = $true
            }
        }

        # 2. Get list of binaries to inspect (.exe and .dll)
        $binaries = if ($specificFiles.Count -gt 0) { $specificFiles } else {
            Get-ChildItem -Path $dir -Include "*.exe", "*.dll" -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }
        }

        if ($binaries.Count -gt 0) {
            Write-Host "  Auditing $($binaries.Count) binaries in $dir..." -ForegroundColor Cyan
        }

        $buildArtifacts = Get-ChildItem -Path $dir -Include $buildArtifactPatterns -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }

        if ($buildArtifacts.Count -gt 0) {
            Write-Host "  Auditing $($buildArtifacts.Count) build artifact(s) in $dir..." -ForegroundColor Cyan
        }

        foreach ($artifact in $buildArtifacts) {
            $artifactText = ''
            try {
                $artifactText = Get-Content $artifact.FullName -Raw -ErrorAction Stop
            } catch {}

            $licenseType = "Unknown"
            if ($artifactText -match "(?i)Affero General Public License|\bAGPL\b") {
                $licenseType = "AGPL"
            } elseif ($artifactText -match "(?i)General Public License|\bGPL\b|GPL-3\.0|GPL-2\.0") {
                $licenseType = "GPL"
            } elseif ($artifactText -match "(?i)MIT License|\bMIT\b") {
                $licenseType = "MIT"
            } elseif ($artifactText -match "(?i)Apache License|Apache-2\.0") {
                $licenseType = "Apache-2.0"
            } elseif ($artifactText -match "(?i)BSD License|\bBSD\b") {
                $licenseType = "BSD"
            } elseif ($artifactText -match "(?i)\bISC\b") {
                $licenseType = "ISC"
            }

            $detailText = "Build Artifact License Scan"
            if (-not $hasRootLicense) {
                $detailText += " [MISSING LICENSE/ATTRIBUTION FILE]"
            }
            if ($licenseType -eq "Unknown") {
                $detailText += " [UNKNOWN LICENSE]"
            }

            Add-LGUniqueResult -Item ([PSCustomObject]@{
                Module       = "BinaryAudit"
                Name         = "Build Artifact: $($artifact.Name)"
                Version      = ""
                Publisher    = "BuildOutput"
                License      = $licenseType
                Detail       = $detailText
                Status       = Get-LGLicenseAuditStatus -License $licenseType -HasMissingAttribution (-not $hasRootLicense)
                ComputerName = $env:COMPUTERNAME
            })
        }

        foreach ($bin in $binaries) {
            $binName = $bin.Name
            $binPath = $bin.FullName
            
            # A. Inspect PE Metadata
            $vi = $null
            try {
                $vi = $bin.VersionInfo
            } catch {}

            $company   = if ($vi -and $vi.CompanyName) { $vi.CompanyName } else { "Unknown Company" }
            $copyright = if ($vi -and $vi.LegalCopyright) { $vi.LegalCopyright } else { "" }
            $version   = if ($vi -and $vi.ProductVersion) { $vi.ProductVersion } else { $bin.VersionInfo.FileVersion }
            if (-not $version) { $version = "1.0.0" }

            # Basic heuristics: Check copyright/trademarks for "GPL" or "AGPL" terms
            $licenseType = "Commercial/Proprietary"
            if ($copyright -match "GPL" -or $copyright -match "General Public License" -or $vi.LegalTrademarks -match "GPL") {
                $licenseType = "GPL"
            } elseif ($copyright -match "Apache" -or $copyright -match "ASL") {
                $licenseType = "Apache"
            } elseif ($copyright -match "MIT" -or $copyright -match "X11") {
                $licenseType = "MIT"
            }

            # Compliance Warning: Blank metadata in own binaries might indicate lack of governance
            $complianceDetail = "Binary Metadata Check"
            if (-not $copyright -and -not $vi.CompanyName) {
                $complianceDetail += " [MISSING METADATA]"
            }
            if (-not $hasRootLicense) {
                $complianceDetail += " [MISSING LICENSE/ATTRIBUTION FILE]"
            }

            Add-LGUniqueResult -Item ([PSCustomObject]@{
                Module       = "BinaryAudit"
                Name         = "Binary: $($binName)"
                Version      = $version
                Publisher    = $company
                License      = $licenseType
                Detail       = "Copyright: $copyright | $complianceDetail"
                Status       = Get-LGLicenseAuditStatus -License $licenseType -HasMissingAttribution (-not $hasRootLicense)
                ComputerName = $env:COMPUTERNAME
            })

            # B. Check for .NET Core .deps.json
            $depsJsonPath = [System.IO.Path]::ChangeExtension($binPath, ".deps.json")
            if (Test-Path $depsJsonPath) {
                Write-Host "    Found .deps.json for $($binName), parsing NuGet dependencies..." -ForegroundColor DarkGray
                try {
                    $depsJson = Get-Content $depsJsonPath -Raw | ConvertFrom-Json
                    
                    # Parse dependencies from targets section
                    if ($depsJson.targets) {
                        $targetFramework = ($depsJson.targets.psobject.Properties | Select-Object -First 1).Name
                        if ($targetFramework) {
                            $targetDeps = $depsJson.targets.$targetFramework
                            foreach ($depProp in $targetDeps.psobject.Properties) {
                                # Format: "PackageName/Version"
                                $depKey = $depProp.Name
                                if ($depKey -match "^([^/]+)/(.+)$") {
                                    $packageId = $Matches[1]
                                    $pkgVersion = $Matches[2]
                                    $sbomKey = "{0}|{1}" -f $packageId.ToLowerInvariant(), $pkgVersion
                                    if ($sbomPackageKeys.ContainsKey($sbomKey)) {
                                        continue
                                    }

                                    # Only look at package dependencies, skip projects or runtimes
                                    $depVal = $depProp.Value
                                    if ($depVal.type -eq "package" -or $null -eq $depVal.type) {
                                        # Resolve package license from NuGet cache
                                        $nugetCache = Join-Path $env:USERPROFILE ".nuget\packages"
                                        $pkgFolder = Join-Path $nugetCache $packageId.ToLowerInvariant()
                                        $versionFolder = Join-Path $pkgFolder $pkgVersion
                                        $nuspecPath = Join-Path $versionFolder "$($packageId.ToLowerInvariant()).nuspec"
                                        
                                        $license = "Unknown"
                                        $hasLicenseFile = $false
                                        
                                        if (Test-Path $nuspecPath) {
                                            try {
                                                [xml]$nuspecXml = Get-Content $nuspecPath
                                                $ns = New-Object System.Xml.XmlNamespaceManager($nuspecXml.NameTable)
                                                $ns.AddNamespace("ns", $nuspecXml.DocumentElement.NamespaceURI)
                                                
                                                $licenseNode = $nuspecXml.SelectSingleNode("//ns:license", $ns)
                                                if ($licenseNode) {
                                                    $license = $licenseNode.InnerText
                                                } else {
                                                    $licenseUrlNode = $nuspecXml.SelectSingleNode("//ns:licenseUrl", $ns)
                                                    if ($licenseUrlNode) {
                                                        $url = $licenseUrlNode.InnerText
                                                        if ($url -match "licenses.nuget.org/MIT" -or $url -match "opensource.org/licenses/MIT") { $license = "MIT" }
                                                        elseif ($url -match "licenses.nuget.org/Apache-2.0") { $license = "Apache-2.0" }
                                                        else { $license = $url }
                                                    }
                                                }

                                                foreach ($pattern in $licenseFilePatterns) {
                                                    $files = Get-ChildItem -Path $versionFolder -Filter $pattern -File -ErrorAction SilentlyContinue
                                                    if ($files -and $files.Count -gt 0) {
                                                        $hasLicenseFile = $true
                                                        break
                                                    }
                                                }
                                            } catch {}
                                        }

                                        if ($license -eq "Unknown") {
                                            $license = Resolve-LGNuGetLicenseFromApi -PackageId $packageId -Version $pkgVersion
                                        }

                                        $detailText = "NuGet Package: $packageId (Runtime Dependency of $binName)"
                                        if (-not $hasLicenseFile -and $license -ne "Unknown") {
                                            $detailText += " [MISSING PHYSICAL LICENSE FILE]"
                                        }

                                        Add-LGUniqueResult -Item ([PSCustomObject]@{
                                            Module       = "BinaryAudit"
                                            Name         = "Binary Dependency ($binName): $packageId"
                                            Version      = $pkgVersion
                                            Publisher    = "NuGet"
                                            License      = $license
                                            Detail       = $detailText
                                            Status       = Get-LGLicenseAuditStatus -License $license -HasMissingAttribution (-not $hasLicenseFile)
                                            ComputerName = $env:COMPUTERNAME
                                        })
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    # Skip invalid deps.json files
                }
            }

        }

        foreach ($component in $sbomComponents) {
            Add-LGUniqueResult -Item ([PSCustomObject]@{
                Module       = "BinaryAudit"
                Name         = "SBOM Dependency ($($component.Source)): $($component.Name)"
                Version      = $component.Version
                Publisher    = $component.Publisher
                License      = $component.License
                Detail       = "SBOM Package License: $($component.License)"
                Status       = Get-LGLicenseAuditStatus -License $component.License
                ComputerName = $env:COMPUTERNAME
            })
        }
    }

    $results
}
