# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

Describe "Test Add-WindowsPSModulePath cmdlet" {
    BeforeAll {
        Import-Module -Force "$scriptPath\..\bin\WinCompatibilityPack.psd1"
        $originalPsModulePath = $env:PSModulePath
    }

    AfterAll {
        Remove-Module -Force WinCompatibilityPack
        $env:PSModulePath = $originalPsModulePath
    }

    It "Validate Windows PSModulePath is added on Core" {
        $env:PSModulePath | Should -Not -BeLike "*\WindowsPowerShell\*"
        Add-WindowsPSModulePath | Should -BeNullOrEmpty
        $WindowsPSModulePath = [System.Environment]::GetEnvironmentVariable("psmodulepath", [System.EnvironmentVariableTarget]::Machine)
        $env:PSModulePath | Should -BeLike "*$WindowsPSModulePath*"
    }
}
