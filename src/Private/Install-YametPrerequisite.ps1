function Install-YametPrerequisite {
    <#
    .SYNOPSIS
        Installs a required tool using the system's package manager.

    .DESCRIPTION
        Private helper function to install required tools (mediainfo, ffmpeg, mkvpropedit)
        using the appropriate package manager for the current operating system.

    .PARAMETER ToolName
        The name of the tool to install.

    .PARAMETER Force
        Forces installation without confirmation.

    .OUTPUTS
        System.Boolean
        Returns $true if installation was successful, $false otherwise.

    .NOTES
        This is a private function and should not be called directly.
        Requires administrative/sudo privileges on most systems.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('mediainfo', 'ffmpeg', 'mkvpropedit')]
        [string]$ToolName,

        [Parameter()]
        [switch]$Force
    )

    try {
        $packageManager = Get-YametPackageManager

        if ($null -eq $packageManager) {
            Write-Error "No package manager detected. Cannot install $ToolName automatically."
            return $false
        }

        # Map tool names to package names for different package managers
        $packageMap = @{
            'mediainfo' = @{
                'chocolatey' = 'mediainfo-cli'
                'winget' = 'MediaArea.MediaInfo'
                'apt' = 'mediainfo'
                'dnf' = 'mediainfo'
                'yum' = 'mediainfo'
                'pacman' = 'mediainfo'
                'zypper' = 'mediainfo'
                'brew' = 'media-info'
            }
            'ffmpeg' = @{
                'chocolatey' = 'ffmpeg'
                'winget' = 'Gyan.FFmpeg'
                'apt' = 'ffmpeg'
                'dnf' = 'ffmpeg'
                'yum' = 'ffmpeg'
                'pacman' = 'ffmpeg'
                'zypper' = 'ffmpeg'
                'brew' = 'ffmpeg'
            }
            'mkvpropedit' = @{
                'chocolatey' = 'mkvtoolnix'
                'winget' = 'MoritzBunkus.MKVToolNix'
                'apt' = 'mkvtoolnix'
                'dnf' = 'mkvtoolnix'
                'yum' = 'mkvtoolnix'
                'pacman' = 'mkvtoolnix-cli'
                'zypper' = 'mkvtoolnix'
                'brew' = 'mkvtoolnix'
            }
        }

        $packageName = $packageMap[$ToolName][$packageManager]

        if ([string]::IsNullOrEmpty($packageName)) {
            Write-Error "Package name not found for $ToolName on $packageManager"
            return $false
        }

        Write-Verbose "Installing $ToolName ($packageName) using $packageManager"

        $installSteps = switch ($packageManager) {
            'chocolatey' { @(@{ Command = 'choco'; Arguments = @('install', $packageName, '-y') }) }
            'winget' { @(@{ Command = 'winget'; Arguments = @('install', '--id', $packageName, '--silent', '--accept-package-agreements', '--accept-source-agreements') }) }
            'apt' {
                @(
                    @{ Command = 'sudo'; Arguments = @('apt-get', 'update') },
                    @{ Command = 'sudo'; Arguments = @('apt-get', 'install', '-y', $packageName) }
                )
            }
            'dnf' { @(@{ Command = 'sudo'; Arguments = @('dnf', 'install', '-y', $packageName) }) }
            'yum' { @(@{ Command = 'sudo'; Arguments = @('yum', 'install', '-y', $packageName) }) }
            'zypper' { @(@{ Command = 'sudo'; Arguments = @('zypper', '--non-interactive', 'install', $packageName) }) }
            'pacman' { @(@{ Command = 'sudo'; Arguments = @('pacman', '-S', '--noconfirm', $packageName) }) }
            'brew' { @(@{ Command = 'brew'; Arguments = @('install', $packageName) }) }
        }

        if (-not $installSteps) {
            Write-Error "Installation steps not defined for $packageManager"
            return $false
        }

        $commandPreview = ($installSteps | ForEach-Object { "{0} {1}" -f $_.Command, ($_.Arguments -join ' ') }) -join ' && '

        $shouldInstall = $Force -or $PSCmdlet.ShouldProcess($ToolName, "Install using '$commandPreview'")

        if (-not $shouldInstall) {
            Write-Warning "Installation cancelled by user"
            return $false
        }

        foreach ($step in $installSteps) {
            $commandText = "{0} {1}" -f $step.Command, ($step.Arguments -join ' ')
            Write-Host "Executing: $commandText" -ForegroundColor Cyan

            try {
                & $step.Command @($step.Arguments)
                if ($LASTEXITCODE -ne 0) {
                    throw "Command exited with code $LASTEXITCODE"
                }
            } catch {
                Write-Error "Failed to run '$commandText': $_"
                return $false
            }
        }

        # Verify installation
        Start-Sleep -Seconds 2
        $installed = Test-YametPrerequisite -ToolName $ToolName

        if ($installed) {
            Write-Host "$ToolName installed successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "$ToolName installation completed but tool is not yet available in PATH. You may need to restart your shell."
            return $false
        }

    } catch {
        $errorMessage = $PSItem.Exception.Message
        Write-Error "Failed to install ${ToolName}: $errorMessage"
        return $false
    }
}
