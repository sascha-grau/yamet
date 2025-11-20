function Get-YametHDRParams {
    <#
    .SYNOPSIS
        Builds HDR encoding parameters for x265.

    .DESCRIPTION
        Internal helper function that constructs x265 HDR parameters
        based on video stream color information.

    .PARAMETER VideoStream
        The video stream object with HDR information.

    .OUTPUTS
        String containing x265 parameters, or $null if not HDR content.
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VideoStream
    )

    $hdrProfile = $VideoStream.HDRProfile
    $hdrFormat = $VideoStream.HDRFormat

    if (-not $hdrProfile -and -not $hdrFormat) {
        return $null
    }

    $x265Params = @('hdr-opt=1', 'repeat-headers=1')

    # Color matrix
    if ($VideoStream.ColorMatrix -eq 'BT.2020 non-constant') {
        $x265Params += 'colormatrix=bt2020nc'
    }

    # Color primaries
    if ($VideoStream.ColorPrim -eq 'BT.2020') {
        $x265Params += 'colorprim=bt2020'
    }

    # Transfer characteristics
    if ($VideoStream.ColorTransfer -in @('SMPTE ST 2086', 'SMPTE ST 2094 App 4', 'PQ')) {
        $x265Params += 'transfer=smpte2084'
    }

    if ($x265Params.Count -gt 0) {
        return ($x265Params -join ':')
    }

    return $null
}
