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
    try
    {
        Remove-Item -Path $outputPath -Recurse -Force -ErrorAction Stop
    }
    catch [System.Management.Automation.ItemNotFoundException]
    {
        Write-Warning "$outputPath does not exist.  Skipping clean."
    }
}

$pscore6assemblies = @(
    'Microsoft.Win32.Registry.AccessControl.dll',
    'Microsoft.Win32.Registry.dll',
    'mscorlib.dll',
    'sni.dll',
    'System.ComponentModel.Composition.dll',
    'System.Configuration.dll',
    'System.Core.dll',
    'System.Data.dll',
    'System.Data.SqlClient.dll',
    'System.Diagnostics.DiagnosticSource.dll',
    'System.dll',
    'System.Drawing.dll',
    'System.IO.FileSystem.AccessControl.dll',
    'System.IO.Packaging.dll',
    'System.Memory.dll',
    'System.Net.dll',
    'System.Net.Http.WinHttpHandler.dll',
    'System.Runtime.CompilerServices.Unsafe.dll',
    'System.Security.AccessControl.dll',
    'System.Security.Cryptography.Pkcs.dll',
    'System.Security.dll',
    'System.Security.Permissions.dll',
    'System.Security.Principal.Windows.dll',
    'System.ServiceModel.dll',
    'System.ServiceModel.Duplex.dll',
    'System.ServiceModel.Http.dll',
    'System.ServiceModel.NetTcp.dll',
    'System.ServiceModel.Primitives.dll',
    'System.ServiceModel.Security.dll',
    'System.ServiceModel.Web.dll',
    'System.ServiceProcess.dll',
    'System.ServiceProcess.ServiceController.dll',
    'System.Text.Encoding.CodePages.dll',
    'System.Threading.AccessControl.dll',
    'System.Transactions.dll',
    'WindowsBase.dll'
)

$otherExcludedAssmblies = @(
    'WinCompatibilityPack.dll'
)

foreach ($target in @('netcoreapp20','net472'))
{
    Write-Verbose "Building for $target" -Verbose
    dotnet publish .\WinCompatibilityPack -c Release -f $target -r win-x64
    $null = New-Item "$outputPath\$target" -ItemType Directory -Force -ErrorAction SilentlyContinue
    foreach ($assembly in (Get-ChildItem ".\WinCompatibilityPack\bin\Release\$target\win-x64\publish\*.dll"))
    {
        if ($otherExcludedAssemblies -contains $assembly.Name -or
            ($target -eq 'netcoreapp20' -and $pscore6assemblies -contains $assembly.Name))
        {
            continue
        }
        Copy-Item $assembly -Destination "$outputPath\$target" -Force
    }
}

foreach ($file in @('WinCompatibilityPack.psd1','WinCompatibilityPack.psm1'))
{
    Copy-Item .\WinCompatibilityPack\$file -Destination $outputPath
}

Write-Verbose "Converting help" -Verbose
New-ExternalHelp -OutputPath $outputPath -Path .\docs\Module\ -Force

Write-Verbose "Module saved to: $outputPath" -Verbose
