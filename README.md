# WindowsPowerShellCompatibilityPack

This module increases PowerShell Core 6 compatibility with existing Windows PowerShell scripts and modules by:
- adding more dotnet classes via the [Windows Compatibility Pack for .NET Core](https://blogs.msdn.microsoft.com/dotnet/2017/11/16/announcing-the-windows-compatibility-pack-for-net-core/)
- adding the Windows PowerShell PSModulePath
- include existing Windows PowerShell cmdlets that could not be ported to PowerShell Core:
  - WMI cmdlets
  - EventLog cmdlets
  - PerfCounter cmdlets

Initiated from https://blogs.msdn.microsoft.com/dotnet/2017/11/16/announcing-the-windows-compatibility-pack-for-net-core/
