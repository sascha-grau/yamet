# Development Guide

> **Note**: This module uses opinionated encoding parameters suitable for personal use. When contributing, maintain consistency with existing quality settings or propose changes that benefit the core use case.

## Project Structure

```
yamet/
├── src/                              # Module source code
│   ├── Yamet.psd1                   # Module manifest
│   ├── Yamet.psm1                   # Root module file
│   ├── Public/                       # Public functions (exported)
│   │   ├── Get-YametVideoInformation.ps1
│   │   ├── New-YametEncodingItem.ps1
│   │   ├── Test-YametPrerequisites.ps1
│   │   └── Update-YametVideoTags.ps1
│   └── Private/                      # Private helper functions
│       ├── Add-YametAudioEncodingParams.ps1
│       ├── Add-YametSubtitleEncodingParams.ps1
│       ├── Get-YametHDRParams.ps1
│       ├── Get-YametMetadata.ps1
│       ├── Get-YametOutputPath.ps1
│       ├── Get-YametPackageManager.ps1
│       ├── Get-YametSeriesInfo.ps1
│       ├── Get-YametVideoEncodingParams.ps1
│       ├── Get-YametVideoFilter.ps1
│       ├── Install-YametPrerequisite.ps1
│       ├── Test-YametCudaSupport.ps1
│       └── Test-YametPrerequisite.ps1
├── tests/                            # Pester tests
│   └── Yamet.Tests.ps1
├── build/                            # Build scripts
│   └── build.ps1
├── docs/                             # Documentation
│   ├── getting-started.md
│   ├── video-encoding.md
│   ├── metadata-scrapers.md
│   └── development.md
├── .vscode/                          # VS Code configuration
│   ├── tasks.json
│   └── launch.json
├── .github/                          # GitHub configuration
│   └── instructions/
│       └── powershell.instructions.md
├── README.md
└── QUICK_REFERENCE.md
```

## Development Workflow

### Prerequisites

- PowerShell 5.1 or PowerShell 7+
- Pester 5.0+ (for testing)
- VS Code with PowerShell extension (recommended)

### Setting Up Development Environment

1. Clone the repository:
   ```powershell
   git clone <repository-url>
   cd yamet
   ```

2. Install Pester (if not already installed):
   ```powershell
   Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
   ```

3. Import the module in development mode:
   ```powershell
   Import-Module .\src\Yamet.psd1 -Force
   ```

### Making Changes

1. **Create a new function:**
   - Add the function file in `src/Public/` for exported functions
   - Add the function file in `src/Private/` for internal helpers
   - Follow the naming convention: `Verb-YametNoun.ps1`

2. **Follow PowerShell best practices:**
   - Use approved verbs (check with `Get-Verb`)
   - Include comment-based help
   - Implement `[CmdletBinding()]` for advanced functions
   - Support pipeline input where appropriate
   - Use `ShouldProcess` for operations that modify state

3. **Update the module manifest:**
   - Add new function names to `FunctionsToExport` in `Yamet.psd1`

4. **Consult repository instructions:**
    - Before editing PowerShell files, review `.github/instructions/powershell.instructions.md` to stay aligned with the module's shell and cmdlet guidelines.

### Testing

Run all tests:

```powershell
.\build\build.ps1 -Task Test
```

Run tests with Pester directly:

```powershell
Invoke-Pester -Path .\tests\
```

### Building

Build the module:

```powershell
.\build\build.ps1 -Task Build
```

Run all tasks (clean, test, build):

```powershell
.\build\build.ps1 -Task All
```

### VS Code Tasks

Use the predefined VS Code tasks:

- **Build Module** (Ctrl+Shift+B): Builds the module
- **Test Module**: Runs all tests
- **Clean Output**: Cleans the output directory
- **Build and Test**: Runs all build tasks
- **Import Module (Development)**: Imports the module in a new terminal

## Coding Standards

### Function Structure

```powershell
function Verb-YametNoun {
    <#
    .SYNOPSIS
        Brief description
    
    .DESCRIPTION
        Detailed description
    
    .PARAMETER Name
        Parameter description
    
    .EXAMPLE
        Example usage
    
    .OUTPUTS
        Output type
    
    .NOTES
        Additional information
    #>
    
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    
    begin {
        Write-Verbose 'Begin block'
    }
    
    process {
        try {
            # Implementation
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    
    end {
        Write-Verbose 'End block'
    }
}
```

### Error Handling

- Use `try/catch` blocks
- Create proper `ErrorRecord` objects
- Use `$PSCmdlet.WriteError()` for non-terminating errors
- Use `$PSCmdlet.ThrowTerminatingError()` for terminating errors

### Pipeline Support

- Use `begin`, `process`, and `end` blocks
- Support `ValueFromPipeline` where appropriate
- Process one item at a time in the `process` block

## Debugging

### In VS Code

1. Set breakpoints in your code
2. Press F5 to start debugging
3. Choose the appropriate launch configuration

### Interactive Debugging

```powershell
# Import module with verbose output
Import-Module .\src\Yamet.psd1 -Force -Verbose

# Run cmdlet with verbose output
Get-YametResource -Verbose

# Enable script tracing
Set-PSDebug -Trace 1

# Disable script tracing
Set-PSDebug -Off
```

## Contributing

1. Create a feature branch
2. Make your changes following the coding standards
3. Write tests for new functionality
4. Ensure all tests pass
5. Update documentation
6. Submit a pull request

## Resources

- [PowerShell Best Practices](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- [Pester Documentation](https://pester.dev)
- [PowerShell Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style)
