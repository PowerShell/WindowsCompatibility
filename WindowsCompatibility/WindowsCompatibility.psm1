###########################################################################################
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

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
    "WindowsCompatibility"
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
# in the PowerShell Core module repository using the Copy-WinModule command (if running on Windows).
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

# The computer name to use if one isn't provided as a parameter. It can come from an environment variable.
if ($env:WindowsCompatibilityComputerName)
{
    $SessionComputerName = $env:WindowsCompatibilityComputerName
}
else
{
    $SessionComputerName = 'localhost'
}

# Specifies the default configuration to find or to connect to when creating the compatibility session.
# Windows uses WINRM form of parameters, non-windows uses SSH form
if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows)
{
    $SessionConfigurationName = 'DefaultShell'
    if ($env:WindowsCompatibilityKeyFilePath)
    {
        $SessionKeyFilePath = $env:WindowsCompatibilityKeyFilePath
        Write-Verbose -Message "$SessionKeyFilePath will be used as the key file"
    }
    else {
        $SessionKeyFilePath = $null
    }
}
else {
    $SessionConfigurationName = 'Microsoft.PowerShell'
}
Set-Alias -Name Add-WinPSModulePath -Value Add-WindowsPSModulePath

# Location Changed handler that keeps the compatibility session PWD in sync with the parent PWD
# This only applies on localhost, but not from sessions in Windows Subsystem for Linux.
$locationChangedHandler = {
    [PSSession] $session = Initialize-WinSession @PSBoundParameters -PassThru
    if ($session.ComputerName -eq "localhost" -and ($IsWindows -or $PSVersionTable.PSEdition -ne 'Core') )
    {
        $newPath = $_.newPath
        Invoke-Command -Session $session { Set-Location $using:newPath}
    }
}

$ExecutionContext.InvokeCommand.LocationChangedAction = $locationChangedHandler

# Remove the location changed handler if the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    if ($ExecutionContext.InvokeCommand.LocationChangedAction -eq $locationChangedHandler)
    {
        $ExecutionContext.InvokeCommand.LocationChangedAction = $null
    }
}

function Initialize-WinSession
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.PSSession])]
    Param (

        # If you don't want to use the default compatibility session, use
        # this parameter to specify the name of the computer on which to create
        # the compatibility session.
        [Parameter(Mandatory=$false,Position=0)]
        [String]
        [Alias("Cn")]
            $ComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName,

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

    if ($ComputerName)
    {
        $script:SessionComputerName = $ComputerName
    }
    else
    {
        $ComputerName = $script:SessionComputerName
    }

    if ($ConfigurationName)
    {
        $script:SessionConfigurationName = $ConfigurationName
    }
    else
    {
        $ConfigurationName = $script:SessionConfigurationName
    }

    if ($Credential)
    {
        $script:SessionName = "wincompat-$ComputerName-$($Credential.UserName)"
    }
    elseif ($ComputerName -match '^\w+@\w+') #allow for ssh style name of "user@host:port"
    {
        $script:SessionName = "wincompat-$ComputerName"
    }
    else
    {
        $script:SessionName = "wincompat-$ComputerName-$([environment]::UserName)"
    }

    Write-Verbose -Verbose:$verboseFlag "The compatibility session name is '$script:SessionName'."

    $session = Get-PSSession | Where-Object {
        $_.ComputerName      -eq ($ComputerName -replace '^\w+@','' -replace ':\d+$',"" )-and #allow for ssh style name of "user@host:port"
        $_.ConfigurationName -eq $ConfigurationName -and
        $_.Name              -eq $script:SessionName
        } | Select-Object -First 1

    # Deal with the possibilities of multiple sessions. This might arise
    # from the user hitting ctrl-C. We'll make the assumption that the
    # first one returned is the correct one and we'll remove the rest.
    $session, $rest = $session
    if ($rest)
    {
        foreach ($s in $rest)
        {
            Remove-PSSession  $s
        }
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
            Name              = $script:sessionName
            ErrorAction       = "Stop"
        }
        #If not running on windows: use Hostname (not ComputerName) and use keyfilePath if one was set as an environment variable, and name from credential (if provided)
        if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows)
        {
            $newPSSessionParameters.HostName = $ComputerName
            if ($Credential)
            {
                $newPSSessionParameters.UserName = $Credential.UserName
            }
            if ($null -ne $SessionKeyFilePath )
            {
                $newPSSessionParameters.KeyFilePath = $SessionKeyFilePath
            }
        }
        #if running on Windows use ComputerName (not HostName), ConfigurationName, Credential if provided and enableNetworkAccess if connecting to localhost.
        else {
            $newPSSessionParameters.ComputerName = $ComputerName
            $newPSSessionParameters.ConfigurationName = $configurationName
            if ($Credential)
            {
                $newPSSessionParameters.Credential = $Credential
            }
            if ($ComputerName -eq "localhost" -or $ComputerName -eq [environment]::MachineName)
            {
                $newPSSessionParameters.EnableNetworkAccess = $true
            }
        }
        Write-Verbose -Verbose:$verboseFlag "Creating new compatibiilty session with '$computername'"
        $session = New-PSSession @newPSSessionParameters | Select-Object -First 1
        #if connecting to localhost from a Windows session sync the current directory.
        if ($session -and ($session.ComputerName -eq "localhost")  -and   ( $IsWindows -or $PSVersionTable.PSEdition -ne 'Core' )  )
        {
            Invoke-Command $session { Set-Location $using:PWD }
        }
    }
    else
    {
        Write-Verbose -Verbose:$verboseFlag "Reusing the existing compatibility session; 'host = $script:SessionComputerName'."
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
        [Alias("FunctionName")]
            $Name,

        # Scriptblock to use as the body of the function
        [Parameter(Mandatory,Position=1)]
        [ScriptBlock]
            $ScriptBlock,

        # If you don't want to use the default compatibility session, use
        # this parameter to specify the name of the computer on which to create
        # the compatibility session.
        [Parameter()]
        [String]
        [Alias("Cn")]
            $ComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName,

        # The credential to use when creating the compatibility session
        # using the target machine/configuration
        [Parameter()]
        [PSCredential]
            $Credential
    )
    # Make sure the session is initialized
    [void] $PSBoundParameters.Remove('Name')
    [void] $PSBoundParameters.Remove('ScriptBlock')

    # the session variable will be captured in the closure
    $session = Initialize-WinSession @PSBoundParameters -PassThru
    $wrapper = {
        Invoke-Command -Session $session -Scriptblock $ScriptBlock -ArgumentList $args
    }
    Set-item function:Global:$Name $wrapper.GetNewClosure();
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
        [Parameter()]
        [String]
        [Alias("cn")]
            $ComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName,

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
        [Alias("cn")]
        [String]
            $ComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName,

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
        [Parameter()]
        [String]
        [Alias("cn")]
            $ComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName,

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
            $importModuleParameters.PassThru = $true
            foreach ($name in $noClobberNames)
            {
                $module = Import-Module -Name $name -NoClobber @importModuleParameters
                # Hack using private reflection to keep the proxy module from shadowing the real module.
                $null = [PSModuleInfo].
                    GetMethod('SetName',[System.Reflection.BindingFlags]'Instance, NonPublic').
                        Invoke($module, @($module.Name + '.WinModule'))
                if($PassThru.IsPresent)
                {
                    $module
                }
            }
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
        [Parameter()]
        [String]
        [Alias("cn")]
            $ComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName,

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
        [Parameter()]
        [String]
        [Alias("cn")]
            $ComputerName,

        # Specifies the configuration to connect to when creating the compatibility session
        # (Defaults to 'Microsoft.PowerShell')
        [Parameter()]
        [String]
            $ConfigurationName,

        # If needed, use this parameter to specify credentials for the compatibility session
        [Parameter()]
        [PSCredential]
            $Credential,

        # The location where compatible modules should be copied to
        [Parameter()]
        [String]
            $Destination
    )

    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows)
    {
        throw "This cmdlet is only supported on Windows"
    }

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
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param ()

    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows)
    {
        throw "This cmdlet is only supported on Windows"
    }

    if ($PSVersionTable.PSEdition -eq 'Desktop')
    {
        return
    }

    [bool] $verboseFlag = $PSBoundParameters['Verbose']

    $paths =  @(
        $Env:PSModulePath -split [System.IO.Path]::PathSeparator
        "${Env:UserProfile}\Documents\WindowsPowerShell\Modules"
        "${Env:ProgramFiles}\WindowsPowerShell\Modules"
        "${Env:WinDir}\system32\WindowsPowerShell\v1.0\Modules"
        [System.Environment]::GetEnvironmentVariable('PSModulePath',
            [System.EnvironmentVariableTarget]::Machine) -split [System.IO.Path]::PathSeparator
    )

    $pathTable = [ordered] @{}
    $doUpdate = $false
    foreach ($path in $paths)
    {
        if ($pathTable[$path])
        {
            continue
        }

        if ($PSCmdlet.ShouldProcess($path, "Add to PSModulePath"))
        {
            Write-Verbose -Verbose:$verboseFlag "Adding '$path' to the PSModulePath."
            $doUpdate = $true
        }

        $pathTable[$path] = $true
    }

    if ($doUpdate)
    {
        $Env:PSModulePath = $pathTable.Keys -join [System.IO.Path]::PathSeparator
    }
}
