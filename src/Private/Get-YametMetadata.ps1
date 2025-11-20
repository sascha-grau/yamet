function Get-YametMetadata {
    <#
    .SYNOPSIS
        Retrieves metadata from various sources.

    .DESCRIPTION
        Internal helper function that retrieves metadata from different scrapers
        including local filename parsing and online databases.

    .PARAMETER SeriesInfo
        Hashtable containing series information (Series, Season, Episode).

    .PARAMETER Scraper
        The scraper to use: 'Local', 'TheTVDB', 'TMDB', 'IMDB', 'AniDB'.

    .PARAMETER ApiKey
        API key for online scrapers.

    .OUTPUTS
        Hashtable with metadata (Title, Description, Year, etc.)
    #>

    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$SeriesInfo,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Local', 'TheTVDB', 'TMDB', 'IMDB', 'AniDB')]
        [string]$Scraper,

        [Parameter()]
        [string]$ApiKey
    )

    Write-Verbose "Using $Scraper scraper for metadata retrieval"

    switch ($Scraper) {
        'Local' {
            # Return metadata from filename only (current behavior)
            return @{
                Title = if ($SeriesInfo.EpisodeName) {
                    $SeriesInfo.EpisodeName
                } else {
                    '{0} S{1:d2}E{2:d2}' -f $SeriesInfo.Series, $SeriesInfo.Season, $SeriesInfo.Episode
                }
                Series = $SeriesInfo.Series
                Season = $SeriesInfo.Season
                Episode = $SeriesInfo.Episode
                Description = $null
                Year = $null
                Source = 'Local'
            }
        }

        'TheTVDB' {
            Write-Warning "TheTVDB scraper not yet implemented. Using local metadata."
            # TODO: Implement TheTVDB API integration
            # - Search for series by name
            # - Get episode details by season/episode number
            # - Return formatted metadata
            if ([string]::IsNullOrEmpty($ApiKey)) {
                Write-Warning "TheTVDB requires an API key. Visit https://thetvdb.com/api-information"
            }

            $title = if ($SeriesInfo.EpisodeName) {
                $SeriesInfo.EpisodeName
            } else {
                '{0} S{1:d2}E{2:d2}' -f $SeriesInfo.Series, $SeriesInfo.Season, $SeriesInfo.Episode
            }

            return @{
                Title = $title
                Series = $SeriesInfo.Series
                Season = $SeriesInfo.Season
                Episode = $SeriesInfo.Episode
                Description = $null
                Year = $null
                Source = 'Local (TheTVDB not implemented)'
            }
        }

        'TMDB' {
            Write-Warning "TMDB scraper not yet implemented. Using local metadata."
            # TODO: Implement The Movie Database API integration
            # - Search for TV show or movie
            # - Get episode/movie details
            # - Return formatted metadata
            if ([string]::IsNullOrEmpty($ApiKey)) {
                Write-Warning "TMDB requires an API key. Visit https://www.themoviedb.org/settings/api"
            }

            $title = if ($SeriesInfo.EpisodeName) {
                $SeriesInfo.EpisodeName
            } else {
                '{0} S{1:d2}E{2:d2}' -f $SeriesInfo.Series, $SeriesInfo.Season, $SeriesInfo.Episode
            }

            return @{
                Title = $title
                Series = $SeriesInfo.Series
                Season = $SeriesInfo.Season
                Episode = $SeriesInfo.Episode
                Description = $null
                Year = $null
                Source = 'Local (TMDB not implemented)'
            }
        }

        'IMDB' {
            Write-Warning "IMDB scraper not yet implemented. Using local metadata."
            # TODO: Implement IMDB integration (via OMDb API or web scraping)
            # Note: IMDB doesn't have an official API
            if ([string]::IsNullOrEmpty($ApiKey)) {
                Write-Warning "Consider using OMDb API (requires key): http://www.omdbapi.com/apikey.aspx"
            }

            $title = if ($SeriesInfo.EpisodeName) {
                $SeriesInfo.EpisodeName
            } else {
                '{0} S{1:d2}E{2:d2}' -f $SeriesInfo.Series, $SeriesInfo.Season, $SeriesInfo.Episode
            }

            return @{
                Title = $title
                Series = $SeriesInfo.Series
                Season = $SeriesInfo.Season
                Episode = $SeriesInfo.Episode
                Description = $null
                Year = $null
                Source = 'Local (IMDB not implemented)'
            }
        }

        'AniDB' {
            Write-Warning "AniDB scraper not yet implemented. Using local metadata."
            # TODO: Implement AniDB integration for anime series
            # - UDP API or HTTP API
            # - Get episode titles and metadata
            # - Handle anime-specific formatting
            if ([string]::IsNullOrEmpty($ApiKey)) {
                Write-Warning "AniDB requires registration: https://anidb.net/perl-bin/animedb.pl?show=client"
            }

            $title = if ($SeriesInfo.EpisodeName) {
                $SeriesInfo.EpisodeName
            } else {
                '{0} S{1:d2}E{2:d2}' -f $SeriesInfo.Series, $SeriesInfo.Season, $SeriesInfo.Episode
            }

            return @{
                Title = $title
                Series = $SeriesInfo.Series
                Season = $SeriesInfo.Season
                Episode = $SeriesInfo.Episode
                Description = $null
                Year = $null
                Source = 'Local (AniDB not implemented)'
            }
        }
    }
}
