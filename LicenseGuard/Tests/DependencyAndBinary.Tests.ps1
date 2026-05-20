#Requires -Module Pester
<#
.SYNOPSIS
    Pester v5 tests for Get-LGProjectDependencies and Get-LGBinaryLicenseAudit modules.
#>

Describe 'Dependency and Binary Audit' {
    BeforeAll {
        $modulePath = Join-Path (Split-Path $PSScriptRoot) 'LicenseGuard.psm1'
        Import-Module $modulePath -Force -ErrorAction Stop
        Initialize-LicenseGuard -Language en

        # Create temporary workspace for tests
        $script:tempWorkspace = Join-Path ([System.IO.Path]::GetTempPath()) "LG_TestWorkspace_$([guid]::NewGuid().Guid)"
        New-Item -ItemType Directory -Path $script:tempWorkspace -Force | Out-Null
    }

    AfterAll {
        # Clean up temporary workspace
        Remove-Item $script:tempWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Module LicenseGuard -ErrorAction SilentlyContinue
    }

    Context 'Project Dependencies (SCA) Scanning' {
        It 'scans Node.js NPM project dependencies and extracts licenses' {
            $projDir = Join-Path $script:tempWorkspace "NodeProj"
            $expressDir = Join-Path $projDir "node_modules/express"
            New-Item -ItemType Directory -Path $expressDir -Force | Out-Null

            # Create root package.json
            @'
{
  "name": "nodeproj",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2"
  }
}
'@ | Out-File (Join-Path $projDir "package.json") -Encoding UTF8

            # Create express package.json
            @'
{
  "name": "express",
  "version": "4.18.2",
  "license": "MIT"
}
'@ | Out-File (Join-Path $expressDir "package.json") -Encoding UTF8

            # Perform scan
            $deps = Get-LGProjectDependencies -ProjectPath $projDir

            $deps | Should -Not -BeNullOrEmpty
            $deps.Count | Should -Be 1
            $deps[0].Name | Should -Be "NodeProj: express"
            $deps[0].License | Should -Be "MIT"
            $deps[0].Publisher | Should -Be "NPM"
            $deps[0].HasLicense | Should -Be $false  # No physical LICENSE file was created
        }

        It 'scans .NET NuGet dependencies from csproj and parses nuspec cache' {
            $projDir = Join-Path $script:tempWorkspace "NetProj"
            New-Item -ItemType Directory -Path $projDir -Force | Out-Null

            # Create csproj file
            @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
  </ItemGroup>
</Project>
'@ | Out-File (Join-Path $projDir "NetProj.csproj") -Encoding UTF8

            # Mock local NuGet cache for Newtonsoft.Json
            $mockNuGetCache = Join-Path $script:tempWorkspace "mock_nuget"
            $nuspecDir = Join-Path $mockNuGetCache "newtonsoft.json/13.0.3"
            New-Item -ItemType Directory -Path $nuspecDir -Force | Out-Null

            @'
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <id>Newtonsoft.Json</id>
    <version>13.0.3</version>
    <license type="expression">MIT</license>
  </metadata>
</package>
'@ | Out-File (Join-Path $nuspecDir "newtonsoft.json.nuspec") -Encoding UTF8

            # Mock the nuget cache path internally by changing the environment variable or mocking Get-LGProjectDependencies
            # Since Get-LGProjectDependencies uses $env:USERPROFILE\.nuget\packages, we can temporarily redirect it in our test
            $oldProfile = $env:USERPROFILE
            $env:USERPROFILE = $script:tempWorkspace

            # Copy mock_nuget contents to fake USERPROFILE\.nuget\packages
            $fakeNugetFolder = Join-Path $script:tempWorkspace ".nuget/packages"
            Copy-Item -Path $mockNuGetCache/* -Destination $fakeNugetFolder -Recurse -Force -ErrorAction SilentlyContinue

            try {
                $deps = Get-LGProjectDependencies -ProjectPath $projDir

                $deps | Should -Not -BeNullOrEmpty
                $deps.Count | Should -Be 1
                $deps[0].Name | Should -Be "NetProj: Newtonsoft.Json"
                $deps[0].License | Should -Be "MIT"
                $deps[0].Publisher | Should -Be "NuGet"
            }
            finally {
                $env:USERPROFILE = $oldProfile
            }
        }
    }

    Context 'Binary License Auditing' {
        It 'audits compiled PE binary metadata, .deps.json and SBOM files' {
            $binDir = Join-Path $script:tempWorkspace "BinOutput"
            New-Item -ItemType Directory -Path $binDir -Force | Out-Null

            # Create dummy EXE
            "MZ Dummy EXE" | Out-File (Join-Path $binDir "App.exe") -Encoding ASCII

            # Create .deps.json file
            @'
{
  "runtimeTarget": {
    "name": ".NETCoreApp,Version=v8.0"
  },
  "targets": {
    ".NETCoreApp,Version=v8.0": {
      "Newtonsoft.Json/13.0.3": {
        "type": "package"
      }
    }
  }
}
'@ | Out-File (Join-Path $binDir "App.deps.json") -Encoding UTF8

            # Create CycloneDX SBOM
            @'
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "serialNumber": "urn:uuid:3e671687-397b-437f-a30b-ac4678747dfd",
  "version": 1,
  "components": [
    {
      "type": "library",
      "name": "log4net",
      "version": "2.0.15",
      "licenses": [
        {
          "license": {
            "id": "Apache-2.0"
          }
        }
      ]
    }
  ]
}
'@ | Out-File (Join-Path $binDir "bom.json") -Encoding UTF8

            # Mock local NuGet cache for App.deps.json resolution
            $oldProfile = $env:USERPROFILE
            $env:USERPROFILE = $script:tempWorkspace
            $nuspecDir = Join-Path $script:tempWorkspace ".nuget/packages/newtonsoft.json/13.0.3"
            New-Item -ItemType Directory -Path $nuspecDir -Force | Out-Null
            @'
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <id>Newtonsoft.Json</id>
    <version>13.0.3</version>
    <license type="expression">MIT</license>
  </metadata>
</package>
'@ | Out-File (Join-Path $nuspecDir "newtonsoft.json.nuspec") -Encoding UTF8

            try {
                $audit = Get-LGBinaryLicenseAudit -Path $binDir

                $audit | Should -Not -BeNullOrEmpty
                # Should have 3 results: 1 for the EXE itself, 1 from App.deps.json (Newtonsoft.Json), 1 from SBOM bom.json (log4net)
                $audit.Count | Should -Be 3

                $exeResult = $audit | Where-Object { $_.Name -eq "Binary: App.exe" }
                $exeResult | Should -Not -BeNullOrEmpty
                $exeResult.Detail | Should -Like "*[MISSING LICENSE/ATTRIBUTION FILE]*"

                $depResult = $audit | Where-Object { $_.Name -eq "Binary Dependency (App.exe): Newtonsoft.Json" }
                $depResult | Should -Not -BeNullOrEmpty
                $depResult.License | Should -Be "MIT"

                $sbomResult = $audit | Where-Object { $_.Name -eq "SBOM Dependency (bom.json): log4net" }
                $sbomResult | Should -Not -BeNullOrEmpty
                $sbomResult.License | Should -Be "Apache-2.0"
            }
            finally {
                $env:USERPROFILE = $oldProfile
            }
        }
    }
}
