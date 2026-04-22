$ErrorActionPreference = 'SilentlyContinue'

$script:LGVersion     = '3.0.0'
$script:LGConfig      = $null
$script:LGStrings     = $null
$script:LGEolDatabase = $null

$private = Join-Path $PSScriptRoot 'Private'
Get-ChildItem $private -Filter '*.ps1' -ErrorAction Stop | ForEach-Object { . $_.FullName }

$public = Join-Path $PSScriptRoot 'Public'
$publicFiles = Get-ChildItem $public -Filter '*.ps1' -ErrorAction Stop
$publicFiles | ForEach-Object { . $_.FullName }

Export-ModuleMember -Function '*'
