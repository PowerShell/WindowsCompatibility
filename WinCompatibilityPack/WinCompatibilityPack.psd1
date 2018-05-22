###########################################################################################
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
#
# Module manifest for module 'WinCompatibilityPack'
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'WinCompatibilityPack.psm1'

# Version number of this module.
ModuleVersion = '0.0.1'

# Supported PSEditions
CompatiblePSEditions = @('Desktop','Core')

# ID used to uniquely identify this module
GUID = '9d427bc5-2ae1-4806-b9d1-2ae62461767e'

# Author of this module
Author = 'PowerShell'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = 'Copyright (c) Microsoft Corporation. All rights reserved'

# Description of the functionality provided by this module
Description = @'
This module Provides compatibility utilities that allow PowerShell Core sessions to
invoke commands that are only available in Windows PowerShell. These utilities help you
to discover available modules, import those modules through proxies and then use the module
commands much as if they were native to PowerShell Core.
'@

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
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

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('Compatibility', 'Desktop', 'Core')

        # A URL to the license for this module.
        LicenseUri = 'https://opensource.org/licenses/MIT'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PowerShell/WindowsPowerShellCompatibilityPack'

        # A URL to an icon representing this module.
        # IconUri = ''

        # Release Notes of this module
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

# HelpInfo URI of this module
# HelpInfoURI = ''

}
