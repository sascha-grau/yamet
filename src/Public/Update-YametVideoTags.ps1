function Update-YametVideoTags {
    <#
    .SYNOPSIS
        Updates metadata tags in a video file.

    .DESCRIPTION
        The Update-YametVideoTags cmdlet updates track metadata (titles, language, flags)
        in MKV video files. It can optionally copy or move the file to a new location
        with proper naming conventions for series.

    .PARAMETER Path
        Specifies the path to the video file. This parameter is mandatory.

    .PARAMETER OutputPath
        Specifies the output directory. Required when using -Copy or -Move.

    .PARAMETER Copy
        If specified, copies the file to the output path after updating tags.

    .PARAMETER Move
        If specified, moves the file to the output path after updating tags.

    .PARAMETER NamingProfile
        Specifies the naming profile to use for parsing and formatting filenames.
        Valid values: 'Standard', 'Plex', 'Emby', 'Jellyfin'
        Default: 'Standard'

    .PARAMETER MetadataScraper
        Specifies the metadata scraper to use for retrieving episode/movie information.
        Valid values: 'Local', 'TheTVDB', 'TMDB', 'IMDB', 'AniDB'
        Default: 'Local' (extracts metadata from filename only)

    .PARAMETER ScraperApiKey
        API key for the selected metadata scraper (required for TheTVDB, TMDB, etc.).
        Not needed for 'Local' scraper.

    .EXAMPLE
        Update-YametVideoTags -Path 'movie.mkv'

        Updates metadata tags in the video file using local filename parsing.

    .EXAMPLE
        Update-YametVideoTags -Path 'episode.mkv' -OutputPath 'C:\Videos' -Move

        Updates tags and moves the file to the specified location with proper naming.

    .EXAMPLE
        Update-YametVideoTags -Path 'episode.mkv' -OutputPath 'C:\Videos' -Move -NamingProfile 'Plex'

        Updates tags and moves the file using Plex naming conventions.

    .EXAMPLE
        Update-YametVideoTags -Path 'episode.mkv' -MetadataScraper 'TheTVDB' -ScraperApiKey 'your-api-key'

        Updates tags using metadata from TheTVDB API.

    .EXAMPLE
        Update-YametVideoTags -Path 'movie.mkv' -MetadataScraper 'TMDB' -ScraperApiKey 'your-api-key'

        Updates tags using metadata from The Movie Database API.

    .INPUTS
        System.IO.FileInfo
        You can pipe file objects to this cmdlet.

    .OUTPUTS
        None

    .NOTES
        Author: Your Name
        Date: 11/15/2025

        Requires: mediainfo, mkvpropedit
        Use Test-YametPrerequisites to check for required tools.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "File '$_' not found"
            }

            $extension = [System.IO.Path]::GetExtension($_)
            if ([string]::IsNullOrEmpty($extension) -or ($extension.ToLowerInvariant() -ne '.mkv')) {
                throw "File '$_' is not an MKV container. Update-YametVideoTags only supports MKV files."
            }

            return $true
        })]
        [System.IO.FileInfo]$Path,

        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [switch]$Copy,

        [Parameter()]
        [switch]$Move,

        [Parameter()]
        [ValidateSet('Standard', 'Plex', 'Emby', 'Jellyfin')]
        [string]$NamingProfile = 'Standard',

        [Parameter()]
        [ValidateSet('Local', 'TheTVDB', 'TMDB', 'IMDB', 'AniDB')]
        [string]$MetadataScraper = 'Local',

        [Parameter()]
        [string]$ScraperApiKey
    )

    begin {
        Write-Verbose 'Starting video tag update'

        $requiredTools = @('mediainfo', 'mkvpropedit')
        foreach ($tool in $requiredTools) {
            if (-not (Test-YametPrerequisite -ToolName $tool)) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.InvalidOperationException]::new("$tool is not installed. Run 'Test-YametPrerequisites -Install' to install required tools."),
                    'PrerequisiteNotFound',
                    [System.Management.Automation.ErrorCategory]::NotInstalled,
                    $tool
                )
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        }

        if ($Copy -and $Move) {
            throw '-Copy and -Move cannot be used together'
        }

        if (($Copy -or $Move) -and [string]::IsNullOrEmpty($OutputPath)) {
            throw "-OutputPath is required when using -Copy or -Move"
        }

        # Validate API key for online scrapers
        if ($MetadataScraper -ne 'Local' -and [string]::IsNullOrEmpty($ScraperApiKey)) {
            Write-Warning "$MetadataScraper scraper requires an API key. Falling back to 'Local' scraper."
            $MetadataScraper = 'Local'
        }
    }

    process {
        try {
            $title = $Path.BaseName
            $outputFile = $null

            # Handle series naming convention
            if ($title -match 'S\d+E\d+') {
                # Parse filename
                $seriesInfo = $null
                if ($title -match '(?<series>.*) - S(?<season>\d+)E(?<episode>\d+) - (?<episodename>.*)') {
                    $seriesInfo = @{
                        Series = $matches['series']
                        Season = [int]$matches['season']
                        Episode = [int]$matches['episode']
                        EpisodeName = $matches['episodename']
                    }
                } elseif ($title -match '(?<series>.*) - S(?<season>\d+)E(?<episode>\d+)') {
                    $seriesInfo = @{
                        Series = $matches['series']
                        Season = [int]$matches['season']
                        Episode = [int]$matches['episode']
                        EpisodeName = $null
                    }
                } elseif ($title -match '(?<series>.*)[^-] S(?<season>\d+)E(?<episode>\d+)') {
                    $seriesInfo = @{
                        Series = $matches['series']
                        Season = [int]$matches['season']
                        Episode = [int]$matches['episode']
                        EpisodeName = $null
                    }
                }

                if ($seriesInfo) {
                    # Get metadata from scraper
                    $metadata = Get-YametMetadata -SeriesInfo $seriesInfo -Scraper $MetadataScraper -ApiKey $ScraperApiKey
                    
                    # Update series info with scraped metadata if available
                    if ($metadata.Title -and -not $seriesInfo.EpisodeName) {
                        $seriesInfo.EpisodeName = $metadata.Title
                    }
                    
                    Write-Verbose "Metadata source: $($metadata.Source)"
                    
                    # Format title based on naming profile
                    $title = switch ($NamingProfile) {
                        'Standard' {
                            if ($seriesInfo.EpisodeName) {
                                '{0} - S{1:d2} E{2:d3} - {3}' -f $seriesInfo.Series, $seriesInfo.Season, $seriesInfo.Episode, $seriesInfo.EpisodeName
                            } else {
                                '{0} - S{1:d2} E{2:d3}' -f $seriesInfo.Series, $seriesInfo.Season, $seriesInfo.Episode
                            }
                        }
                        { $_ -in @('Plex', 'Emby', 'Jellyfin') } {
                            if ($seriesInfo.EpisodeName) {
                                '{0} - s{1:d2}e{2:d2} - {3}' -f $seriesInfo.Series, $seriesInfo.Season, $seriesInfo.Episode, $seriesInfo.EpisodeName
                            } else {
                                '{0} - s{1:d2}e{2:d2}' -f $seriesInfo.Series, $seriesInfo.Season, $seriesInfo.Episode
                            }
                        }
                    }

                    # Format output path and filename based on naming profile
                    if ($OutputPath) {
                        $seasonFolder = if ($seriesInfo.Season -eq 0) { 'Specials' } else { "Season {0:d2}" -f $seriesInfo.Season }

                        $OutputPath = Join-Path $OutputPath $seriesInfo.Series
                        $OutputPath = Join-Path $OutputPath $seasonFolder

                        if (-not (Test-Path $OutputPath)) {
                            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
                        }

                        $outputFile = switch ($NamingProfile) {
                            'Standard' {
                                '{0} S{1:d2}E{2:d3}{3}' -f $seriesInfo.Series, $seriesInfo.Season, $seriesInfo.Episode, $Path.Extension
                            }
                            { $_ -in @('Plex', 'Emby', 'Jellyfin') } {
                                '{0} - s{1:d2}e{2:d2}{3}' -f $seriesInfo.Series, $seriesInfo.Season, $seriesInfo.Episode, $Path.Extension
                            }
                        }
                    }
                }
            } else {
                # Non-series file
                if ($OutputPath) {
                    $OutputPath = Join-Path $OutputPath $Path.BaseName
                    if (-not (Test-Path $OutputPath)) {
                        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
                    }
                    $outputFile = '{0}{1}' -f $Path.BaseName, $Path.Extension
                }
            }

            # Get stream information
            $streamInfo = Get-YametVideoInformation -Path $Path.FullName

            # Build mkvpropedit parameters
            $mkvPropParams = @('--edit', 'info', '--set', "title=$title")

            # Video track
            $videoStream = $streamInfo | Where-Object { $_.Type -eq 'Video' } | Select-Object -First 1

            if ($videoStream) {
                $videoFormat = switch ($videoStream.CodecId) {
                    'V_MPEG2' { 'MPEG2' }
                    { $_ -in @('V_MPEG4/ISO/AVC', 'AVC', 'AVC1', '27') } { 'H264' }
                    'V_MS/VFW/FOURCC / WVC1' { 'VC1' }
                    'V_MPEGH/ISO/HEVC' { 'H265' }
                    default { 'H264' }
                }

                $mkvPropParams += '--edit', 'track:v1', '--set', 'flag-forced=0'
                $mkvPropParams += '--edit', 'track:v1', '--set', 'flag-default=0'
                $mkvPropParams += '--edit', 'track:v1', '--set', "name=Video - $videoFormat"
                $mkvPropParams += '--tags', 'all:'
            }

            # Audio tracks
            $audioStreams = $streamInfo | Where-Object { $_.Type -eq 'Audio' }
            $defaultAudioAssigned = $false
            foreach ($audioStream in $audioStreams) {
                $isDefaultAudio = -not $defaultAudioAssigned
                if ($isDefaultAudio) {
                    $defaultAudioAssigned = $true
                }

                $defaultFlagValue = if ($isDefaultAudio) { 1 } else { 0 }

                $mkvPropParams += '--edit', "track:a$($audioStream.TypeOrder)", '--set', 'flag-forced=0'
                $mkvPropParams += '--edit', "track:a$($audioStream.TypeOrder)", '--set', "flag-default=$defaultFlagValue"

                $audioTitle = switch ($audioStream.Channels) {
                    '1' { "Audio - $($audioStream.Format) - Mono" }
                    '2' { "Audio - $($audioStream.Format) - Stereo" }
                    '6' { "Audio - $($audioStream.Format) - 5.1" }
                    '8' { "Audio - $($audioStream.Format) - 7.1" }
                    default { "Audio - $($audioStream.Format)" }
                }

                $mkvPropParams += '--edit', "track:a$($audioStream.TypeOrder)", '--set', "name=$audioTitle"
            }

            # Subtitle tracks
            $subtitleStreams = $streamInfo | Where-Object { $_.Type -eq 'Text' }
            foreach ($subStream in $subtitleStreams) {
                $subTitle = if ($subStream.Forced -eq 'Yes') {
                    "Subtitles - $($subStream.LanguageString) - Forced"
                } else {
                    "Subtitles - $($subStream.LanguageString)"
                }

                $mkvPropParams += '--edit', "track:s$($subStream.TypeOrder)", '--set', "name=$subTitle"
            }

            # Attachments
            $general = $streamInfo | Where-Object { $_.Type -eq 'General' } | Select-Object -First 1
            if ($general -and $general.Attachments) {
                $attachments = $general.Attachments -split ' / '
                for ($i = 0; $i -lt $attachments.Count; $i++) {
                    $attachment = $attachments[$i]
                    if ($attachment -match '[\w-]+?(?=\.)') {
                        $mkvPropParams += '--attachment-name', $Matches[0], '--update-attachment', ($i + 1).ToString()
                    }
                }
            }

            # Execute mkvpropedit
            if ($PSCmdlet.ShouldProcess($Path.Name, 'Update video tags')) {
                $hasTransferAction = $Move.IsPresent -or $Copy.IsPresent
                Write-Host "File: $($Path.Name) | " -NoNewline -ForegroundColor Cyan
                Write-Verbose "Executing: mkvpropedit $($Path.FullName) $($mkvPropParams -join ' ')"

                & mkvpropedit $Path.FullName @mkvPropParams

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "ReTag | " -NoNewline -ForegroundColor Green
                    if (-not $hasTransferAction) {
                        Write-Host ''
                    }
                } else {
                    Write-Host ''
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("mkvpropedit failed with exit code $LASTEXITCODE"),
                        'MkvPropEditFailed',
                        [System.Management.Automation.ErrorCategory]::WriteError,
                        $Path.FullName
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }

                # Move or copy file
                if ($Move) {
                    $destination = Join-Path $OutputPath $outputFile
                    Write-Host "Move: $destination" -ForegroundColor Yellow
                    try {
                        Move-Item -Path $Path.FullName -Destination $destination -Force -ErrorAction Stop
                    } catch {
                        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $_.Exception,
                            'MoveVideoFailed',
                            [System.Management.Automation.ErrorCategory]::WriteError,
                            $destination
                        )
                        $PSCmdlet.ThrowTerminatingError($errorRecord)
                    }
                }

                if ($Copy) {
                    $destination = Join-Path $OutputPath $outputFile
                    Write-Host "Copy: $destination" -ForegroundColor Yellow
                    try {
                        Copy-Item -Path $Path.FullName -Destination $destination -Force -ErrorAction Stop
                    } catch {
                        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $_.Exception,
                            'CopyVideoFailed',
                            [System.Management.Automation.ErrorCategory]::WriteError,
                            $destination
                        )
                        $PSCmdlet.ThrowTerminatingError($errorRecord)
                    }
                }
            }

        } catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'VideoTagUpdateFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $Path
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose 'Video tag update completed'
    }
}
