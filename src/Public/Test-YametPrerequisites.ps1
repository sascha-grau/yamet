function Test-YametPrerequisites {
    <#
    .SYNOPSIS
        Tests and optionally installs required tools for video encoding.

    .DESCRIPTION
        The Test-YametPrerequisites cmdlet checks if the required tools (mediainfo, ffmpeg, mkvpropedit)
        are installed on the system. It can optionally install missing tools using the system's package manager.

    .PARAMETER Install
        If specified, automatically installs any missing tools.

    .PARAMETER Force
        Forces installation without confirmation prompts.

    .EXAMPLE
        Test-YametPrerequisites

        Checks if all required tools are installed and displays the results.

    .EXAMPLE
        Test-YametPrerequisites -Install

        Checks for required tools and installs any that are missing.

    .EXAMPLE
        Test-YametPrerequisites -Install -Force

        Installs all missing tools without prompting for confirmation.

    .INPUTS
        None

    .OUTPUTS
        PSCustomObject
        Returns custom objects showing the installation status of each tool.

    .NOTES
        Author: Your Name
        Date: 11/15/2025

        Required Tools:
        - mediainfo: For reading video file metadata
        - ffmpeg: For video encoding and conversion
        - mkvpropedit: For editing Matroska file properties

        On Windows: Requires Chocolatey or winget
        On Linux: Requires apt, dnf, yum, or pacman
        On macOS: Requires Homebrew
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$Install,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose 'Starting prerequisite check'
        $requiredTools = @('mediainfo', 'ffmpeg', 'mkvpropedit')
        $results = @()
    }

    process {
        try {
            foreach ($tool in $requiredTools) {
                Write-Verbose "Checking for $tool"

                $isInstalled = Test-YametPrerequisite -ToolName $tool

                $result = [PSCustomObject]@{
                    PSTypeName = 'Yamet.PrerequisiteStatus'
                    Tool = $tool
                    Installed = $isInstalled
                    Action = 'None'
                }

                if (-not $isInstalled) {
                    Write-Warning "$tool is not installed"

                    if ($Install) {
                        if ($Force -or $PSCmdlet.ShouldProcess($tool, 'Install missing tool')) {
                            Write-Host "Installing $tool..." -ForegroundColor Yellow

                            $installSuccess = Install-YametPrerequisite -ToolName $tool -Force:$Force

                            if ($installSuccess) {
                                $result.Installed = $true
                                $result.Action = 'Installed'
                            } else {
                                $result.Action = 'Failed'
                            }
                        } else {
                            $result.Action = 'Skipped'
                        }
                    } else {
                        Write-Host "To install $tool, run: Test-YametPrerequisites -Install" -ForegroundColor Cyan
                        $result.Action = 'Missing'
                    }
                } else {
                    Write-Verbose "$tool is already installed"
                    $result.Action = 'Already Installed'
                }

                $results += $result
            }

            # Display results
            Write-Host "`nPrerequisite Check Results:" -ForegroundColor Cyan
            $formattedResults = $results | Format-Table -AutoSize | Out-String
            Write-Host $formattedResults.TrimEnd()

            # Check CUDA/NVENC support
            Write-Host "`nHardware Acceleration:" -ForegroundColor Cyan
            $cudaSupported = Test-YametCudaSupport
            
            if ($cudaSupported) {
                # Get GPU name
                try {
                    $gpuName = & nvidia-smi --query-gpu=name --format=csv,noheader 2>$null | Select-Object -First 1
                    Write-Host "  CUDA/NVENC: " -NoNewline -ForegroundColor White
                    Write-Host "Available" -ForegroundColor Green
                    Write-Host "  GPU: $gpuName" -ForegroundColor Gray
                    Write-Host "  Supported Codecs: h264_nvenc, hevc_nvenc" -ForegroundColor Gray
                }
                catch {
                    Write-Host "  CUDA/NVENC: " -NoNewline -ForegroundColor White
                    Write-Host "Available" -ForegroundColor Green
                }
            } else {
                Write-Host "  CUDA/NVENC: " -NoNewline -ForegroundColor White
                Write-Host "Not Available" -ForegroundColor Yellow
                Write-Host "  Software codecs will be used (x264, x265)" -ForegroundColor Gray
                
                # Try to determine why CUDA is not available
                $hasNvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
                if (-not $hasNvidiaSmi) {
                    Write-Host "  Reason: NVIDIA GPU not detected" -ForegroundColor Gray
                } else {
                    Write-Host "  Reason: ffmpeg NVENC support not available" -ForegroundColor Gray
                }
            }

            # Summary
            $missing = $results | Where-Object { -not $_.Installed }
            Write-Host ""
            if ($missing.Count -eq 0) {
                Write-Host "All required tools are installed!" -ForegroundColor Green
            } else {
                Write-Warning "$($missing.Count) tool(s) are missing: $($missing.Tool -join ', ')"

                if (-not $Install) {
                    Write-Host "`nTo install missing tools, run:" -ForegroundColor Yellow
                    Write-Host "  Test-YametPrerequisites -Install" -ForegroundColor Cyan
                }
            }

            # Output results
            foreach ($result in $results) {
                Write-Output $result
            }

        } catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'PrerequisiteCheckFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $null
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose 'Prerequisite check completed'
    }
}
