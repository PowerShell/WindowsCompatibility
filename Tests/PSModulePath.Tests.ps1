# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Describe "Test Add-WindowsPSModulePath cmdlet" {
    BeforeAll {
        Import-Module -Force ..\WinCompatibilityPack\WinCompatibilityPack.psd1
        $originalPsModulePath = $env:PSModulePath
    }

    AfterAll {
        Remove-Module -Force WinCompatibilityPack
        $env:PSModulePath = $originalPsModulePath
    }

    It "Validate Windows PSModulePath is added" {
        $env:PSModulePath | Should -Not -BeLike "*\WindowsPowerShell\*"
        Add-WindowsPSModulePath
        $WindowsPSModulePath = [System.Environment]::GetEnvironmentVariable("psmodulepath", [System.EnvironmentVariableTarget]::Machine)
        $env:PSModulePath | Should -BeLike "*$WindowsPSModulePath*"
    }
}
