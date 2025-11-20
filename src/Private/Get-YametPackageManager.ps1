function Get-YametPackageManager {
    <#
    .SYNOPSIS
        Detects the available package manager on the current system.

    .DESCRIPTION
        Private helper function to detect which package manager is available
        on the current system (Windows: chocolatey/winget, Linux: apt/dnf/yum/zypper/pacman).

    .OUTPUTS
        System.String
        Returns the name of the detected package manager, or $null if none found.

    .NOTES
        This is a private function and should not be called directly.
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            # Check for Chocolatey
            $choco = Get-Command choco -ErrorAction SilentlyContinue
            if ($null -ne $choco) {
                Write-Verbose "Detected package manager: Chocolatey"
                return 'chocolatey'
            }

            # Check for winget
            $winget = Get-Command winget -ErrorAction SilentlyContinue
            if ($null -ne $winget) {
                Write-Verbose "Detected package manager: winget"
                return 'winget'
            }

            Write-Warning "No package manager found. Please install Chocolatey or winget."
            return $null
        }

        if ($IsLinux) {
            # Check for apt (Debian/Ubuntu)
            $apt = Get-Command apt-get -ErrorAction SilentlyContinue
            if ($null -ne $apt) {
                Write-Verbose "Detected package manager: apt"
                return 'apt'
            }

            # Check for dnf (Fedora/RHEL)
            $dnf = Get-Command dnf -ErrorAction SilentlyContinue
            if ($null -ne $dnf) {
                Write-Verbose "Detected package manager: dnf"
                return 'dnf'
            }

            # Check for yum (older RHEL)
            $yum = Get-Command yum -ErrorAction SilentlyContinue
            if ($null -ne $yum) {
                Write-Verbose "Detected package manager: yum"
                return 'yum'
            }

            # Check for zypper (openSUSE)
            $zypper = Get-Command zypper -ErrorAction SilentlyContinue
            if ($null -ne $zypper) {
                Write-Verbose "Detected package manager: zypper"
                return 'zypper'
            }

            # Check for pacman (Arch)
            $pacman = Get-Command pacman -ErrorAction SilentlyContinue
            if ($null -ne $pacman) {
                Write-Verbose "Detected package manager: pacman"
                return 'pacman'
            }

            Write-Warning "No supported package manager found on this Linux distribution."
            return $null
        }

        if ($IsMacOS) {
            # Check for Homebrew
            $brew = Get-Command brew -ErrorAction SilentlyContinue
            if ($null -ne $brew) {
                Write-Verbose "Detected package manager: Homebrew"
                return 'brew'
            }

            Write-Warning "Homebrew not found. Please install from https://brew.sh"
            return $null
        }

        return $null
    } catch {
        Write-Warning "Error detecting package manager: $_"
        return $null
    }
}
