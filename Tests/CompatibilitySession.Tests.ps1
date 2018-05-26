# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces

$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

Describe "Test the Windows PowerShell Compatibility Session functions" {

    BeforeAll {
        Import-Module -Force "$scriptPath\..\WinCompatibilityPack\bin\release\netstandard2.0\publish\WinCompatibilityPack.psd1"
    }

    It "Make sure the <command> command exists" -TestCases @(
        @{command = 'Initialize-WinSession'},
        @{command = 'Add-WinFunction'},
        @{command = 'Invoke-WinCommand'},
        @{command = 'Get-WinModule'},
        @{command = 'Import-WinModule'},
        @{command = 'Compare-WinModule'},
        @{command = 'Copy-WinModule'}
        ) {
            param($command)
            Get-Command $command | Should -Not -BeNullOrEmpty
        }

    It "Calling Initialize-WinSession should return a valid session" {
        Initialize-WinSession -PassThru | Should -BeOfType ([PSSession])
    }

    It "Multiple calls to Initialize-WinSession shouild return the same session" {
        $first = Initialize-WinSession -PassThru
        $second = Initialize-WinSession -PassThru
        $first | Should -Be $second
    }

    It "Get-WinModule should return a single value for PnpDevice" {
        $info = Get-WinModule PnpDevice
        $info | Should -Not -BeNullOrEmpty
        $info.Name | Should -BeExactly "PnpDevice"
    }

    It "Import-WinModule should import the PnpDevice module" -Skip:($PSEdition -eq "Desktop") {
        # Remove the PnpDevice module if it's installed
        Get-Module PnpDevice | Remove-Module

        # Now import the proxy module, returning the ModuleInfo object
        $info = Import-WinModule PnpDevice -PassThru
        $info | Should -Not -BeNullOrEmpty
        $info.Name | Should -BeExactly "PnpDevice"
        $info.ModuleType | Should -BeExactly "Script"

        # Verify that the commands were imported as proxies
        $cmd = Get-Command Get-PnpDevice
        $cmd.CommandType | Should -BeExactly "Function"

        # Make sure the command actually runs
        $results = Get-PnpDevice
        $results | Should -Not -BeNullOrEmpty
        $results | Should -BeOfType ([Microsoft.Management.Infrastructure.CimInstance])
        $results[0].PSObject.TypeNames[0] | Should -Be 'Microsoft.Management.Infrastructure.CimInstance#ROOT/cimv2/Win32_PnPEntity'

        # Clean up
        Get-Module PnpDevice | Remove-Module
    }

    It "Import-WinModule Microsoft.PowerShell.Management should import new commands but not overwrite existing ones" -Skip:($PSEdition -eq "Desktop") {
        # Remove the proxy module if present
        Get-Module Microsoft.PowerShell.Management |
            Where-Object ModuleType -eq Script |
                Remove-Module
        # Import the proxy module
        Import-WinModule  Microsoft.PowerShell.Management
        # Verify that the module is named with ".WinModule" appended
        Get-Module "Microsoft.PowerShell.Management.WinModule" | Should -Not -BeNullOrEmpty 
        # Verify PS Core native commands don't get overridden
        $cmd = Get-Command Get-ChildItem
        $cmd.Module.ModuleType | Should -BeExactly "Manifest"
        # but the extra commands are imported
        $cmd2 = Get-Command Get-EventLog
        $cmd2.Module.ModuleType | Should -BeExactly "Script"
        # and that these commands work
        $ele = Get-EventLog -LogName Application -Newest 1
        $ele | Should -Not -BeNullOrEmpty
        $ele.PSObject.TypeNames -eq 'Deserialized.System.Diagnostics.EventLogEntry' | Should -Be Deserialized.System.Diagnostics.EventLogEntry
    }

    It "Add-WinFunction should define a function in the current session and return information from the compatibility session" {
        Remove-Item -ErrorAction Ignore function:myFunction
        Add-WinFunction myFunction {param ($n) "Hi $n!"; $PSVersionTable.PSEdition }
        $function:myFunction | Should -Not -BeNullOrEmpty
        $msg, $edition = myFunction Bill
        $msg | Should -BeExactly "Hi Bill!"
        $edition | Should -BeExactly "Desktop"
    }

    It "Invoke-WinCommand should return information from the compatibility session" {
        $result = Invoke-WinCommand { $PSVersionTable.PSEdition }
        $result | Should -BeExactly "Desktop"
    }

    It "Compare-WinModule should return a non-null collection of modules" -Skip:($PSEdition -eq "Desktop") {
        $pattern = 'Azure*'
        $modules = Compare-WinModule $pattern
        $modules | Should -Not -BeNullOrEmpty
        $modules[0].Name | Should -BeLike $pattern
    }

    It "Copy-WinModule should copy the specified module to the destination path" -Skip:($PSEdition -eq "Desktop") {
        $tempDirToUse = Join-Path TestDrive: "tmp$(Get-Random)"
        New-Item -ItemType directory $tempDirToUse

        # Invoke the command to copy the module
        Copy-WinModule PnpDevice -Destination $tempDirToUse

        # Ensure that the module directory exists
        Join-Path $tempDirToUse PnpDevice | Should -Exist
        # And the .psd1 file
        $psd1File = Join-Path $tempDirToUse PnpDevice PnpDevice.psd1
        $psd1File | Should -Exist
        # Ensure that only 1 module got copied
        (Get-Childitem $tempDirToUse).Count | Should -BeExactly 1

        # Now verify that the local module can be loaded and used

        # First make sure that the module is not already loaded (it shouldn't be)
        Get-Module PnpDevice | Remove-Module -ErrorAction Ignore
        # Load the module and verify the type
        $info = Import-Module $psd1File -PassThru
        $info | Should -Not -BeNullOrEmpty
        $info.Name | Should -BeExactly "PnpDevice"
        $info.ModuleType | Should -BeExactly "Manifest"

        # Verify that the commands were imported as proxies
        $cmd = Get-Command Get-PnpDevice
        $cmd.CommandType | Should -BeExactly "Function"

        # Make sure the command actually runs
        $results = Get-PnpDevice
        $results | Should -Not -BeNullOrEmpty
        $results | Should -BeOfType ([Microsoft.Management.Infrastructure.CimInstance])
        $results[0].PSObject.TypeNames[0] | Should -BeExactly 'Microsoft.Management.Infrastructure.CimInstance#ROOT/cimv2/Win32_PnPEntity'

        # Finally remove the module from memory to clean up
        Remove-Module PnpDevice
    }

    It "Copy-WinModule should copy the specified module to the user's module path by default" -Skip:($PSEdition -eq "Desktop") {

        # Get the user's module folder path
        $destination = [environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments),
                            "PowerShell",
                                "Modules"
        $fullModulePath = Join-Path $destination PnpDevice

        # Only run the test if the user's module directory exists but they
        # haven't copied the PnpDevice module already.
        if ((Test-Path $destination) -and -not (Test-Path $fullModulePath))
        {
            # Invoke the command to copy the module
            Copy-WinModule PnpDevice

            # Ensure that the module directory exists
            $fullModulePath | Should -Exist
            # And the .psd1 file
            $psd1File = Join-Path $fullModulePath PnpDevice.psd1
            $psd1File | Should -Exist
            # Ensure that only 1 module got copied
            (Get-Childitem $tempDirToUse).Count | Should -BeExactly 1

            # Now verify that the local module can be loaded and used

            # First make sure that the module is not already loaded (it shouldn't be)
            Get-Module PnpDevice | Remove-Module -ErrorAction Ignore
            # Load the module using just the module name and verify the type
            $info = Import-Module PnpDevice -PassThru
            $info | Should -Not -BeNullOrEmpty
            $info.Name | Should -BeExactly "PnpDevice"
            $info.ModuleType | Should -BeExactly "Manifest"

            # Verify that the commands were imported as proxies
            $cmd = Get-Command Get-PnpDevice
            $cmd.CommandType | Should -BeExactly "Function"

            # Make sure the command actually runs
            $results = Get-PnpDevice
            $results | Should -Not -BeNullOrEmpty
            $results | Should -BeOfType ([Microsoft.Management.Infrastructure.CimInstance])
            $results[0].PSObject.TypeNames[0] | Should -BeExactly 'Microsoft.Management.Infrastructure.CimInstance#ROOT/cimv2/Win32_PnPEntity'

            # Finally remove the module from memory to clean up
            Remove-Module PnpDevice
            # And remove them module if we installed it
            Remove-Item -Recurse $fullModulePath
        }
    }
}
