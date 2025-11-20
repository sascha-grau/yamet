function Get-YametVideoInformation {
    <#
    .SYNOPSIS
        Gets detailed information about a video file.

    .DESCRIPTION
        The Get-YametVideoInformation cmdlet retrieves comprehensive information about video files
        using mediainfo. It parses video, audio, and subtitle streams, and can automatically
        select streams based on language preferences.

    .PARAMETER Path
        Specifies the path to the video file. This parameter is mandatory.

    .PARAMETER AutoSelectStreams
        If specified, automatically selects appropriate video, audio, and subtitle streams
        based on the specified languages.

    .PARAMETER Languages
        Specifies the preferred languages for auto-selection (ISO 639-2 codes).
        Valid values are: 'deu', 'ger', 'eng', 'jpn'.
        Only used when -AutoSelectStreams is specified.

    .PARAMETER Remux
        If specified along with -AutoSelectStreams, includes high-quality audio streams
        with more than 6 channels.

    .EXAMPLE
        Get-YametVideoInformation -Path 'C:\Videos\movie.mkv'

        Retrieves all stream information from the video file.

    .EXAMPLE
        Get-YametVideoInformation -Path 'movie.mkv' -AutoSelectStreams -Languages 'eng', 'deu'

        Retrieves stream information and auto-selects English and German streams.

    .EXAMPLE
        Get-ChildItem *.mkv | ForEach-Object { Get-YametVideoInformation -Path $_.FullName }

        Gets information for all MKV files in the current directory.

    .INPUTS
        System.String
        You can pipe file paths to this cmdlet.

    .OUTPUTS
        PSCustomObject
        Returns custom objects representing media streams.

    .NOTES
        Author: Your Name
        Date: 11/15/2025

        Requires: mediainfo
        Use Test-YametPrerequisites to check for required tools.
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "File '$_' not found"
            }
            return $true
        })]
        [string]$Path,

        [Parameter()]
        [switch]$AutoSelectStreams,

        [Parameter()]
        [ValidateSet('deu', 'ger', 'eng', 'jpn')]
        [string[]]$Languages = @('deu'),

        [Parameter()]
        [switch]$Remux
    )

    begin {
        Write-Verbose 'Starting video information retrieval'

        # Check if mediainfo is installed
        if (-not (Test-YametPrerequisite -ToolName 'mediainfo')) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new("mediainfo is not installed. Run 'Test-YametPrerequisites -Install' to install it."),
                'MediaInfoNotFound',
                [System.Management.Automation.ErrorCategory]::NotInstalled,
                'mediainfo'
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        $tryConvertToInt = {
            param(
                [Parameter()]$Value,
                [Parameter()] [double]$Divisor = 1
            )

            if ($null -eq $Value) {
                return $null
            }

            $stringValue = $Value.ToString().Trim()
            if (-not $stringValue) {
                return $null
            }

            $numberStyles = [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands
            $parsed = 0d
            if ([double]::TryParse($stringValue, $numberStyles, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
                return [int][math]::Round($parsed / $Divisor)
            }

            return $null
        }
    }

    process {
        try {
            # Resolve to absolute path
            $Path = Resolve-Path -Path $Path | Select-Object -ExpandProperty Path

            Write-Verbose "Analyzing video file: $Path"

            # Execute mediainfo and parse JSON output
            $mediainfoOutput = & mediainfo --Full --Output=JSON $Path

            if ($LASTEXITCODE -ne 0) {
                throw "mediainfo failed with exit code $LASTEXITCODE"
            }

            $json = $mediainfoOutput | ConvertFrom-Json
            $trackInfo = @()
            $index = -1

            foreach ($track in $json.media.track) {
                $trackInfo += [PSCustomObject]@{
                    PSTypeName = 'Yamet.MediaTrack'
                    Type = $track.'@type'
                    Index = $index++
                    TypeOrder = [int](& { if ($track.'@typeorder') { $track.'@typeorder' } else { 1 } })
                    Title = $track.Title
                    ScanType = $track.ScanType
                    ScanOrder = $track.ScanOrder
                    LanguageString = if ($track.Language_String) { [string]$track.Language_String } else { $null }
                    LanguageIsoCode = if ($track.Language_String3) { [string]$track.Language_String3 } else { $null }
                    Format = [string](& { if ($track.Format_Commercial_IfAny) { $track.Format_Commercial_IfAny } else { $track.Format } })
                    Width = $track.Width
                    Height = $track.Height
                    ScreenSize = [string](& { if ($track.Width) { "$($track.Width) x $($track.Height)" } })
                    Fps = $track.FrameRate
                    CodecId = $track.CodecID
                    BitrateKB = & $tryConvertToInt $track.BitRate 1KB
                    BitrateString = $track.BitRate_String -replace '/s', 'ps'
                    SizeMB = & $tryConvertToInt $track.StreamSize 1MB
                    Framerate = $track.Framerate
                    ColorPrim = $track.colour_primaries
                    ColorMatrix = $track.matrix_coefficients
                    ColorTransfer = $track.transfer_characteristics
                    HDRFormat = $track.HDR_Format
                    HDRProfile = $track.HDR_Format_Compatibility
                    Forced = [string](& { if ((Get-Member -InputObject $track -Name 'Forced' -MemberType Properties) -and $null -ne $track.Forced) { $track.Forced } else { 'No' } })
                    SubtitleElements = $track.ElementCount
                    Channels = $track.Channels
                    Attachments = $track.extra.Attachments
                }
            }

            if ($AutoSelectStreams) {
                $trackInfoAuto = @()

                # Video - Select first video stream
                $videoTrack = $trackInfo | Where-Object { $_.Type -eq 'Video' } | Select-Object -First 1
                if ($videoTrack) {
                    $trackInfoAuto += $videoTrack
                }

                # Audio - Select best audio streams for each language
                foreach ($lang in $Languages) {
                    if ($Remux) {
                        # Include high-quality surround sound
                        $audioTrack = $trackInfo |
                            Where-Object { $_.Type -eq 'Audio' -and $_.LanguageIsoCode -eq $lang } |
                            Sort-Object -Property BitrateKB -Descending |
                            Select-Object -First 1

                        if ($audioTrack) {
                            $trackInfoAuto += $audioTrack
                        }
                    }

                    # Include stereo/5.1 audio
                    $audioTrack = $trackInfo |
                        Where-Object { $_.Type -eq 'Audio' -and $_.Channels -le 6 -and $_.LanguageIsoCode -eq $lang } |
                        Sort-Object -Property BitrateKB -Descending |
                        Select-Object -First 1

                    if ($audioTrack) {
                        $trackInfoAuto += $audioTrack
                    }
                }

                # Fallback audio selection when no language match exists
                if (-not ($trackInfoAuto | Where-Object { $_.Type -eq 'Audio' })) {
                    $fallbackAudio = $trackInfo |
                        Where-Object { $_.Type -eq 'Audio' } |
                        Sort-Object -Property @{ Expression = { $_.Channels } ; Descending = $true }, @{ Expression = { $_.BitrateKB } ; Descending = $true } |
                        Select-Object -First 1

                    if ($fallbackAudio) {
                        $trackInfoAuto += $fallbackAudio
                    }
                }

                # Subtitles - Select subtitle streams for each language
                $subtitleTracks = $trackInfo | Where-Object { $_.Type -eq 'Text' }
                if (($subtitleTracks | Measure-Object).Count -gt 0) {
                    foreach ($lang in $Languages) {
                        $langSubtitles = $subtitleTracks | Where-Object { $_.LanguageIsoCode -eq $lang }
                        $subtitleCount = ($langSubtitles | Measure-Object).Count

                        if ($subtitleCount -eq 0) {
                            # No subtitles for this language
                            continue
                        } elseif ($subtitleCount -eq 1) {
                            # Only one subtitle track - include it as-is without modifying the Forced flag
                            $trackInfoAuto += $langSubtitles[0]
                        } else {
                            # Multiple subtitle tracks for this language
                            # First, check if any are explicitly marked as forced
                            $explicitForcedSub = $langSubtitles | Where-Object { $_.Forced -eq 'Yes' } | Select-Object -First 1
                            
                            if ($explicitForcedSub) {
                                # Use the explicitly marked forced subtitle
                                $trackInfoAuto += $explicitForcedSub
                                
                                # Get the full subtitle (largest, excluding the forced one)
                                $fullSub = $langSubtitles |
                                    Where-Object { $_.Index -ne $explicitForcedSub.Index } |
                                    Sort-Object -Property SizeMB -Descending |
                                    Select-Object -First 1
                                
                                if ($fullSub) {
                                    $trackInfoAuto += $fullSub
                                }
                            } else {
                                # No explicit forced flag - use size heuristic
                                # Smallest is typically forced (foreign language parts only)
                                $forcedSub = $langSubtitles |
                                    Sort-Object -Property SizeMB |
                                    Select-Object -First 1
                                
                                # Largest is typically full subtitles
                                $fullSub = $langSubtitles |
                                    Sort-Object -Property SizeMB -Descending |
                                    Select-Object -First 1
                                
                                # Only add if they're different tracks
                                if ($forcedSub.Index -ne $fullSub.Index) {
                                    $trackInfoAuto += $forcedSub
                                    $trackInfoAuto += $fullSub
                                } else {
                                    # Same track (shouldn't happen, but handle gracefully)
                                    $trackInfoAuto += $forcedSub
                                }
                            }
                        }
                    }

                    if (-not ($trackInfoAuto | Where-Object { $_.Type -eq 'Text' })) {
                        $fallbackSubtitle = $subtitleTracks |
                            Sort-Object -Property @{ Expression = { $_.Forced -eq 'Yes' } ; Descending = $true }, @{ Expression = { $_.SizeMB } ; Descending = $true } |
                            Select-Object -First 1

                        if ($fallbackSubtitle) {
                            $trackInfoAuto += $fallbackSubtitle
                        }
                    }
                }

                # Attachments (fonts)
                $attachmentSource = $trackInfo |
                    Where-Object { $_.Type -eq 'General' -and $_.Attachments } |
                    Select-Object -First 1

                if (-not $attachmentSource -and $videoTrack -and $videoTrack.Attachments) {
                    $attachmentSource = $videoTrack
                }

                if ($attachmentSource -and $attachmentSource.Attachments) {
                    $attachments = $attachmentSource.Attachments -split ' / '
                    Write-Verbose "Found $($attachments.Count) attachment(s)"

                    foreach ($attachment in $attachments) {
                        $attachmentTrack = [PSCustomObject]@{
                            PSTypeName = 'Yamet.MediaTrack'
                            Type = 'Attachment'
                            Index = [array]::IndexOf($attachments, $attachment)
                            TypeOrder = [array]::IndexOf($attachments, $attachment)
                            Title = $attachment
                            ScanType = $null
                            ScanOrder = $null
                            LanguageString = $null
                            LanguageIsoCode = $null
                            Format = $null
                            Width = $null
                            Height = $null
                            ScreenSize = $null
                            Fps = $null
                            CodecId = $null
                            BitrateKB = $null
                            BitrateString = $null
                            SizeMB = $null
                            Framerate = $null
                            ColorPrim = $null
                            ColorMatrix = $null
                            ColorTransfer = $null
                            HDRFormat = $null
                            HDRProfile = $null
                            Forced = $null
                            SubtitleElements = $null
                            Channels = $null
                            Attachments = $null
                        }
                        $trackInfoAuto += $attachmentTrack
                    }
                }

                # Output unique tracks
                $trackInfoAuto | Select-Object * -Unique | ForEach-Object { Write-Output $_ }
            } else {
                # Output all tracks
                $trackInfo | ForEach-Object { Write-Output $_ }
            }

        } catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'VideoInformationRetrievalFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $Path
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose 'Video information retrieval completed'
    }
}
