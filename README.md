# Windows PowerShell Compatibility

This module provides PowerShell Core 6 compatibility with existing Windows PowerShell scripts and modules by:

- Enable adding the Windows PowerShell PSModulePath
  - Note that some Windows PowerShell modules (like CDXML based) will work fine with PowerShell Core 6, but others may not be fully compatible
- Enable using implicit remoting to utilize Windows PowerShell cmdlets from PowerShell Core 6 for modules that are not compatible directly

## Installation

#### [PowerShell V5](https://www.microsoft.com/en-us/download/details.aspx?id=50395) and Later
You can install the `WindowsCompatibility` module directly from the PowerShell Gallery

* [Recommended] Install to your personal PowerShell Modules folder
```PowerShell
Install-Module WindowsCompatibility -scope CurrentUser
```
* [Requires Elevation] Install for Everyone (computer PowerShell Modules folder)
```PowerShell
Install-Module WindowsCompatibility
```

## Quick Start

Viewing the local computer's Event Log from PowerShell Core:

```powershell
Import-WinModule Microsoft.PowerShell.Management
Get-EventLog -Newest 5 -LogName "Application"
```

View the Event Log on a remote computer from PowerShell Core:

```powershell
$Credential = Get-Credential
Initialize-WinSession -ComputerName SQLSERVER01 -Credential $Credential
Import-WinModule Microsoft.PowerShell.Management
Get-EventLog -Newest 5 -LogName "Application"
```

View more in the [Quick Start Guide][QuickStart].

[QuickStart]: ./docs/QuickStart.md

## Documentation

The project documentation is located in the [docs][ProjectDocs] directory.

[ProjectDocs]: ./docs/

## Maintainers

- Mark Kraus ([markekraus](https://github.com/markekraus))
- Steve Lee ([stevel-msft](https://github.com/stevel-msft))
- Bruce Payette ([brucepay](https://github.com/brucepay))
