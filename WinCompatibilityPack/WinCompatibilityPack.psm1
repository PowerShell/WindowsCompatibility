###########################################################################################
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Management.Automation.
using namespace System.Management.Automation.Runspaces

Set-StrictMode -Version latest

# PSCore 6.0.x has older versions of assemblies from WCP that are not compatible
if ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.Major -eq 6 -and
    $PSVersionTable.PSVersion.Minor -eq 0)
{
    throw "This module is not compatible with PSCore 6.0.x, please upgrade to PSCore 6.1 or newer"
}

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
# will not overwrite any existing PowerShell Core commands
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

function Initialize-WinSession
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.PSSession])]
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
            $PassThru
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
        $script:SessionName = "win-$([environment]::UserName)"
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

    if (-not $session)
    {
        $newPSSessionParameters = @{
            Verbose           = $verboseFlag
            ComputerName      = $ComputerName
            Name              = $script:sessionName
            ConfigurationName = $configurationName
            ErrorAction       = "Stop"
        }
        if ($Credential)
        {
            $newPSSessionParameters.Credential = $Credential
        }
        if ($ComputerName -eq "localhost" -or $ComputerName -eq [environment]::MachineName)
        {
            $newPSSessionParameters.EnableNetworkAccess = $true
        }
        Write-Verbose -Verbose:$verboseFlag "Creating a new compatibility session."
        ##BUGBUG need to deal with the case where there might be multiple sessions because someone hit ctrl-C
        $session = New-PSSession @newPSSessionParameters
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

function Add-WinFunction
{
    [CmdletBinding()]
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

    $localSessionName = $script:SessionName
    $wrapper = {
        $session = Get-PSsession -Name $localSessionName
        Invoke-Command -Session $session -Scriptblock $ScriptBlock -ArgumentList $args
    }
    Set-item function:Global:$FunctionName $wrapper.GetNewClosure();
}

function Invoke-WinCommand
{
    [CmdletBinding()]
    [OutputType([PSObject])]
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
        [Alias("cn")]
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
    [PSSession] $session = Initialize-WinSession @PSBoundParameters -PassThru

    # And invoke the scriptblock in the session
    Invoke-Command -Session $session -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
}

function Get-WinModule
{
    [CmdletBinding()]
    [OutputType([PSObject])]
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
    $initializeWinSessionParameters = @{
        Verbose           = $verboseFlag
        ComputerName      = $ComputerName
        ConfigurationName = $ConfigurationName
        Credential        = $Credential
        PassThru          = $true
    }
    [PSSession] $session = Initialize-WinSession @initializeWinSessionParameters

    if ($name -ne '*')
    {
        Write-Verbose -Verbose:$verboseFlag "Getting the list of available modules matching '$name'."
    }
    else
    {
        Write-Verbose -Verbose:$verboseFlag 'Getting the list of available modules.'
    }

    $propertiesToReturn = if ($Full) { '*' } else {'Name', 'Version', 'Description'}
    Invoke-Command -Session $session  -ScriptBlock {
        Get-Module -ListAvailable -Name $using:Name |
            Where-Object Name -notin $using:NeverImportList |
                Select-Object $using:propertiesToReturn
    } |  Select-Object $propertiesToReturn |
        Sort-Object Name
}

function Import-WinModule
{
    [CmdletBinding()]
    [OutputType([PSObject])]
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

        # If present, the ModuleInfo objects will be written to the output pipe
        # as deserialized (PSObject) objects
        [Parameter()]
        [Switch]
            $PassThru
    )

    [bool] $verboseFlag = $PSBoundParameters['Verbose']

    Write-Verbose -Verbose:$verboseFlag "Connecting to compatibility session."
    $initializeWinSessionParameters = @{
        Verbose           = $verboseFlag
        ComputerName      = $ComputerName
        ConfigurationName = $ConfigurationName
        Credential        = $Credential
        PassThru          = $true
    }
    [PSSession] $session = Initialize-WinSession @initializeWinSessionParameters

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
    $importModuleParameters = @{
        Global              = $true
        Force               = $Force
        Verbose             = $verboseFlag
        PSSession           = $session
        PassThru            = $PassThru
        DisableNameChecking = $DisableNameChecking
    }
    if ($Prefix)
    {
        $importModuleParameters.Prefix = $Prefix
    }
    if ($PassThru)
    {
        $importModuleParameters.PassThru = $PassThru
    }
    if ($importNames)
    {
        # Extract the 'never clobber' modules from the list
        $noClobberNames = $importNames.where{ $_ -in $script:NeverClobberList }
        $importNames    = $importNames.where{ $_ -notin $script:NeverClobberList }
        if ($importNames)
        {
            Import-Module  -Name $ImportNames -NoClobber:$NoClobber @importModuleParameters
        }
        if ($noClobberNames)
        {
            Import-Module  -Name $noClobberNames -NoClobber @importModuleParameters
        }
    }
    else
    {
        Write-Verbose -Verbose:$verboseFlag "No matching modules were found; nothing was imported"
    }
}

function Compare-WinModule
{
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        # Specifies the names or name patterns of for the modules to compare.
        # Wildcard characters are permitted.
        [Parameter(Position=0)]
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
    $initializeWinSessionParameters = @{
        Verbose           = $verboseFlag
        ComputerName      = $ComputerName
        ConfigurationName = $ConfigurationName
        Credential        = $Credential
        PassThru          = $true
    }
    [PSSession] $session = Initialize-WinSession @initializeWinSessionParameters

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

function Copy-WinModule
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
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
            $Destination
    )

    [bool] $verboseFlag = $PSBoundParameters['Verbose']
    [bool] $whatIfFlag  = $PSBoundParameters['WhatIf']
    [bool] $confirmFlag = $PSBoundParameters['Confirm']

    if (-not $Destination)
    {
        # If the user hasn't specified a destination, default to the user module directory
        $parts =  [environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments),
                    "PowerShell",
                        "Modules"
        $Destination = Join-Path @parts
    }

    # Resolve the path which also verifies that the path exists
    $resolvedDestination = Resolve-Path $Destination -ErrorAction SilentlyContinue
    if (-not $?)
    {
        throw "The destination path '$Destination' could not be resolved. Please ensure that the path exists and try the command again"
    }
    # Make sure it's a FileSystem location
    if ($resolvedDestination.provider.ImplementingType -ne [Microsoft.PowerShell.Commands.FileSystemProvider] )
    {
        throw "Modules can only be installed to paths in the filesystem. Please choose a different location and try the command again"
    }
    $Destination = $resolvedDestination.Path

    $initializeWinSessionParameters = @{
        Verbose           = $verboseFlag
        ComputerName      = $ComputerName
        ConfigurationName = $ConfigurationName
        Credential        = $Credential
        PassThru          = $true
    }
    [PSSession] $session = Initialize-WinSession @initializeWinSessionParameters

    $copyItemParameters = @{
        WhatIf  = $whatIfFlag
        Verbose = $verboseFlag
        Confirm = $confirmFlag
        Recurse = $true
    }
    if ($ComputerName -ne "localhost" -and $ComputerName -ne ".")
    {
        $copyItemParameters.FromSession = $session
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

    Write-Verbose -Verbose:$verboseFlag "Copying modules to path '$Destination'"

    $modulesToCopy = $modulesToCopy | Sort-Object -Unique -Property Name
    foreach ($m in $modulesToCopy)
    {
        # Skip modules that aren't on the named module list
        if (-not ($name.Where{$m.Name -like $_}))
        {
            continue
        }

        $fullDestination = Join-Path $Destination $m.name
        if (-not (Test-Path $fullDestination))
        {
            Copy-Item  -Path $m.ModuleBase -Destination $fullDestination @copyItemParameters
        }
        else
        {
            Write-Verbose -Verbose:$verboseFlag "Skipping module '$($m.Name)'; module directory already exists"
        }
    }
}

function Add-WindowsPSModulePath
{

    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows)
    {
        throw "This cmdlet is only supported on Windows"
    }

    if ($PSVersionTable.PSEdition -eq 'Desktop')
    {
        return
    }

    $WindowsPSModulePath = [System.Environment]::GetEnvironmentVariable("psmodulepath", [System.EnvironmentVariableTarget]::Machine)
    if (-not ($env:PSModulePath).Contains($WindowsPSModulePath))
    {
        $env:PSModulePath += ";${env:userprofile}\Documents\WindowsPowerShell\Modules;${env:programfiles}\WindowsPowerShell\Modules;${WindowsPSModulePath}"
    }

}
