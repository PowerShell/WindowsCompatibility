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

#endregion Dependency checks

$currentPath = Split-Path $MyInvocation.MyCommand.Path -Parent
$outputPath = Join-Path -Path $currentPath -ChildPath "bin"

if ($Clean)
{
    Write-Verbose "Cleaning $outputPath" -Verbose
    try
    {
        Remove-Item -Path $outputPath -Recurse -Force -ErrorAction Stop
    }
    catch [System.Management.Automation.ItemNotFoundException]
    {
        Write-Warning "$outputPath does not exist.  Skipping clean."
    }
}

if (-not (Test-Path -PathType Container $outputPath))
{
    New-Item -ItemType Directory -Path $outputPath
}

foreach ($file in @('WindowsCompatibility.psd1','WindowsCompatibility.psm1'))
{
    Copy-Item .\WindowsCompatibility\$file -Destination $outputPath
}

Write-Verbose "Converting help" -Verbose
New-ExternalHelp -OutputPath $outputPath -Path .\docs\Module\ -Force

Write-Verbose "Module saved to: $outputPath" -Verbose
