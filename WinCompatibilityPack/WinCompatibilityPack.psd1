###########################################################################################
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
#
# Module manifest for module 'WinCompatibilityPack'
#

@{
RootModule = 'WinCompatibilityPack.psm1'
ModuleVersion = '0.0.1'
CompatiblePSEditions = @('Desktop','Core')
GUID = '9d427bc5-2ae1-4806-b9d1-2ae62461767e'
Author = 'PowerShell'
CompanyName = 'Microsoft Corporation'
Copyright = 'Copyright (c) Microsoft Corporation. All rights reserved'
Description = @'
This module Provides compatibility utilities that allow PowerShell Core sessions to
invoke commands that are only available in Windows PowerShell. These utilities help you
to discover available modules, import those modules through proxies and then use the module
commands much as if they were native to PowerShell Core.
'@
PowerShellVersion = '5.1'
RequiredAssemblies = if($PSEdition -eq 'Core')
{
    'netcoreapp20\Microsoft.Win32.SystemEvents.dll',
    'netcoreapp20\System.CodeDom.dll',
    'netcoreapp20\System.Configuration.ConfigurationManager.dll',
    'netcoreapp20\System.Data.DataSetExtensions.dll',
    'netcoreapp20\System.Data.Odbc.dll',
    'netcoreapp20\System.Diagnostics.EventLog.dll',
    'netcoreapp20\System.Diagnostics.PerformanceCounter.dll',
    'netcoreapp20\System.DirectoryServices.AccountManagement.dll',
    'netcoreapp20\System.DirectoryServices.dll',
    'netcoreapp20\System.DirectoryServices.Protocols.dll',
    'netcoreapp20\System.Drawing.Common.dll',
    'netcoreapp20\System.IO.Pipes.AccessControl.dll',
    'netcoreapp20\System.IO.Ports.dll',
    'netcoreapp20\System.Management.dll',
    'netcoreapp20\System.Runtime.Caching.dll',
    'netcoreapp20\System.Security.Cryptography.ProtectedData.dll',
    'netcoreapp20\System.Security.Cryptography.Xml.dll',
    'netcoreapp20\System.ServiceModel.Syndication.dll'
}
else
{
    'net472\Microsoft.Win32.Registry.AccessControl.dll',
    'net472\Microsoft.Win32.Registry.dll',
    'net472\Microsoft.Win32.SystemEvents.dll',
    'net472\System.CodeDom.dll',
    'net472\System.Configuration.ConfigurationManager.dll',
    'net472\System.Data.Odbc.dll',
    'net472\System.Data.SqlClient.dll',
    'net472\System.Diagnostics.EventLog.dll',
    'net472\System.Diagnostics.PerformanceCounter.dll',
    'net472\System.Drawing.Common.dll',
    'net472\System.IO.FileSystem.AccessControl.dll',
    'net472\System.IO.Packaging.dll',
    'net472\System.IO.Pipes.AccessControl.dll',
    'net472\System.IO.Ports.dll',
    'net472\System.Management.Automation.dll',
    'net472\System.Runtime.CompilerServices.Unsafe.dll',
    'net472\System.Security.AccessControl.dll',
    'net472\System.Security.Cryptography.Cng.dll',
    'net472\System.Security.Cryptography.Pkcs.dll',
    'net472\System.Security.Cryptography.ProtectedData.dll',
    'net472\System.Security.Cryptography.Xml.dll',
    'net472\System.Security.Permissions.dll',
    'net472\System.Security.Principal.Windows.dll',
    'net472\System.ServiceModel.Duplex.dll',
    'net472\System.ServiceModel.Http.dll',
    'net472\System.ServiceModel.NetTcp.dll',
    'net472\System.ServiceModel.Primitives.dll',
    'net472\System.ServiceModel.Syndication.dll',
    'net472\System.ServiceProcess.ServiceController.dll',
    'net472\System.Text.Encoding.CodePages.dll',
    'net472\System.Threading.AccessControl.dll'
}
FunctionsToExport = @(
    'Initialize-WinSession',
    'Add-WinFunction',
    'Invoke-WinCommand',
    'Get-WinModule',
    'Import-WinModule',
    'Compare-WinModule',
    'Copy-WinModule',
    'Add-WindowsPSModulePath'
)
PrivateData = @{
    PSData = @{
        Tags = @('Compatibility', 'Desktop', 'Core')
        LicenseUri = 'https://opensource.org/licenses/MIT'
        ProjectUri = 'https://github.com/PowerShell/WindowsPowerShellCompatibilityPack'
        ReleaseNotes = @'
This is the first release of this module with the basic commands:
    Initialize-WinSession
    Add-WinFunction
    Invoke-WinCommand
    Get-WinModule
    Import-WinModule
    Compare-WinModule
    Copy-WinModule
These commands provide a set of tools allowing you to run Windows PowerShell
commands from PowerShell Core (PowerShell 6). See the help for the
individual commands for examples on how to use this functionality.

Additionally, the command `Add-WindowsPSModulePath` enables enumerating
existing Windows PowerShell modules within PowerShell Core 6.

The .Net Windows Compatibility Pack is included in this module exposing
more .Net APIs you can use with PowerShell.
'@

    } # End of PSData hashtable
} # End of PrivateData hashtable
# HelpInfoURI = ''
}
