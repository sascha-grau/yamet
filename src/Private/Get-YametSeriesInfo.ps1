function Get-YametSeriesInfo {
    <#
    .SYNOPSIS
        Parses series information from a filename.

    .DESCRIPTION
        Internal helper function that extracts series name, season, episode number,
        and episode name from a filename using regex patterns.

    .PARAMETER FileName
        The filename to parse (without extension).

    .OUTPUTS
        Hashtable with Series, Season, Episode, and EpisodeName properties.
        Returns $null if the filename doesn't match a series pattern.
    #>

    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    if ($FileName -notmatch 'S\d+E\d+') {
        return $null
    }

    $seriesInfo = $null
    $normalized = $FileName.Trim()

    # Pattern 1: Series - S01E01 - Episode Name
    if ($normalized -match '^(?<series>.+?)\s+-\s+S(?<season>\d+)E(?<episode>\d+)\s+-\s+(?<episodename>.+)$') {
        $seriesInfo = @{
            Series      = $matches['series'].Trim()
            Season      = [int]$matches['season']
            Episode     = [int]$matches['episode']
            EpisodeName = $matches['episodename'].Trim()
        }
    }
    # Pattern 2: Series - S01E01
    elseif ($normalized -match '^(?<series>.+?)\s+-\s+S(?<season>\d+)E(?<episode>\d+)$') {
        $seriesInfo = @{
            Series      = $matches['series'].Trim()
            Season      = [int]$matches['season']
            Episode     = [int]$matches['episode']
            EpisodeName = $null
        }
    }
    # Pattern 3: Series S01E01
    elseif ($normalized -match '^(?<series>.*?)\s*S(?<season>\d+)E(?<episode>\d+)$') {
        $seriesInfo = @{
            Series      = $matches['series'].Trim()
            Season      = [int]$matches['season']
            Episode     = [int]$matches['episode']
            EpisodeName = $null
        }
    }

    return $seriesInfo
}
