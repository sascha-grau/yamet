function Get-YametOutputPath {
    <#
    .SYNOPSIS
        Builds the output path and filename for an encoding operation.

    .DESCRIPTION
        Internal helper function that constructs the output directory path
        and filename based on series information or simple filename.

    .PARAMETER BasePath
        The base output directory path.

    .PARAMETER FileName
        The original filename (without extension).

    .PARAMETER TargetContainer
        The target container format (mkv, mp4).

    .OUTPUTS
        Hashtable with OutputDirectory and OutputFileName properties.
    #>

    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [Parameter(Mandatory = $true)]
        [string]$TargetContainer
    )

    $seriesInfo = Get-YametSeriesInfo -FileName $FileName

    $sanitize = {
        param($value)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $value
        }

        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() + [System.IO.Path]::GetInvalidPathChars()
        $pattern = '[' + [Regex]::Escape(($invalidChars | Sort-Object -Unique) -join '') + ']'
        return ($value -replace $pattern, '_').Trim()
    }

    if ($seriesInfo) {
        # Build series-based path
        $seasonFolder = if ($seriesInfo.Season -eq 0) { 'Specials' } else { "Season {0:d2}" -f $seriesInfo.Season }

        $seriesNameSafe = & $sanitize $seriesInfo.Series
        $episodeNameSafe = & $sanitize $seriesInfo.EpisodeName
        $seasonFolderSafe = & $sanitize $seasonFolder

        $outputDir = Join-Path $BasePath $seriesNameSafe
        $outputDir = Join-Path $outputDir $seasonFolderSafe

        $outputFile = '{0} - S{1:d2}E{2:d3}.{3}' -f $seriesNameSafe, $seriesInfo.Season, $seriesInfo.Episode, $TargetContainer

        $title = if ($episodeNameSafe) {
            '{0} - S{1:d2} E{2:d3} - {3}' -f $seriesNameSafe, $seriesInfo.Season, $seriesInfo.Episode, $episodeNameSafe
        } else {
            '{0} - S{1:d2} E{2:d3}' -f $seriesNameSafe, $seriesInfo.Season, $seriesInfo.Episode
        }
    } else {
        # Non-series file
        $fileSafe = & $sanitize $FileName
        $outputDir = Join-Path $BasePath $fileSafe
        $outputFile = '{0}.{1}' -f $fileSafe, $TargetContainer
        $title = $fileSafe
    }

    return @{
        OutputDirectory = $outputDir
        OutputFileName  = $outputFile
        Title           = $title
    }
}
