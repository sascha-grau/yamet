function Add-YametSubtitleEncodingParams {
    <#
    .SYNOPSIS
        Adds subtitle encoding parameters to ffmpeg command.

    .DESCRIPTION
        Internal helper function that appends subtitle stream parameters
        to the ffmpeg parameter array.

    .PARAMETER FFmpegParams
        Reference to the ffmpeg parameters array.

    .PARAMETER MkvPropParams
        Reference to the mkvpropedit parameters array.

    .PARAMETER StreamInfo
        Array of stream information objects.

    .PARAMETER SubtitleStreams
        Array of subtitle stream indices to include.

    .PARAMETER ForcedSubtitleStreams
        Array of subtitle stream indices that should be marked as forced.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ref]$FFmpegParams,

        [Parameter(Mandatory = $true)]
        [ref]$MkvPropParams,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$StreamInfo,

        [Parameter(Mandatory = $true)]
        [int[]]$SubtitleStreams,

        [Parameter()]
        [int[]]$ForcedSubtitleStreams = @()
    )

    $subIndex = 0
    $defaultSubtitleAssigned = $false
    foreach ($subStreamIndex in $SubtitleStreams) {
        $subStream = $StreamInfo | Where-Object { $_.Type -eq 'Text' -and $_.Index -eq $subStreamIndex } | Select-Object -First 1

        if (-not $subStream) {
            continue
        }

        # Map subtitle stream
        $FFmpegParams.Value += '-map', "0:$($subStream.Index)"

        # Handle codec conversion
        if ($subStream.CodecId -eq 'tx3g') {
            $FFmpegParams.Value += "-c:s:$subIndex", 'srt'
        } else {
            $FFmpegParams.Value += "-c:s:$subIndex", 'copy'
        }

        # Metadata
        $FFmpegParams.Value += "-metadata:s:s:$subIndex", "language=$($subStream.LanguageIsoCode)"

        # Forced subtitle handling
        $isForced = $ForcedSubtitleStreams -contains $subStreamIndex
        $dispositionFlags = @()
        $defaultFlag = 0

        if ($isForced) {
            $FFmpegParams.Value += "-metadata:s:s:$subIndex", "title=Subtitles - $($subStream.LanguageString) - Forced"
            $dispositionFlags += 'forced'
            $MkvPropParams.Value += '--edit', "track:s$($subIndex + 1)", '--set', 'flag-default=0'
            $MkvPropParams.Value += '--edit', "track:s$($subIndex + 1)", '--set', 'flag-forced=1'
        } else {
            $FFmpegParams.Value += "-metadata:s:s:$subIndex", "title=Subtitles - $($subStream.LanguageString)"
            $defaultFlag = if (-not $defaultSubtitleAssigned) {
                $defaultSubtitleAssigned = $true
                1
            } else {
                0
            }

            $MkvPropParams.Value += '--edit', "track:s$($subIndex + 1)", '--set', "flag-default=$defaultFlag"
            $MkvPropParams.Value += '--edit', "track:s$($subIndex + 1)", '--set', 'flag-forced=0'
            if ($defaultFlag -eq 1) {
                $dispositionFlags += 'default'
            }
        }
        $dispositionValue = if ($dispositionFlags.Count -gt 0) { $dispositionFlags -join '+' } else { '0' }

        $FFmpegParams.Value += "-disposition:s:$subIndex", $dispositionValue
        $subIndex++
    }
}
