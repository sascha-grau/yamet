#Requires -Version 5.1

<#
.SYNOPSIS
    Root module file for the Yamet PowerShell module.

.DESCRIPTION
    This module provides cmdlets for managing resources efficiently.
    It follows PowerShell best practices and Microsoft guidelines.
#>

# Get public and private function definition files
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'

# Dot source the files
if (Test-Path -Path $publicPath) {
    $publicFunctions = @(Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)

    foreach ($import in $publicFunctions) {
        try {
            Write-Verbose "Importing function: $($import.FullName)"
            . $import.FullName
        } catch {
            Write-Error "Failed to import function $($import.FullName): $_"
        }
    }
}

if (Test-Path -Path $privatePath) {
    $privateFunctions = @(Get-ChildItem -Path $privatePath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)

    foreach ($import in $privateFunctions) {
        try {
            Write-Verbose "Importing private function: $($import.FullName)"
            . $import.FullName
        } catch {
            Write-Error "Failed to import private function $($import.FullName): $_"
        }
    }
}

# Export public functions
if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions.BaseName
}
