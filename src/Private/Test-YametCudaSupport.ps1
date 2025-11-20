function Test-YametCudaSupport {
    <#
    .SYNOPSIS
        Tests if CUDA/NVENC hardware encoding is available.

    .DESCRIPTION
        Internal helper function that checks if ffmpeg has CUDA/NVENC support
        and if an NVIDIA GPU is available.

    .OUTPUTS
        Boolean indicating whether CUDA encoding is available.
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        # Check if ffmpeg exists
        if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
            Write-Verbose "ffmpeg not found in PATH"
            return $false
        }

        # Check if ffmpeg has NVENC encoders
        $ffmpegEncoders = & ffmpeg -hide_banner -encoders 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Unable to enumerate ffmpeg encoders (exit code $LASTEXITCODE)"
            return $false
        }

        $nvencEncoders = $ffmpegEncoders -match 'h264_nvenc|hevc_nvenc'
        if (-not $nvencEncoders -or $nvencEncoders.Count -eq 0) {
            Write-Verbose "ffmpeg does not have NVENC encoder support"
            return $false
        }

        # Attempt to collect GPU information via nvidia-smi (optional)
        try {
            if (Get-Command nvidia-smi -ErrorAction Stop) {
                $nvidiaGpu = & nvidia-smi --query-gpu=name --format=csv,noheader 2>$null | Select-Object -First 1
                if ($LASTEXITCODE -eq 0 -and $nvidiaGpu) {
                    Write-Verbose "CUDA/NVENC support available with GPU: $nvidiaGpu"
                } else {
                    Write-Verbose "nvidia-smi returned a non-zero exit code while querying the GPU"
                }
            }
        }
        catch {
            Write-Verbose "nvidia-smi not available: $_"
        }

        return $true
    }
    catch {
        Write-Verbose "Error checking CUDA support: $_"
        return $false
    }
}
