# Build Documentation

## Build Information

The build process is performed using the `build.ps1` PowerShell script located in the root of the project.
The build script combines the module code with the generated MAML documentation.
The only prerequisites for building this project are PowerShell and the [PlatyPS][PlatyPS] module.

The build process will create the output in the `bin` directory beneath the project root.

[PlatyPS]: https://github.com/PowerShell/platyPS

## Building the Module

To build the project from PowerShell:

```powershell
Install-Module -Scope CurrentUser PlatyPS
git clone https://github.com/PowerShell/WindowsCompatibility.git
Set-Location WindowsCompatibility
./build.ps1
```

## Importing The Built Module

From the project root, run the following:

```powershell
Import-Module ./bin/WindowsCompatibility.psd1 -Force
```

## Building Help Documentation

The Help Documentation for this project is generated using [PlatyPS][PlatyPS].
The markdown files located in [docs/Module/][ModuleDocs]
are transformed to MAML external help documentation.
As a result, Comment Based Help should not be used in this project.

To build the documentation, run the following from the project root in PowerShell:

```powershell
New-Item -ItemType Directory -Path ./bin -ErrorAction SilentlyContinue
New-ExternalHelp -OutputPath ./bin/ -Path ./docs/Module/ -Force
```

[ModuleDocs]: Module/WindowsCompatibility.md

## Build Script Parameters

### `-Clean`

Deletes the output directory and all its contents before performing the build operations.

```powershell
./build.ps1 -Clean
```

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```
