function Get-YametVideoFilter {
    <#
    .SYNOPSIS
        Builds video filter string for ffmpeg.

    .DESCRIPTION
        Internal helper function that constructs the video filter string
        for scaling and deinterlacing operations.

    .PARAMETER VideoStream
        The video stream object.

    .PARAMETER TargetFormat
        The target resolution (720p, 1080p, none).

    .PARAMETER TargetCodec
        The target codec (determines hardware vs software filters).

    .OUTPUTS
        String containing the filter complex, or $null if no filtering needed.
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VideoStream,

        [Parameter(Mandatory = $true)]
        [ValidateSet('720p', '1080p', 'none')]
        [string]$TargetFormat,

        [Parameter(Mandatory = $true)]
        [string]$TargetCodec
    )

    $currentHeight = if ($VideoStream.Height) { [int]$VideoStream.Height } else { 0 }

    $targetHeight = switch ($TargetFormat) {
        '1080p' { 1080 }
        '720p' { 720 }
        'none' { $currentHeight }
    }

    $requiresScaling = $TargetFormat -ne 'none' -and $currentHeight -ne 0 -and $currentHeight -ne $targetHeight

    $scanType = if ($VideoStream.ScanType) { $VideoStream.ScanType.ToString().ToLowerInvariant() } else { $null }
    $requiresDeinterlace = $scanType -eq 'interlaced'

    if (-not $requiresScaling -and -not $requiresDeinterlace) {
        return $null
    }

    $filters = @()

    if ($TargetCodec -match 'nvenc') {
        # Hardware filters
        if ($requiresScaling -or $requiresDeinterlace) {
            $filters += 'format=nv12'
            $filters += 'hwupload_cuda'
        }

        if ($requiresDeinterlace) {
            $filters += 'yadif_cuda=0:-1:1'
        }

        if ($requiresScaling) {
            $filters += "scale_npp=w=-1:h=$($targetHeight):format=nv12:interp_algo=lanczos"
        }
    } else {
        # Software filters
        if ($requiresDeinterlace) {
            $filters += 'yadif=0:-1:1'
        }

        if ($requiresScaling) {
            $filters += "scale=w=-1:h=$($targetHeight):flags=lanczos"
        }
    }

    if ($filters.Count -eq 0) {
        return $null
    }

    return ($filters -join ',')
}
