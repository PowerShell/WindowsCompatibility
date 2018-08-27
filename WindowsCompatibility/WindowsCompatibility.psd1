###########################################################################################
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
#
# Module manifest for module 'WindowsCompatibility'
#

@{
RootModule = 'WindowsCompatibility.psm1'
ModuleVersion = '0.0.1'
CompatiblePSEditions = @('Core')
GUID = '9d427bc5-2ae1-4806-b9d1-2ae62461767e'
Author = 'PowerShell'
CompanyName = 'Microsoft Corporation'
Copyright = 'Copyright (c) Microsoft Corporation. All rights reserved'
Description = @'
This module provides compatibility utilities that allow PowerShell Core sessions to
invoke commands that are only available in Windows PowerShell. These utilities help you
to discover available modules, import those modules through proxies and then use the module
commands much as if they were native to PowerShell Core.
'@
PowerShellVersion = '6.0'
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
        Tags = @('Compatibility', 'Core')
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
'@

    } # End of PSData hashtable
} # End of PrivateData hashtable
# HelpInfoURI = ''
}
