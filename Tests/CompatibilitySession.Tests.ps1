# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces

Describe "Test the Windows PowerShell Compatibility Session functions" {

    BeforeAll {
        Import-Module -Force ..\WinCompatibilityPack\WinCompatibilityPack.psd1
    }
    
    It "Make sure the <command> command exists" -TestCases @(
        @{command = 'Initialize-WinSession'},
        @{command = 'Add-WinFunction'},
        @{command = 'Invoke-WinCommand'},
        @{command = 'Get-WinModule'},
        @{command = 'Import-WinModule'},
        @{command = 'Compare-WinModule'},
        @{command = 'Copy-WinModule'},
        @{command = 'awinf'},
        @{command = 'cpwinm'},
        @{command = 'cwinm'},
        @{command = 'gwinm'},
        @{command = 'iwinc'},
        @{command = 'iwinm'},
        @{command = 'iwins'}
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
        $info.Name | Should -BeExactly PnpDevice 
    }

    It "Import-WinModule should import the PnpDevice module" {
        # Remove the PnpDevice module if it's installed
        Get-Module PnpDevice | Remove-Module

        # Now import the proxy module, returning the ModuleInfo object
        $info = Import-WinModule PnpDevice -PassThru
        $info | Should -Not -BeNullOrEmpty
        $info.Name | Should -BeExactly PnpDevice
        $info.ModuleType | Should -BeExactly "Script"

        # Verify that the commands were imported as proxies
        $cmd = Get-Command Get-PnpDevice
        $cmd.CommandType | Should -BeExactly "Function"

        # Make sure the command actually runs
        $results = Get-PnpDevice
        $results | Should -Not -BeNullOrEmpty
        $results | Should -BeOfType ([Microsoft.Management.Infrastructure.CimInstance])

        # Clean up
        Get-Module PnpDevice | Remove-Module
    }

    It "Import-WinModule Microsoft.PowerShell.Management should import new commands but not overwrite existing ones" {
        # Remove the proxy module if present
        Get-Module Microsoft.PowerShell.Management |
            Where-Object ModuleType -eq Script |
                Remove-Module
        # Import the proxy module
        Import-WinModule  Microsoft.PowerShell.Management
        $cmd = Get-Command Get-ChildItem
        $cmd.Module.ModuleType | Should -BeExactly Manifest
        $cmd2 = Get-Command Get-EventLog
        $cmd2.Module.ModuleType | Should -BeExactly Script
        Get-EventLog -LogName Application -Newest 1 | Should -Not -BeNullOrEmpty
    }

    It "Add-WinFunction should define a function in the current session and return information from the compatibility session" {
        Remove-Item -ErrorAction Ignore function:myFunction
        Add-WinFunction myFunction {param ($n) "Hi $n!"; $PSVersionTable.PSEdition }
        $function:myFunction | Should -Not -BeNullOrEmpty
        $msg, $edition = myFunction Bill
        $msg | Should -BeExactly "Hi Bill!"
        $edition | Should -BeExactly Desktop
    }

    It "Invoke-WinCommand should return information from the compatibility session" {
        $result = Invoke-WinCommand { $PSVersionTable.PSEdition }
        $result | Should -BeExactly Desktop
    }

    It "Compare-WinModule should return a non-null collection of modules" {
        $modules = Compare-WinModule Azure* 
        $modules | Should -Not -BeNullOrEmpty
    }

    It "Copy-WinModule should copy the specified module to the destination path" {
        $tempDirToUse = Join-Path TestDrive: "tmp$(Get-Random)"
        New-Item -ItemType directory $tempDirToUse

        Copy-WinModule PnpDevice -Destination $tempDirToUse
        # Ensure that the module directory exists
        Join-Path $tempDirToUse PnpDevice | Should -Exist
        # And the .psd1 file
        Join-Path $tempDirToUse PnpDevice PnpDevice.psd1 | Should -Exist
        # Ensure that only 1 module got copied
        (Get-Childitem $tempDirToUse).Count | Should -BeExactly 1
    }
}
