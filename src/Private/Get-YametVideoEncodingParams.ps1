function Get-YametVideoEncodingParams {
    <#
    .SYNOPSIS
        Builds ffmpeg parameters for video encoding.

    .DESCRIPTION
        Internal helper function that constructs video encoding parameters
        for ffmpeg based on codec, format, and stream information.

    .PARAMETER VideoStream
        The video stream object from Get-YametVideoInformation.

    .PARAMETER InputPath
        The input file path.

    .PARAMETER Title
        The video title for metadata.

    .PARAMETER TargetCodec
        The target video codec (x264, x265, h264_nvenc, hevc_nvenc).

    .PARAMETER TargetFormat
        The target resolution (720p, 1080p, none).

    .PARAMETER Remux
        Whether to remux without re-encoding.

    .PARAMETER CopyVideo
        Whether to copy the video stream without re-encoding.

    .OUTPUTS
        Hashtable with FFmpegParams (array) and MkvPropParams (array).
    #>

    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VideoStream,

        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [ValidateSet('x264', 'x265', 'h264_nvenc', 'hevc_nvenc')]
        [string]$TargetCodec,

        [Parameter(Mandatory = $true)]
        [ValidateSet('720p', '1080p', 'none')]
        [string]$TargetFormat,

        [Parameter()]
        [switch]$Remux,

        [Parameter()]
        [switch]$CopyVideo
    )

    $params = @()
    $mkvPropParams = @()

    # Determine video format name
    $videoFormat = switch ($VideoStream.CodecId) {
        'V_MPEG2' { 'MPEG2' }
        { $_ -in @('V_MPEG4/ISO/AVC', 'AVC', 'AVC1', '27') } { 'H264' }
        'V_MS/VFW/FOURCC / WVC1' { 'VC1' }
        'V_MPEGH/ISO/HEVC' { 'H265' }
        default { 'H264' }
    }

    # Hardware acceleration setup
    if ($TargetCodec -match 'nvenc') {
        $params += '-hwaccel_output_format', 'cuda'

        $hwaccelParams = switch ($VideoStream.CodecId) {
            'V_MPEG2' { @('-hwaccel_device', '0', '-hwaccel', 'cuvid', '-vcodec', 'mpeg2_cuvid') }
            'V_MPEG4/ISO/AVC' { @('-hwaccel_device', '0', '-hwaccel', 'cuvid', '-vcodec', 'h264_cuvid') }
            { $_ -in @('AVC', 'AVC1', '27') } { @('-hwaccel_device', '0', '-hwaccel', 'cuvid', '-vcodec', 'h264_cuvid') }
            'V_MS/VFW/FOURCC / WVC1' { @('-hwaccel_device', '0', '-hwaccel', 'cuvid', '-vcodec', 'vc1_cuvid') }
            default { @() }
        }
        $params += $hwaccelParams
    }

    # Input and mapping
    $params += '-i', $InputPath
    $params += '-map_metadata', '-1'
    $params += '-analyzeduration', '1000'
    $params += '-map', "0:$($VideoStream.Index)"
    $params += '-metadata', "title=$Title"
    $params += '-metadata:s:v', "title=Video - $videoFormat"

    # MKV properties
    $mkvPropParams += '--edit', 'track:v1', '--set', 'flag-forced=0'
    $mkvPropParams += '--edit', 'track:v1', '--set', 'flag-default=0'

    # Video encoding/copying
    if ($Remux -or $CopyVideo) {
        $params += '-c:v', 'copy'
    } else {
        # Base encoding parameters
        $params += '-preset:v', 'slow'

        $fpsValue = 0
        $numberStyle = [System.Globalization.NumberStyles]::Float
        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        if ($VideoStream.Fps -and [double]::TryParse($VideoStream.Fps, $numberStyle, $culture, [ref]$fpsValue) -and $fpsValue -gt 0) {
            $gop = [math]::Round($fpsValue * 10)
        } else {
            $gop = 240
        }
        $params += '-g', $gop.ToString()

        # Codec-specific parameters
        $codecParams = switch ($TargetCodec) {
            'h264_nvenc' { @('-c:v', 'h264_nvenc', '-rc', 'vbr', '-rc-lookahead', '32', '-qmin:v', '20', '-qmax:v', '26', '-b:v', '0', '-profile:v', 'main', '-bf', '3', '-refs', '3') }
            'hevc_nvenc' { @('-c:v', 'hevc_nvenc', '-rc', 'vbr', '-rc-lookahead', '32', '-cq', '24', '-qmin:v', '20', '-qmax:v', '26', '-b:v', '0') }
            'x264' { @('-c:v', 'libx264', '-crf', '23', '-preset', 'slow', '-profile:v', 'main') }
            'x265' { @('-c:v', 'libx265', '-crf', '24', '-preset', 'slow') }
        }
        $params += $codecParams

        # Deinterlacing metadata
        if ($VideoStream.ScanType -eq 'interlaced') {
            $mkvPropParams += '--edit', 'track:v1', '--delete', 'interlaced'
            $mkvPropParams += '--edit', 'track:v1', '--delete', 'field-order'
        }

        # Scaling and deinterlacing filters
        $filterComplex = Get-YametVideoFilter -VideoStream $VideoStream -TargetFormat $TargetFormat -TargetCodec $TargetCodec
        if ($filterComplex) {
            $params += '-vf', $filterComplex
        }

        # HDR/UHD settings
        $hdrParams = Get-YametHDRParams -VideoStream $VideoStream
        if ($hdrParams -and $TargetCodec -eq 'x265') {
            $params += '-x265-params', $hdrParams
        }
    }

    return @{
        FFmpegParams  = $params
        MkvPropParams = $mkvPropParams
        VideoFormat   = $videoFormat
    }
}
