function Get-LGProjectDependencies {
    <#
    .SYNOPSIS
        Scans project directories for dependencies (e.g. Node.js node_modules and .NET NuGet csproj) and extracts their licenses.
        Can scan recursively if multiple projects exist under a specified path.
        Also verifies if the physical license files exist within the packages and project roots.
    .EXAMPLE
        Get-LGProjectDependencies -ProjectPath "C:\Projects\MyApp"
    .EXAMPLE
        Get-LGProjectDependencies -ProjectPath "C:\Projects"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$ProjectPath
    )

    $L = Get-LGEffectiveStrings
    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()
    $foundPackages = @{}

    # Common filenames for license texts
    $licenseFilePatterns = @("LICENSE*", "LICENSES*", "COPYING*", "NOTICE*", "LICENSE-MIT*", "LICENSE-APACHE*")

    foreach ($path in $ProjectPath) {
        if (-not (Test-Path $path)) {
            Write-Warning "Project path not found: $path"
            continue
        }

        # --- A. Node.js (NPM) Discovery ---
        # Find all project roots (folders containing package.json, but not inside node_modules)
        $projectFiles = Get-ChildItem -Path $path -Filter "package.json" -Recurse -ErrorAction SilentlyContinue | 
                        Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }

        # If no package.json is found recursively, check if the path itself is a project root with node_modules
        $projectDirs = @()
        if ($projectFiles) {
            $projectDirs = $projectFiles | ForEach-Object { $_.DirectoryName }
        } elseif (Test-Path (Join-Path $path "node_modules")) {
            $projectDirs = @($path)
        }

        # Deduplicate directories
        $projectDirs = $projectDirs | Select-Object -Unique

        # Scan each discovered Node.js project
        foreach ($dir in $projectDirs) {
            # Check if project root has a license file
            $rootLicenseFiles = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue | 
                                Where-Object { $_.Name -like "LICENSE*" -or $_.Name -like "3rdpartylicenses*" -or $_.Name -like "LICENSES*" }
            
            if (-not $rootLicenseFiles) {
                Write-Host "  [WARN] NPM Project '$($dir)' does not have a root LICENSE or 3rdpartylicenses file!" -ForegroundColor Yellow
            } else {
                Write-Host "  [OK] Found NPM project license/attribution files: $(($rootLicenseFiles | Select-Object -ExpandProperty Name) -join ', ')" -ForegroundColor Green
            }

            $nodeModulesPath = Join-Path $dir "node_modules"
            if (-not (Test-Path $nodeModulesPath)) {
                continue
            }

            Write-Host "  Scanning NPM dependencies in $dir..." -ForegroundColor Cyan
            $packages = Get-ChildItem -Path $nodeModulesPath -Filter "package.json" -Recurse -Depth 4 -ErrorAction SilentlyContinue

            foreach ($pkg in $packages) {
                try {
                    $json = Get-Content $pkg.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
                    if ($json -and $json.name) {
                        $projectName = Split-Path $dir -Leaf
                        $key = "npm_$($projectName)_$($json.name)_$($json.version)"
                        if ($foundPackages.ContainsKey($key)) { continue }
                        $foundPackages[$key] = $true

                        $license = "Unknown"
                        if ($null -ne $json.license) {
                            if ($json.license -is [string]) { $license = $json.license }
                            elseif ($null -ne $json.license.type) { $license = $json.license.type }
                        } elseif ($null -ne $json.licenses -and $json.licenses.Count -gt 0) {
                            if ($null -ne $json.licenses[0].type) {
                                $license = $json.licenses[0].type
                            } elseif ($json.licenses[0] -is [string]) {
                                $license = $json.licenses[0]
                            }
                        }

                        # Check if physical license file exists
                        $packageDir = $pkg.DirectoryName
                        $hasLicenseFile = $false
                        foreach ($pattern in $licenseFilePatterns) {
                            $files = Get-ChildItem -Path $packageDir -Filter $pattern -File -ErrorAction SilentlyContinue
                            if ($files -and $files.Count -gt 0) {
                                $hasLicenseFile = $true
                                break
                            }
                        }

                        $detailText = "Package License: $license (Project: $projectName)"
                        if (-not $hasLicenseFile -and $license -ne "Unknown") {
                            $detailText += " [MISSING PHYSICAL LICENSE FILE]"
                        }

                        $deps.Add([PSCustomObject]@{
                            Name         = "$($projectName): $($json.name)"
                            Version      = $json.version
                            Publisher    = "NPM"
                            License      = $license
                            Detail       = $detailText
                            Status       = "OK"
                            ComputerName = $env:COMPUTERNAME
                            HasLicense   = $hasLicenseFile
                        })
                    }
                } catch {}
            }
        }

        # --- B. .NET (NuGet) Discovery ---
        # Find all .csproj files recursively (ignoring bin/obj directories)
        $csprojFiles = Get-ChildItem -Path $path -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue | 
                       Where-Object { $_.FullName -notmatch '[\\/]obj[\\/]' -and $_.FullName -notmatch '[\\/]bin[\\/]' }

        foreach ($csproj in $csprojFiles) {
            $projectName = Split-Path $csproj.DirectoryName -Leaf
            Write-Host "  Scanning NuGet dependencies in $($csproj.Name)..." -ForegroundColor Cyan

            # Check if project root has a license file
            $rootLicenseFiles = Get-ChildItem -Path $csproj.DirectoryName -File -ErrorAction SilentlyContinue | 
                                Where-Object { $_.Name -like "LICENSE*" -or $_.Name -like "3rdpartylicenses*" -or $_.Name -like "LICENSES*" }
            
            if (-not $rootLicenseFiles) {
                Write-Host "  [WARN] .NET Project '$projectName' does not have a root LICENSE or 3rdpartylicenses file!" -ForegroundColor Yellow
            }

            try {
                [xml]$xml = Get-Content $csproj.FullName -ErrorAction Stop
                
                # Find all PackageReference nodes
                $packageRefs = $xml.SelectNodes("//PackageReference")
                
                foreach ($ref in $packageRefs) {
                    $packageId = $ref.Include
                    $version = $ref.Version
                    
                    if (-not $version -and $ref.HasAttribute("Version")) {
                        $version = $ref.GetAttribute("Version")
                    }
                    if (-not $version) {
                        $verNode = $ref.SelectSingleNode("Version")
                        if ($verNode) { $version = $verNode.InnerText }
                    }

                    if (-not $packageId -or -not $version) { continue }

                    # Track unique NuGet package per project
                    $key = "nuget_${projectName}_${packageId}_${version}"
                    if ($foundPackages.ContainsKey($key)) { continue }
                    $foundPackages[$key] = $true

                    # Resolve license from local NuGet cache
                    $nugetCache = Join-Path $env:USERPROFILE ".nuget\packages"
                    $pkgFolder = Join-Path $nugetCache $packageId.ToLowerInvariant()
                    $versionFolder = Join-Path $pkgFolder $version
                    $nuspecPath = Join-Path $versionFolder "$($packageId.ToLowerInvariant()).nuspec"
                    
                    $license = "Unknown"
                    $hasLicenseFile = $false
                    
                    if (Test-Path $nuspecPath) {
                        try {
                            [xml]$nuspecXml = Get-Content $nuspecPath
                            
                            # NuSpec XML elements are usually namespaced
                            $ns = New-Object System.Xml.XmlNamespaceManager($nuspecXml.NameTable)
                            $ns.AddNamespace("ns", $nuspecXml.DocumentElement.NamespaceURI)
                            
                            $licenseNode = $nuspecXml.SelectSingleNode("//ns:license", $ns)
                            if ($licenseNode) {
                                $license = $licenseNode.InnerText
                            } else {
                                $licenseUrlNode = $nuspecXml.SelectSingleNode("//ns:licenseUrl", $ns)
                                if ($licenseUrlNode) {
                                    # Use the URL if metadata tag isn't set, e.g. mapping to SPDX format if recognizable
                                    $url = $licenseUrlNode.InnerText
                                    if ($url -match "licenses.nuget.org/MIT" -or $url -match "opensource.org/licenses/MIT") { $license = "MIT" }
                                    elseif ($url -match "licenses.nuget.org/Apache-2.0") { $license = "Apache-2.0" }
                                    else { $license = $url }
                                }
                            }
                            
                            # Check physical license files in package folder
                            foreach ($pattern in $licenseFilePatterns) {
                                $files = Get-ChildItem -Path $versionFolder -Filter $pattern -File -ErrorAction SilentlyContinue
                                if ($files -and $files.Count -gt 0) {
                                    $hasLicenseFile = $true
                                    break
                                }
                            }
                        } catch {}
                    }
                    
                    $detailText = "Package License: $license (Project: $projectName)"
                    if (-not $hasLicenseFile -and $license -ne "Unknown") {
                        $detailText += " [MISSING PHYSICAL LICENSE FILE]"
                    }

                    $deps.Add([PSCustomObject]@{
                        Name         = "$($projectName): $($packageId)"
                        Version      = $version
                        Publisher    = "NuGet"
                        License      = $license
                        Detail       = $detailText
                        Status       = "OK"
                        ComputerName = $env:COMPUTERNAME
                        HasLicense   = $hasLicenseFile
                    })
                }
            } catch {}
        }
    }

    if ($deps.Count -gt 0) {
        Write-Host ("  {0} project dependencies found in total." -f $deps.Count) -ForegroundColor DarkGray
    }

    $deps
}
