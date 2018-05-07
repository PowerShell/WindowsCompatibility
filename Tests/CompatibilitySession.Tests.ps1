using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Test the Compatibility Session functions" {

    BeforeAll {
        Import-Module -Force ..\WPSCompatibilityPack\WPSCompatibilityPack.psd1
    }
    
    It "Makes sure the Initialize-WPSCPSession command exist" {
        Get-Command Initialize-WPSCPSession | Should -Not -BeNullOrEmpty
    }
    It "Makes sure the Add-WPSCPFunction command exist" {
        Get-Command Add-WPSCPFunction | Should -Not -BeNullOrEmpty
    }
    It "Makes sure the Invoke-WPSCPCommand command exist" {
        Get-Command  Invoke-WPSCPCommand | Should -Not -BeNullOrEmpty
    }
    It "Makes sure the Get-WPSCPModule command exist" {
        Get-Command  Get-WPSCPModule | Should -Not -BeNullOrEmpty
    }
    It "Makes sure the Import-WPSCPModule command exist" {
        Get-Command  Import-WPSCPModule | Should -Not -BeNullOrEmpty
    }
    It "Makes sure the Compare-WPSCPModule command exist" {
        Get-Command  Compare-WPSCPModule | Should -Not -BeNullOrEmpty
    }
    It "Makes sure the Copy-WPSCPModule command exist" {
        Get-Command  Copy-WPSCPModule | Should -Not -BeNullOrEmpty
    }

    It "Calling Initialize-WPSCPSession should return a valid session" {
        Initialize-WPSCPSession -PassThru | Should -BeOfType ([PSSession])
    }

    It "Multiple calls to Initialize-WPSCPSession shouild return the same session" {
        $first = Initialize-WPSCPSession -PassThru
        $second = Initialize-WPSCPSession -PassThru 
        $first -eq $second | Should -BeTrue
    }

    It "Get-WPSCPModule should return a single value for PnpDevice" {
        $info = Get-WPSCPModule PnpDevice
        $info | Should -Not -BeNullOrEmpty
        $info.Name | Should -BeExactly PnpDevice 
    }

    It "Import-WPSCPModule should import the PnpDevice module" {
        # Remove the PnpDevice module if it's installed
        Get-Module PnpDevice | Remove-Module
        # Now import the proxy module, returning the ModuleInfo object
        $info = Import-WPSCPModule PnpDevice -PassThru
        $info | Should -Not -BeNullOrEmpty
        $info.Name | Should -BeExactly PnpDevice
        $info.ModuleType | Should -BeExactly "Script"
        # Verify that the commands were imported as proxies
        $cmd = Get-Command Get-PnpDevice
        $cmd.CommandType | Should -BeExactly "Function"
        # Make sure the command actually runs
        $results = Get-PnpDevice
        $results | Should -Not -BeNullOrEmpty
        # Clean up
        Get-Module PnpDevice | Remove-Module
    }

    It "Import-WPSCPModule Microsoft.PowerShell.Management should import new commands but not overwrite existing ones" {
        # Remove the proxy module if present
        Get-Module Microsoft.PowerShell.Management |
            Where-Object ModuleType -eq Script |
                Remove-Module
        # Import the proxy module
        Import-WPSCPModule  Microsoft.PowerShell.Management
        $cmd = Get-Command Get-ChildItem
        $cmd.Module.ModuleType | Should -BeExactly Manifest
        $cmd2 = Get-Command Get-EventLog
        $cmd2.Module.ModuleType | Should -BeExactly Script
        Get-EventLog -LogName Application -Newest 1 | Should -Not -BeNullOrEmpty
    }

    It "Add-WPSCPFunction should define a function in the current session and return information from the compatibility session" {
        Remove-Item -ErrorAction Ignore function:myFunction
        Add-WPSCPFunction myFunction {param ($n) "Hi $n!"; $PSVersionTable.PSEdition }
        $function:myFunction | Should -Not -BeNullOrEmpty
        $msg, $edition = myFunction Bill
        $msg | Should -BeExactly "Hi Bill!"
        $edition | Should -BeExactly Desktop
    }

    It "Invoke-WPSCPCommand should return information from the compatibility session" {
        $result = Invoke-WPSCPCommand { $PSVersionTable.PSEdition }
        $result | Should -BeExactly Desktop
    }

    It "Compare-WPSCPModule should return a non-null collection of modules" {
        $modules = Compare-WPSCPModule Azure* 
        $modules | Should -Not -BeNullOrEmpty
    }

    It "Copy-WPSCPModule should copy the specified module to the destination path" {
        $tempDirToUse = Join-Path ([Io.Path]::GetTempPath()) "tmp$(Get-Random)"
        if (Test-Path $tempDirToUse)
        {
            Remove-Item -Recurse -Force $tempDirToUse
        }
        mkdir $tempDirToUse

        try {
            Copy-WPSCPModule PnpDevice -Destination $tempDirToUse
            Join-Path $tempDirToUse PnpDevice | Should -Exist
            (Get-Childitem $tempDirToUse).Count | Should -BeExactly 1
        }
        finally {
            Remove-Item -Recurse -Force $tempDirToUse
        }
    }
}
