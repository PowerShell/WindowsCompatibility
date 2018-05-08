###########################################################################################
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

#requires -Version 6

using namespace System.Management.Automation.
using namespace System.Management.Automation.Runspaces

Set-StrictMode -Version latest

###########################################################################################
# A list of modules native to PowerShell Core that should never be imported
$NeverImportList = @(
    "PSReadLine",
    "PackageManagement",
    "PowerShellGet",
    "Microsoft.PowerShell.Archive",
    "Microsoft.PowerShell.Host",
    "WinCompatibilityPack"
)

###########################################################################################
# The following is a list of modules native to PowerShell Core that don't have all of
# the functionality of Windows PowerShell 5.1 versions. These modules can be imported but 
# will not over-write any existing PowerShell Core commands
$NeverClobberList = @(
    "Microsoft.PowerShell.Management",
    "Microsoft.PowerShell.Utility",
    "Microsoft.PowerShell.Security",
    "Microsoft.PowerShell.Diagnostics"
)

###########################################################################################
# A list of compatibile modules that exist in Windows PowerShell that aren't available
# to PowerShell Core by default. These modules, along with CIM modules can be installed
# in the PowerShell Core module repository using the Copy-WinModule command.
$CompatibleModules = @(
    "AppBackgroundTask",
    "AppLocker",
    "Appx",
    "AssignedAccess",
    "BitLocker",
    "BranchCache",
    "CimCmdlets",
    "ConfigCI",
    "Defender",
    "DeliveryOptimization",
    "DFSN",
    "DFSR",
    "DirectAccessClientComponents",
    "Dism",
    "EventTracingManagement",
    "GroupPolicy",
    "Hyper-V",
    "International",
    "IscsiTarget",
    "Kds",
    "MMAgent",
    "MsDtc",
    "NetAdapter",
    "NetConnection",
    "NetSecurity",
    "NetTCPIP",
    "NetworkConnectivityStatus",
    "NetworkControllerDiagnostics",
    "NetworkLoadBalancingClusters",
    "NetworkSwitchManager",
    "NetworkTransition",
    "PKI",
    "PnpDevice",
    "PrintManagement",
    "ProcessMitigations",
    "Provisioning",
    "PSScheduledJob",
    "ScheduledTasks",
    "SecureBoot",
    "SmbShare",
    "Storage",
    "TrustedPlatformModule",
    "VpnClient",
    "Wdac",
    "WindowsDeveloperLicense",
    "WindowsErrorReporting",
    "WindowsSearch",
    "WindowsUpdate"
)

# Module-scope variable to hold the active compatibility session name
$SessionName = $null

# Specifies the default configuration to connect to when creating the compatibility session
$DefaultConfigurationName = 'Microsoft.PowerShell'

# Specifies the default name of the computer on which to create the compatibility session
$DefaultComputerName = 'localhost'

###########################################################################################
<#
.Synopsis
   Initialize the connection to the compatibility session.
.DESCRIPTION
   Initialize the connection to the compatibility session. By default
   the compatibility session will be created on the local host using the
   'Microsoft.PowerShell' configuration. On subsequent calls, if a session
   matching the current specification is found, it will be returned rather than
   creating a new session. If a matching session is found, but can't be used, it
   will be closed and a new session will be retrieved.

   This command is called by the other commands in this module so
   you will rarely call this command directly. 
.EXAMPLE
    Initialize-WinSession
    Initialize the default compatibility session
.EXAMPLE
    Initialize-WinSession -ComputerName localhost -ConfigurationName Microsoft.PowerShell
    Initialize the compatibility session with a specific computer name and configuration
#>
function Initialize-WinSession
{
    [CmdletBinding()]
    [Alias("iwins")]
    [OutputType("System.Management.Automation.Runspaces.PSSession")]
    Param (

        # If you don't want to use the default compatibility session, use
        # this parameter to specify the name of the computer on which to create
        # the compatibility session.
        # (Defaults to 'localhost')
        [Parameter(Mandatory=$false,Position=0)]
        [String]
        [Alias("Cn")]
            $ComputerName = $script:DefaultComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName = $script:DefaultConfigurationName,

        # The credential to use when connecting to the target machine/configuration
        [Parameter()]
        [PSCredential]
            $Credential,

        # If present, the specified session object will be returned
        [Parameter()]
        [Switch]
            $PassThru,

        # Instead of initializing the session, show what actions will be taken instead.
        [Parameter()]
        [Switch]
            $WhatIf
    )

    [bool] $verboseFlag = $PSBoundParameters['Verbose']

    if ($ComputerName -eq ".")
    {
        $ComputerName = "localhost"
    }

    Write-Verbose -Verbose:$verboseFlag "Initializing the compatibility session on host '$ComputerName'."
    if ($Credential)
    {
        $script:SessionName = "win-$($Credential.UserName)"
    }
    else
    {
        $script:SessionName = "win-$((Get-ChildItem env:UserName).Value)"
    }
    Write-Verbose -Verbose:$verboseFlag "The compatibility session name is '$script:SessionName'."

    # BUGBUG - need to deal with the possibilities of multiple sessions
    $session = Get-PSSession | Where-Object {
        $_.ComputerName      -eq $ComputerName -and
        $_.ConfigurationName -eq $ConfigurationName -and
        $_.Name              -eq $script:SessionName
    }

    if ($session -and $session.State -ne "Opened")
    {
        Write-Verbose -Verbose:$verboseFlag "Removing closed compatibility session."
        Remove-PSSession $session
        $session = $null
    }

    if (! $session)
    {
        $SessionOpts = @{}
        if ($Credential)
        {
            $SessionOpts.Credential = $Credential
        }
        if ($ComputerName -eq "." -or $ComputerName -eq (hostname) -or $ComputerName -eq "localhost")
        {
            $SessionOpts.EnableNetworkAccess = $true
            
        }
        Write-Verbose -Verbose:$verboseFlag "Creating a new compatibility session."
        ##BUGBUG need to deal with the case where there might be multiple sessions because someone hit ctrl-C
        $session = New-PSSession -Verbose:$verboseFlag -Name $script:sessionName -ComputerName $ComputerName `
                -ConfigurationName $configurationName @SessionOpts
    }
    else
    {
        Write-Verbose -Verbose:$verboseFlag "Reusing the existing compatibility session."
    }

    if ($PassThru)
    {
        return $session
    }
}

###########################################################################################
<#
.Synopsis
   This command defines a global function that always runs in the compatibility session.
.DESCRIPTION
    This command defines a global function that always runs in the compatibility session,
    returning serialized data to the calling session. Parameters can be specified using
    the 'param' statement but only positional parameters are supported.

    By default, when executing, the current compatibility session is used,
    or, in the case where there is no existing session, a new default session
    will be created. This behaviour can be overridden using the
    additional parameters on the command.
.EXAMPLE
    Add-WinFunction myFunction {param ($n) "Hi $n!"; $PSVersionTable.PSEdition }
    This example defines a function called 'myFunction' with 1 parameter. When invoked it will print a message then return the PSVersion table
    from the compatibility session. Now call the function
    PS C:\> myFunction Bill
    Hi Bill!
    Desktop
#>
function Add-WinFunction
{
    [CmdletBinding()]
    [Alias("awinf")]
    [OutputType([void])]
    Param
    (
        # The name of the function to define
        [Parameter(Mandatory,Position=0)]
        [String]
            $FunctionName,

        # Scriptblock to use as the body of the function
        [Parameter(Mandatory,Position=1)]
        [ScriptBlock]
            $ScriptBlock,

        # If you don't want to use the default compatibility session, use
        # this parameter to specify the name of the computer on which to create
        # the compatibility session.
        # (Defaults to 'localhost')
        [Parameter()]
        [String]
        [Alias("Cn")]
            $ComputerName = $script:DefaultComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName = $script:DefaultConfigurationName,

        # The credential to use when creating the compatibility session
        # using the target machine/configuration
        [Parameter()]
        [PSCredential]
            $Credential
    )

    # Make sure the session is initialized
    [void] $PSBoundParameters.Remove('FunctionName')
    [void] $PSBoundParameters.Remove('ScriptBlock')

    Initialize-WinSession @PSBoundParameters

    $scriptToRun = @"
    param()
    
    `$session = Get-PSsession -Name ${script:SessionName}
    Invoke-Command -Session `$session -Scriptblock `$ScriptBlock -ArgumentList `$args
"@
    $wrapper = [ScriptBlock]::Create($scriptToRun)
    Set-item function:Global:$FunctionName $wrapper.GetNewClosure();
}

###########################################################################################
<#
.Synopsis
   Invoke a scriptblock that runs in the compatibility runspace.
.DESCRIPTION
    This command takes a scriptblock and invokes it in the 
    compatibility session. Parameters can be passed using the -ArgumentList
    parameter.

    By default, when executing, the current compatibility session is used,
    or, in the case where there is no existing session, a new default session
    will be created. This behaviour can be overridden using the
    additional parameters on the command.
.EXAMPLE
    Invoke-WinCommand {param ($name) "Hello $name, how are you?"; $PSVersionTable.PSVersion} Jeffrey
    Hello Jeffrey, how are you?
    Major  Minor  Build  Revision PSComputerName
    -----  -----  -----  -------- --------------
    5      1      17134  1        localhost

    In this example, we're invoking a scriptblock with 1 parameter in the compatibility
    session. This scriptblock will simply print a message and then return 
    the version number of the compatibility session.
.EXAMPLE
    Invoke-WinCommand {Get-EventLog -Log Application -New 10 }

    This examples invokes Get-EventLog in the compatibility session,
    returning the 10 newest events in the application log.
#>
function Invoke-WinCommand
{
    [CmdletBinding()]
    [Alias("iWinc")]
    [OutputType([void])]
    Param
    (
        # The scriptblock to invoke in the compatibility session
        [Parameter(Mandatory, Position=0)]
        [ScriptBlock]
            $ScriptBlock,

        # If you don't want to use the default compatibility session, use
        # this parameter to specify the name of the computer on which to create
        # the compatibility session.
        # (Defaults to 'localhost')
        [Parameter()]
        [String]
        [Alias("Cn")]
            $ComputerName = $script:DefaultComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName = $script:DefaultConfigurationName,

        # The credential to use when connecting to the compatibility session.
        [Parameter()]
        [PSCredential]
            $Credential,
        
        # Arguments to pass to the scriptblock
        [Parameter(ValueFromRemainingArguments)]
        [object[]]
            $ArgumentList
    )

    [void] $PSBoundParameters.Remove('ScriptBlock')
    [void] $PSBoundParameters.Remove('ArgumentList')

    # Make sure the session is initialized
    $session = Initialize-WinSession @PSBoundParameters -PassThru

    # And invoke the scriptblock in the session
    Invoke-Command -Session $session -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
}

###########################################################################################
<#
.Synopsis
   Get a list of the available modules from the compatibility session
.DESCRIPTION
    Get a list of the available modules from the compatibility session.

    By default, when executing, the current compatibility session is used,
    or, in the case where there is no existing session, a new default session
    will be created. This behaviour can be overridden using the
    additional parameters on this command.
.EXAMPLE
    Get-WinModule *PNP*
    Name      Version Description
    ----      ------- -----------
    PnpDevice 1.0.0.0

    This example looks for modules in the compatibility session with the string 'PNP' 
    in their name.
#>
function Get-WinModule
{
    [CmdletBinding()]
    [Alias("gWinm")]
    [OutputType([int])]
    Param
    (
        # Pattern to filter module names by
        [Parameter(Mandatory=$false, Position=0)]
        [String[]]
            $Name='*',

        # If you don't want to use the default compatibility session, use
        # this parameter to specify the name of the computer on which to create
        # the compatibility session.
        # (Defaults to 'localhost')
        [Alias("cn")]
        [String]
            $ComputerName = $script:DefaultComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName = $script:DefaultConfigurationName,

        # The credential to use when creating the compatibility session
        # using the target machine/configuration
        [Parameter()]
        [PSCredential]
            $Credential,
        
        # If specified, the complete deserialized module object
        # will be returned instead of the abbreviated form returned
        # by default. 
        [Parameter()]
        [Switch]
            $Full
    )

    [bool] $verboseFlag = $PSBoundParameters['Verbose']

    Write-Verbose -Verbose:$verboseFlag 'Connecting to compatibility session.'
    $s = Initialize-WinSession -ComputerName $ComputerName `
        -ConfigurationName $ConfigurationName -Credential $Credential -PassThru
    
    if ($name -ne '*')
    {
        Write-Verbose -Verbose:$verboseFlag "Getting the list of available modules matching '$name'."
    }
    else {
        Write-Verbose -Verbose:$verboseFlag 'Getting the list of available modules.'
    }

    $propertiesToReturn = if ($Full) { '*' } else {'Name', 'Version', 'Description'}
    Invoke-Command -Session $s  -ScriptBlock {
        Get-Module -ListAvailable -Name $using:Name |
            Where-Object Name -notin $using:NeverImportList |
                Select-Object $using:propertiesToReturn
    } |  Select-Object $propertiesToReturn |
        Sort-Object Name
}

###########################################################################################
<#
.Synopsis
   Import a compatibility module.
.DESCRIPTION
    This command allows you to import proxy modules from a local or remote
    session. These proxy modules will allow you to invoke cmdlets that are
    not directly supported in this version of PowerShell. There are commands in
    the Windows PowerShell core modules that don't exist natively in PowerShell Core.
    If these modules are imported, proxies will only be created for the missing commands.
    Commands that already exist in PowerShell core will not be overridden.

    By default, when executing, the current compatibility session is used,
    or, in the case where there is no existing session, a new default session
    will be created. This behaviour can be overridden using the
    additional parameters on the command.
.EXAMPLE
    Import-WinModule PnpDevice; Get-Command -Module PnpDevice

    This example imports the 'PnpDevice' module.
.EXAMPLE
    Import-WinModule Microsoft.PowerShell.Management; Get-Command Get-EventLog

    This example imports one of the core Windows PowerShell modules
    containing commands not natively available in PowerShell Core such
    as 'Get-EventLog'. Only commands not already present in PowerShell Core
    will be imported.
.EXAMPLE
    Import-WinModule PnpDevice -Verbose -Force

    This example forces a reload of the module 'PnpDevice' with
    verbose output turned on.
#>
function Import-WinModule
{
    [CmdletBinding()]
    [Alias("iWinm")]
    [OutputType([int])]
    Param
    (
        # Specifies the name of the module to be imported. Wildcards can be used.
        [Parameter(Mandatory=$False,Position=0)]
        [String[]]
            $Name="*",

        # A list of wildcard patterns matching the names of modules that
        # should not be imported.
        [Parameter()]
        [string[]]
            $Exclude = "",

        # If you don't want to use the default compatibility session, use
        # this parameter to specify the name of the computer on which to create
        # the compatibility session.
        # (Defaults to 'localhost')
        [Parameter()]
        [String]
        [Alias("cn")]
            $ComputerName = $script:DefaultComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName = $script:DefaultConfigurationName,

        # Prefix to prepend to the imported command names
        [Parameter()]
        [string]
            $Prefix = "",

        # Disable warnings about non-standard verbs
        [Parameter()]
        [Switch]
            $DisableNameChecking,

        # Don't overwrite any existing function definitions
        [Parameter()]
        [Switch]
            $NoClobber,

        # Force reloading the module
        [Parameter()]
        [Switch]
            $Force,

        # The credential to use when creating the compatibility session
        # using the target machine/configuration
        [Parameter()]
        [PSCredential]
            $Credential,

        # Show what will be imported instead of importing the modules
        [Parameter()]
        [Switch]
            $WhatIf,
        
        # If present, the ModuleInfo objects will be written to the output pipe
        [Parameter()]
        [Switch]
            $PassThru
    )

    [bool] $verboseFlag = $PSBoundParameters['Verbose']

    Write-Verbose -Verbose:$verboseFlag "Connecting to compatibility session."
    [PSSession] $session = Initialize-WinSession -Verbose:$verboseFlag `
        -ComputerName $ComputerName -ConfigurationName $ConfigurationName `
        -Credential $Credential -PassThru

    $ImportOpts = @{}
    if ($Prefix)
    {
        $ImportOpts.Prefix = $Prefix
    }
    if ($PassThru)
    {
        $ImportOpts.PassThru = $PassThru
    }

    # Mapping wildcards to a regex
    $Exclude = ($Exclude -replace "\*",".*") -join "|"

    Write-Verbose -Verbose:$verboseFlag "Getting module list..."
    $importNames = Invoke-Command -Session $session {
        # Running on the Remote Machine
        $m = (Get-Module -ListAvailable -Name $using:Name).
                Where{ $_.Name -notin $using:NeverImportList } 
        
        # These can use wildcards e.g. Az*,x* will probably be common
        if ($using:Exclude)
        { 
            $m = $m.Where{ $_.Name -NotMatch $using:Exclude } 
        }

        $m.Name | Select-Object -Unique
    }
    
    Write-Verbose -Verbose:$verboseFlag "Importing modules..."
    if ($importNames)
    {
        # Extract the 'never clobber' modules from the list
        $noClobberNames = $importNames.where{ $_ -in $script:NeverClobberList }
        $importNames = $importNames.where{ $_ -notin $script:NeverClobberList }
        if ($importNames)
        {
            Import-Module -Global -Force:$Force -Verbose:$verboseFlag -PSSession $session -Name $ImportNames `
                -DisableNameChecking:$DisableNameChecking -NoClobber:$NoClobber @ImportOpts
        }
        if ($noClobberNames)
        {
            Import-Module -Global -Force:$Force -Verbose:$verboseFlag -PSSession $session -Name $noClobberNames `
                -DisableNameChecking:$DisableNameChecking -NoClobber @ImportOpts
        }
    }
    else
    {
        Write-Verbose -Verbose:$verboseFlag "No matching modules were found; nothing was imported"
    }
}

###########################################################################################
<#
.Synopsis
   Compare the set of modules for this version of PowerShell
   against those available in the comptibility session.
.DESCRIPTION
   Compare the set of modules for this version of PowerShell
   against those available in the comptibility session.
.EXAMPLE
   Compare-WinModule
.EXAMPLE
   Compare-WinModule A*
#>
function Compare-WinModule
{
    [CmdletBinding()]
    [Alias("cWinm")]
    [OutputType([int])]
    Param
    (
        # Specifies the names or name patterns of for the modules to compare. 
        # Wildcard characters are permitted.
        [Parameter(Mandatory=$false, Position=0)]
        [String[]]
            $Name="*",

        # If you don't want to use the default compatibility session, use
        # this parameter to specify the name of the computer on which to create
        # the compatibility session.
        # (Defaults to 'localhost')
        [Parameter()]
        [String]
        [Alias("cn")]
            $ComputerName = $script:DefaultComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName = $script:DefaultConfigurationName,

        # If needed, use this parameter to specify credentials for the compatibility session
        [Parameter()]
        [PSCredential]
            $Credential
    )

    [bool] $verboseFlag = $PSBoundParameters['Verbose']

    Write-Verbose -Verbose:$verboseFlag "Initializing compatibility session"
    [PSSession] $session = Initialize-WinSession -Verbose:$verboseFlag -ComputerName $ComputerName `
            -ConfigurationName $ConfigurationName `
            -Credential $Credential -PassThru

    Write-Verbose -Verbose:$verboseFlag "Getting local modules..."
    $LocalModule = (Get-Module -ListAvailable -Verbose:$false).Where{$_.Name -like $Name}

    Write-Verbose -Verbose:$verboseFlag "Getting remote modules..."
    # Use Invoke-Command here instead of the -PSSession option on Get-Module because
    # we're only returning a subset of the data
    $RemoteModule = @(Invoke-Command -Session $session {
        (Get-Module -ListAvailable).
            Where{$_.Name -notin $using:NeverImportList -and $_.Name -like $using:Name} |
                Select-Object Name, Version })

    Write-Verbose -Verbose:$verboseFlag "Comparing module set..."     
    Compare-Object $LocalModule $RemoteModule -Property Name,Version |
        Where-Object SideIndicator -eq "=>"
}

###########################################################################################
<#
.Synopsis
   Copy modules from the compatibility session that are directly usable in PowerShell Core.
.DESCRIPTION
   Copy modules from the compatibility session that are directly usable in PowerShell Core.
   By default, these modules will be copied to $PSHome/Modules. This can be overridden using
   the -Destination parameter. Once these modules have been copied, they will be available
   just like the other native modules for PowerShell Core.

   Note that if there already is a module in the destination corresponding to the module
   to be copied's name, it will not be copied. 
.EXAMPLE
    Copy-WinModule hyper-v -WhatIf -Verbose

    Run the copy command with -WhatIf to see what would be copied to $PSHome/Modules.
    Also show Verose information.
.EXAMPLE
    PS C:\> Copy-WinModule hyper-v -Destination ~/Documents/PowerShell/Modules

    Copy the specified module to your user module directory.
#>
function Copy-WinModule
{
    [CmdletBinding()]
    [Alias("cpwinm")]
    [OutputType([int])]
    Param
    (
        # Specifies names or name patterns of modules that will be copied. 
        # Wildcard characters are permitted.
        [Parameter(Mandatory=$false,Position=0)]
        [String[]]
            $Name="*",

        # If you don't want to use the default compatibility session, use
        # this parameter to specify the name of the computer on which to create
        # the compatibility session.
        # (Defaults to 'localhost')
        [Parameter()]
        [String]
        [Alias("cn")]
            $ComputerName = $script:DefaultComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName = $script:DefaultConfigurationName,

        # If needed, use this parameter to specify credentials for the compatibility session
        [Parameter()]
        [PSCredential]
            $Credential,
        
        # The location where compatible modules should be copied to
        [Parameter()]
        [String]
            $Destination = (join-path $PSHOME "Modules"),
        
        # Show what will be copied instead of copying the files
        [Parameter()]
        [Switch]
            $WhatIf
    )

    [bool] $verboseFlag = $PSBoundParameters['Verbose']

    [PSSession] $session = Initialize-WinSession -Verbose:$verboseFlag -ComputerName $ComputerName `
                                -ConfigurationName $ConfigurationName `
                                -Credential $Credential -PassThru

    $CopyOptions = @{}
    if ($ComputerName -ne "localhost" -and $ComputerName -ne ".")
    {
        $CopyOptions.FromSession = $session
    }

    Write-Verbose -Verbose:$verboseFlag "Searching for compatible modules..."
    $modulesToCopy = Invoke-Command $session {
        Get-Module -ListAvailable -Name $using:CompatibleModules |
            Select-Object Name, ModuleBase
    }

    Write-Verbose -Verbose:$verboseFlag "Searching for CIM modules..."
    $modulesToCopy += Invoke-Command $session {
        Get-Module -ListAvailable |
            Where-Object { $_.NestedModules[0].path -match '\.cdxml$' } |
                Select-Object Name,ModuleBase
    }

    $moduleHash = @{}
    foreach ($n in $name)
    {
        foreach ($m in $modulesToCopy -like $n)
        {
            $moduleHash[$m.Name]
        }
    }
    Write-Verbose -Verbose:$verboseFlag "Copying modules to path '$Destination'"

    foreach ($m in $modulesToCopy)
    {
        # Skip modules that aren't on the named module list
        if (-not ($name.Where{$m.Name -like $_}))
        {
            continue
        }

        $fullDestination = Join-Path $Destination $m.name
        if (! (Test-Path $fullDestination))
        {
            Copy-Item -WhatIf:$WhatIf -Verbose:$verboseFlag -Path $m.ModuleBase `
                -Destination $fullDestination -Recurse @CopyOptions
        }
        else
        {
            Write-Verbose -Verbose:$verboseFlag "Skipping module '$($m.Name)'; module directory already exists"
        }
    }
}