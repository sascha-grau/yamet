function Test-YametPrerequisite {
    <#
    .SYNOPSIS
        Tests if a required tool is installed.

    .DESCRIPTION
        Private helper function to test if a required tool (mediainfo, ffmpeg, mkvpropedit)
        is installed and accessible on the system PATH.

    .PARAMETER ToolName
        The name of the tool to check for.

    .OUTPUTS
        System.Boolean
        Returns $true if the tool is installed and accessible, $false otherwise.

    .NOTES
        This is a private function and should not be called directly.
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('mediainfo', 'ffmpeg', 'mkvpropedit')]
        [string]$ToolName
    )

    try {
        $command = Get-Command $ToolName -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            $commandPath = if ($command.CommandType -eq 'Application') { $command.Source } else { $command.Path }
            Write-Verbose "$ToolName is installed at: $commandPath"
            return $true
        }

        Write-Verbose "$ToolName is not found in PATH"
        return $false
    } catch {
        Write-Verbose "Error checking for $ToolName"
        return $false
    }
}
