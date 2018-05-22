###########################################################################################
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

#region Dependency checks

param(
    [switch] $Clean
)

if ($null -eq (Get-Command New-ExternalHelp -ErrorAction SilentlyContinue))
{
    throw "Please install PlatyPS using: Install-Module PlatyPS -Scope currentuser"
}

if ($null -eq (Get-Command dotnet -ErrorAction SilentlyContinue))
{
    throw "'dotnet' not found in path.  Please install DotNetCli from https://dot.net/core"
}

#endregion Dependency checks

$currentPath = Split-Path $MyInvocation.MyCommand.Path -Parent
$outputPath = Join-Path -Path $currentPath -ChildPath "bin"

if ($Clean)
{
    Write-Verbose "Cleaning $outputPath" -Verbose
    Remove-Item -Path $outputPath -Recurse -Force
}

foreach ($target in @('netcoreapp20','net472'))
{
    Write-Verbose "Building for $target" -Verbose
    dotnet publish .\WinCompatibilityPack -c Release -f $target -r win-x64
    $null = New-Item "$outputPath\$target" -ItemType Directory -Force -ErrorAction SilentlyContinue
    Copy-Item .\WinCompatibilityPack\bin\Release\$target\win-x64\publish\*.dll -Destination "$outputPath\$target" -Exclude WinCompatibilityPack.dll -Force
}
Copy-Item .\WinCompatibilityPack\bin\Release\netcoreapp20\* -Destination $outputPath -Exclude "Publish"

Write-Verbose "Converting help" -Verbose
New-ExternalHelp -OutputPath $outputPath -Path .\docs\Module\ -Force

Write-Verbose "Module saved to: $outputPath" -Verbose
