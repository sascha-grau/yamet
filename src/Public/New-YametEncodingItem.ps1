function New-YametEncodingItem {
    <#
    .SYNOPSIS
        Creates an encoded version of a video file.

    .DESCRIPTION
        The New-YametEncodingItem cmdlet encodes video files using ffmpeg with hardware acceleration
        support. It can remux files, transcode video/audio streams, and handle subtitles and attachments.
        The cmdlet supports both Windows (NVIDIA CUDA) and Linux platforms.

    .PARAMETER Path
        Specifies the path to the input video file. This parameter is mandatory.

    .PARAMETER OutputPath
        Specifies the output directory for the encoded file.

    .PARAMETER AutoSelectStreams
        If specified, automatically selects streams based on language preferences.

    .PARAMETER Languages
        Specifies the preferred languages for auto-selection (ISO 639-2 codes).

    .PARAMETER Remux
        If specified, remuxes the file without re-encoding (copies streams).

    .PARAMETER AudioStreams
        Specifies the audio stream indices to include.

    .PARAMETER SubtitleStreams
        Specifies the subtitle stream indices to include.

    .PARAMETER ForcedSubtitleStreams
        Specifies which subtitle streams should be marked as forced.

    .PARAMETER FontAttachments
        Specifies font attachment indices to include.

    .PARAMETER TargetFormat
        Specifies the target resolution. Valid values: '720p', '1080p', 'none'.

    .PARAMETER TargetCodec
        Specifies the video codec to use. Valid values: 'x264', 'x265', 'h264_nvenc', 'hevc_nvenc'.

    .PARAMETER TargetContainer
        Specifies the output container format. Valid values: 'mp4', 'mkv'.

    .PARAMETER InformOnly
        If specified, displays stream information without encoding.

    .PARAMETER CopyVideo
        If specified, copies the video stream without re-encoding.

    .PARAMETER CopyAudio
        If specified, copies audio streams without re-encoding.

    .EXAMPLE
        New-YametEncodingItem -Path 'movie.mkv' -OutputPath 'C:\Encoded' -AutoSelectStreams -Languages 'eng'

        Encodes a movie file with automatic stream selection for English audio/subtitles.

    .EXAMPLE
        New-YametEncodingItem -Path 'video.mkv' -Remux -OutputPath 'C:\Output'

        Remuxes the video file without re-encoding.

    .EXAMPLE
        New-YametEncodingItem -Path 'video.mkv' -InformOnly

        Displays stream information without encoding.

    .INPUTS
        System.IO.FileInfo
        You can pipe file objects to this cmdlet.

    .OUTPUTS
        None

    .NOTES
        Author: Your Name
        Date: 11/15/2025

        Requires: ffmpeg, mediainfo, mkvpropedit
        Use Test-YametPrerequisites to check for required tools.

        Hardware Acceleration:
        - On Windows with NVIDIA GPU: Uses CUDA acceleration (h264_nvenc/hevc_nvenc)
        - On Linux: Can use software encoding (x264/x265) or hardware encoding if available
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "File '$_' not found"
            }
            return $true
        })]
        [System.IO.FileInfo]$Path,

        [Parameter()]
        [switch]$AutoSelectStreams,

        [Parameter()]
        [ValidateSet('deu', 'ger', 'eng', 'jpn')]
        [string[]]$Languages = @('deu'),

        [Parameter()]
        [switch]$Remux,

        [Parameter()]
        [int[]]$AudioStreams,

        [Parameter()]
        [int[]]$SubtitleStreams,

        [Parameter()]
        [int[]]$ForcedSubtitleStreams,

        [Parameter()]
        [int[]]$FontAttachments,

        [Parameter()]
        [ValidateSet('720p', '1080p', 'none')]
        [string]$TargetFormat = '1080p',

        [Parameter()]
        [ValidateSet('x264', 'x265', 'h264_nvenc', 'hevc_nvenc')]
        [string]$TargetCodec = 'x264',

        [Parameter()]
        [ValidateSet('mp4', 'mkv')]
        [string]$TargetContainer = 'mkv',

        [Parameter()]
        [switch]$InformOnly,

        [Parameter()]
        [switch]$CopyVideo,

        [Parameter()]
        [switch]$CopyAudio,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    begin {
        Write-Verbose 'Starting video encoding process'

        # Check prerequisites
        $requiredTools = @('ffmpeg', 'mediainfo', 'mkvpropedit')
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

        # Check CUDA support if hardware codec is requested
        if ($TargetCodec -match 'nvenc') {
            if (-not (Test-YametCudaSupport)) {
                Write-Warning "CUDA/NVENC hardware encoding is not available. NVIDIA GPU or ffmpeg NVENC support not detected."
                Write-Warning "Falling back to software encoding. Use -TargetCodec 'x264' or 'x265' to avoid this warning."
                
                # Auto-fallback to software codec
                $TargetCodec = if ($TargetCodec -eq 'hevc_nvenc') { 'x265' } else { 'x264' }
                Write-Verbose "Switched to software codec: $TargetCodec"
            }
        }
    }

    process {
        try {
            # Get stream information
            $streamInfoParams = @{
                Path = $Path.FullName
            }
            if ($AutoSelectStreams) {
                $streamInfoParams['AutoSelectStreams'] = $true
                $streamInfoParams['Languages'] = $Languages
                if ($Remux) {
                    $streamInfoParams['Remux'] = $true
                }
            }
            $streamInfo = Get-YametVideoInformation @streamInfoParams

            # If InformOnly, display information and return
            if ($InformOnly) {
                Write-Output $streamInfo
                return
            }

            # Auto-select streams if enabled
            if ($AutoSelectStreams) {
                $AudioStreams = $streamInfo | Where-Object { $_.Type -eq 'Audio' } |
                    Select-Object -ExpandProperty Index

                $SubtitleStreams = $streamInfo | Where-Object { $_.Type -eq 'Text' } |
                    Select-Object -ExpandProperty Index

                $ForcedSubtitleStreams = $streamInfo |
                    Where-Object { $_.Type -eq 'Text' -and $_.Forced -eq 'Yes' } |
                    Select-Object -ExpandProperty Index
            }
            else {
                if (-not $PSBoundParameters.ContainsKey('AudioStreams') -or -not $AudioStreams) {
                    $primaryAudio = $streamInfo |
                        Where-Object { $_.Type -eq 'Audio' } |
                        Sort-Object -Property TypeOrder |
                        Select-Object -First 1

                    if ($primaryAudio) {
                        $AudioStreams = @([int]$primaryAudio.Index)
                    }
                }

                if (-not $PSBoundParameters.ContainsKey('SubtitleStreams') -or -not $SubtitleStreams) {
                    $primarySubtitle = $streamInfo |
                        Where-Object { $_.Type -eq 'Text' } |
                        Sort-Object -Property @{ Expression = { $_.Forced -eq 'Yes' } ; Descending = $true }, TypeOrder |
                        Select-Object -First 1

                    if ($primarySubtitle) {
                        $SubtitleStreams = @([int]$primarySubtitle.Index)
                    }
                }

                if ((-not $PSBoundParameters.ContainsKey('ForcedSubtitleStreams') -or -not $ForcedSubtitleStreams) -and $SubtitleStreams) {
                    $forcedSelection = $streamInfo |
                        Where-Object { $_.Type -eq 'Text' -and $_.Forced -eq 'Yes' -and $SubtitleStreams -contains $_.Index } |
                        ForEach-Object { [int]$_.Index }

                    $ForcedSubtitleStreams = @($forcedSelection)
                }
            }

            # Build output path and filename
            $outputInfo = Get-YametOutputPath -BasePath $OutputPath -FileName $Path.BaseName -TargetContainer $TargetContainer
            $OutputPath = $outputInfo.OutputDirectory
            $outputFile = $outputInfo.OutputFileName
            $title = $outputInfo.Title

            # Create output directory
            if (-not (Test-Path $OutputPath)) {
                New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
                Write-Verbose "Created output directory: $OutputPath"
            }

            $fullOutputPath = Join-Path $OutputPath $outputFile

            # Build ffmpeg parameters
            $params = @()
            $mkvPropParams = @()

            #############################################################################################
            ### Video Encoding
            #############################################################################################

            $videoStream = $streamInfo | Where-Object { $_.Type -eq 'Video' } | Select-Object -First 1

            if ($videoStream) {
                $videoEncoding = Get-YametVideoEncodingParams -VideoStream $videoStream `
                    -InputPath $Path.FullName `
                    -Title $title `
                    -TargetCodec $TargetCodec `
                    -TargetFormat $TargetFormat `
                    -Remux:$Remux `
                    -CopyVideo:$CopyVideo

                $params += $videoEncoding.FFmpegParams
                $mkvPropParams += $videoEncoding.MkvPropParams
            }

            #############################################################################################
            ### Audio Encoding
            #############################################################################################

            if ($AudioStreams) {
                Add-YametAudioEncodingParams -FFmpegParams ([ref]$params) `
                    -MkvPropParams ([ref]$mkvPropParams) `
                    -StreamInfo $streamInfo `
                    -AudioStreams $AudioStreams `
                    -Remux:$Remux `
                    -CopyAudio:$CopyAudio
            }

            #############################################################################################
            ### Subtitles
            #############################################################################################

            if ($SubtitleStreams) {
                Add-YametSubtitleEncodingParams -FFmpegParams ([ref]$params) `
                    -MkvPropParams ([ref]$mkvPropParams) `
                    -StreamInfo $streamInfo `
                    -SubtitleStreams $SubtitleStreams `
                    -ForcedSubtitleStreams $ForcedSubtitleStreams
            }

            #############################################################################################
            ### Attachments (Fonts)
            #############################################################################################

            if ($FontAttachments) {
                foreach ($fontIndex in $FontAttachments) {
                    $params += '-map', "0:t:$fontIndex"
                    $params += '-c:t', 'copy'
                }
            }

            # Confirmation
            $confirmMessage = "Encode video file '$($Path.Name)' to '$fullOutputPath'"
            if ($PSCmdlet.ShouldProcess($Path.Name, $confirmMessage)) {
                # Execute ffmpeg
                $ffmpegCommand = "ffmpeg -y -hide_banner $($params -join ' ') `"$fullOutputPath`""
                Write-Verbose "Executing: $ffmpegCommand"
                Write-Host "Encoding: $($Path.Name)" -ForegroundColor Yellow

                & ffmpeg -y -hide_banner @params $fullOutputPath

                if ($LASTEXITCODE -ne 0) {
                    throw "ffmpeg failed with exit code $LASTEXITCODE"
                }

                # Apply mkv properties if mkv container
                if ($TargetContainer -eq 'mkv' -and $mkvPropParams.Count -gt 0) {
                    Write-Verbose "Applying MKV properties"
                    & mkvpropedit $fullOutputPath @mkvPropParams

                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "mkvpropedit failed with exit code $LASTEXITCODE"
                    }
                }

                Write-Host "Encoding completed: $fullOutputPath" -ForegroundColor Green
            }

        } catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'EncodingFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $Path
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose 'Video encoding process completed'
    }
}
