function Add-YametAudioEncodingParams {
    <#
    .SYNOPSIS
        Adds audio encoding parameters to ffmpeg command.

    .DESCRIPTION
        Internal helper function that appends audio stream parameters
        to the ffmpeg parameter array.

    .PARAMETER FFmpegParams
        Reference to the ffmpeg parameters array.

    .PARAMETER MkvPropParams
        Reference to the mkvpropedit parameters array.

    .PARAMETER StreamInfo
        Array of stream information objects.

    .PARAMETER AudioStreams
        Array of audio stream indices to include.

    .PARAMETER Remux
        Whether to remux (copy) audio without re-encoding.

    .PARAMETER CopyAudio
        Whether to copy audio streams without re-encoding.
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
        [int[]]$AudioStreams,

        [Parameter()]
        [switch]$Remux,

        [Parameter()]
        [switch]$CopyAudio
    )

    $audioIndex = 0
    $defaultAudioAssigned = $false
    foreach ($audioStreamIndex in $AudioStreams) {
        $audioStream = $StreamInfo | Where-Object { $_.Type -eq 'Audio' -and $_.Index -eq $audioStreamIndex } | Select-Object -First 1

        if (-not $audioStream) {
            continue
        }

        # Map audio stream
        $FFmpegParams.Value += '-map', "0:$($audioStream.Index)"
        $FFmpegParams.Value += "-metadata:s:a:$audioIndex", "language=$($audioStream.LanguageIsoCode)"

        $isDefaultAudio = -not $defaultAudioAssigned
        if ($isDefaultAudio) {
            $defaultAudioAssigned = $true
        }

        $audioDisposition = if ($isDefaultAudio) { 'default' } else { '0' }
        $FFmpegParams.Value += "-disposition:a:$audioIndex", $audioDisposition

        # MKV properties
        $MkvPropParams.Value += '--edit', "track:a$($audioIndex + 1)", '--set', 'flag-forced=0'
        $defaultFlagValue = [Convert]::ToInt32($isDefaultAudio)
        $MkvPropParams.Value += '--edit', "track:a$($audioIndex + 1)", '--set', "flag-default=$defaultFlagValue"

        $channelLabel = switch ($audioStream.Channels) {
            '1' { 'Mono' }
            '2' { 'Stereo' }
            '6' { '5.1' }
            '8' { '7.1' }
            default { $null }
        }

        $outputCodecLabel = if ($Remux -or $CopyAudio) { $audioStream.Format } else { 'AAC' }

        # Encoding or copying
        if ($Remux -or $CopyAudio) {
            $FFmpegParams.Value += "-c:a:$audioIndex", 'copy'
        } else {
            $FFmpegParams.Value += "-c:a:$audioIndex", 'aac', "-b:a:$audioIndex", '192k'

            if ($audioStream.Format) {
                $FFmpegParams.Value += "-metadata:s:a:$audioIndex", "comment=Source codec: $($audioStream.Format)"
            }
        }

        $titleParts = @('Audio', $outputCodecLabel)
        if ($channelLabel) {
            $titleParts += $channelLabel
        }
        $audioTitle = ($titleParts -join ' - ')

        $FFmpegParams.Value += "-metadata:s:a:$audioIndex", "title=$audioTitle"
        $audioIndex++
    }
}
