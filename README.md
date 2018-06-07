# Windows PowerShell Compatibility

This module provides PowerShell Core 6 compatibility with existing Windows PowerShell scripts and modules by:

- Enable adding the Windows PowerShell PSModulePath
  - Note that some Windows PowerShell modules (like CDXML based) will work fine with PowerShell Core 6, but others may not be fully compatible
- Enable using implicit remoting to utilize Windows PowerShell cmdlets from PowerShell Core 6 for modules that are not compatible directly

Maintainers:

- Mark Kraus ([markekraus](https://github.com/markekraus))
- Steve Lee ([stevel-msft](https://github.com/stevel-msft))
- Bruce Payette ([brucepay](https://github.com/brucepay))
