# Windows PowerShell Compatibility Pack

This module provides PowerShell Core 6 compatibility with existing Windows PowerShell scripts and modules by:

- Adding more .Net Framework classes via the [Windows Compatibility Pack for .NET Core](https://blogs.msdn.microsoft.com/dotnet/2017/11/16/announcing-the-windows-compatibility-pack-for-net-core/)
- Enable adding the Windows PowerShell PSModulePath
  - Note that some Windows PowerShell modules (like CDXML based) will work fine with PowerShell Core 6, but others may not be fully compatible
- Enable using implicit remoting to utilize Windows PowerShell cmdlets from PowerShell Core 6 for modules that are not compatible directly

Modules built against .Net Standard 2.0, PowerShell Standard Library 5.1, and also the .Net Windows Compatibility Pack
should specify this module as a required module in their module manifest to avoid redistributing another copy of
the Windows Compatibility Pack assemblies.
This module is necessary for those modules to work with Windows PowerShell 5.1 in addition to PowerShell Core 6.

Maintainers:

- Mark Kraus ([markekraus](https://github.com/markekraus))
- Steve Lee ([stevel-msft](https://github.com/stevel-msft))
- Bruce Payette ([brucepay](https://github.com/brucepay))
