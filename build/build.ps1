<#
.SYNOPSIS
    Build script for the Yamet PowerShell module.

.DESCRIPTION
    This script builds the Yamet module by validating the module structure,
    running tests, and preparing the module for distribution.

.PARAMETER Task
    Specifies the build task to execute. Valid values are: 'Clean', 'Test', 'Build', 'All'.
    Default value is 'All'.

.PARAMETER Configuration
    Specifies the build configuration. Valid values are: 'Debug', 'Release'.
    Default value is 'Release'.

.EXAMPLE
    .\build.ps1

    Runs all build tasks in Release configuration.

.EXAMPLE
    .\build.ps1 -Task Test

    Runs only the test task.

.EXAMPLE
    .\build.ps1 -Task Build -Configuration Debug

    Runs the build task in Debug configuration.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Clean', 'Test', 'Build', 'All')]
    [string]$Task = 'All',

    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'

# Define paths
$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$srcPath = Join-Path -Path $projectRoot -ChildPath 'src'
$testsPath = Join-Path -Path $projectRoot -ChildPath 'tests'
$outputPath = Join-Path -Path $projectRoot -ChildPath 'output'
$moduleName = 'Yamet'

Write-Host "Starting build process for $moduleName" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor Cyan
Write-Host "Task: $Task" -ForegroundColor Cyan

function Invoke-CleanTask {
    Write-Host "`nCleaning output directory..." -ForegroundColor Yellow

    if (Test-Path -Path $outputPath) {
        Remove-Item -Path $outputPath -Recurse -Force
        Write-Host "Output directory cleaned" -ForegroundColor Green
    } else {
        Write-Host "Output directory does not exist, skipping" -ForegroundColor Gray
    }
}

function Invoke-TestTask {
    Write-Host "`nRunning tests..." -ForegroundColor Yellow

    # Check if Pester is installed
    $pester = Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -ge '5.0.0' }
    if (-not $pester) {
        Write-Warning "Pester 5.0+ is not installed. Installing Pester..."
        Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck
    }

    Import-Module -Name Pester -MinimumVersion 5.0.0

    $testResults = Invoke-Pester -Path $testsPath -Output Detailed -PassThru

    if ($testResults.FailedCount -gt 0) {
        throw "Tests failed. Failed count: $($testResults.FailedCount)"
    }

    Write-Host "All tests passed" -ForegroundColor Green
}

function Invoke-BuildTask {
    Write-Host "`nBuilding module..." -ForegroundColor Yellow

    # Create output directory
    $moduleOutputPath = Join-Path -Path $outputPath -ChildPath $moduleName
    New-Item -Path $moduleOutputPath -ItemType Directory -Force | Out-Null

    # Copy module files
    Write-Host "Copying module files..."
    Copy-Item -Path "$srcPath\*" -Destination $moduleOutputPath -Recurse -Force

    # Test module manifest
    Write-Host "Testing module manifest..."
    $manifestPath = Join-Path -Path $moduleOutputPath -ChildPath "$moduleName.psd1"
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop

    Write-Host "Module built successfully" -ForegroundColor Green
    Write-Host "Output location: $moduleOutputPath" -ForegroundColor Cyan
    Write-Host "Module version: $($manifest.Version)" -ForegroundColor Cyan
}

try {
    switch ($Task) {
        'Clean' {
            Invoke-CleanTask
        }
        'Test' {
            Invoke-TestTask
        }
        'Build' {
            Invoke-CleanTask
            Invoke-BuildTask
        }
        'All' {
            Invoke-CleanTask
            Invoke-TestTask
            Invoke-BuildTask
        }
    }

    Write-Host "`nBuild completed successfully!" -ForegroundColor Green

} catch {
    Write-Host "`nBuild failed: $_" -ForegroundColor Red
    throw
}
