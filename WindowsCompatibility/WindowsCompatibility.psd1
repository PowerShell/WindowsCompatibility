###########################################################################################
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
#
# Module manifest for module 'WindowsCompatibility'
#

@{
RootModule = 'WindowsCompatibility.psm1'
ModuleVersion = '1.0.0'
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
AliasesToExport = @('Add-WinPSModulePath')
PrivateData = @{
    PSData = @{
        Tags = @('WindowsPowerShell', 'Compatibility', 'Core')
        LicenseUri = 'https://opensource.org/licenses/MIT'
        ProjectUri = 'https://github.com/PowerShell/WindowsCompatibility'
        ReleaseNotes = @'
This module provides a set of commands that allow you to use
Windows PowerShell modules from PowerShell Core (PowerShell 6).
The following commands are included: 
    Initialize-WinSession
    Add-WinFunction
    Invoke-WinCommand
    Get-WinModule
    Import-WinModule
    Compare-WinModule
    Copy-WinModule
See the help for the individual commands for examples on how
to use this functionality.

Additionally, the command `Add-WindowsPSModulePath` will update
your $ENV:PSModulePath to include Windows PowerShell module directories
within PowerShell Core 6.

NOTE: This release is only intended to be used with PowerShell Core 6
running on Microsoft Windows. Linux and MacOS are not supported at this
time.
'@

    } # End of PSData hashtable
} # End of PrivateData hashtable
# HelpInfoURI = ''
}
