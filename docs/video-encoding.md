# Video Encoding Guide

## Overview

Yamet provides powerful video encoding capabilities with support for hardware acceleration, automatic stream selection, and cross-platform compatibility.

> **Note**: Encoding parameters are optimized for personal use. Video quality settings (CRF, bitrate) and audio encoding parameters are fixed based on target resolution. These settings balance quality and file size according to the author's preferences and may need adjustment for your use case.

## Prerequisites

Before using the video encoding features, ensure required tools are installed:

```powershell
# Check for required tools
Test-YametPrerequisites

# Install missing tools
Test-YametPrerequisites -Install
```

## Hardware Acceleration

### Windows with NVIDIA GPU

The module supports CUDA hardware acceleration for NVIDIA GPUs:

```powershell
# H.264 hardware encoding
New-YametEncodingItem -Path 'video.mkv' -OutputPath 'C:\Output' `
    -TargetCodec 'h264_nvenc' -AutoSelectStreams

# H.265 hardware encoding
New-YametEncodingItem -Path 'video.mkv' -OutputPath 'C:\Output' `
    -TargetCodec 'hevc_nvenc' -AutoSelectStreams

# Verify NVENC availability on this machine
Test-YametCudaSupport -Verbose
```

### Linux and Software Encoding

For systems without NVIDIA GPUs or on Linux, use software encoding:

```powershell
# H.264 software encoding
New-YametEncodingItem -Path 'video.mkv' -OutputPath '/output' `
    -TargetCodec 'x264' -AutoSelectStreams

# H.265 software encoding
New-YametEncodingItem -Path 'video.mkv' -OutputPath '/output' `
    -TargetCodec 'x265' -AutoSelectStreams
```

## Analyzing Video Files

### Intelligent Subtitle Selection

When analyzing video files with `-AutoSelectStreams`, Yamet intelligently handles multiple subtitle tracks:

```powershell
# Automatically selects best subtitle tracks
Get-YametVideoInformation -Path 'movie.mkv' -AutoSelectStreams -Languages 'eng', 'deu'
```

**Selection Logic:**
- **Single track**: Included as-is without modification
- **Multiple tracks with forced flag**: Respects container metadata
- **Multiple tracks without forced flag**: Uses size heuristic
  - Smallest file = Forced subtitles (foreign language parts only)
  - Largest file = Full subtitles (complete dialogue)

### Basic Information

```powershell
# Display all tracks and streams
Get-YametVideoInformation -Path 'movie.mkv'

# Auto-select streams for specific languages
Get-YametVideoInformation -Path 'movie.mkv' `
    -AutoSelectStreams `
    -Languages 'eng', 'deu'

# Check before remuxing (includes high-quality audio)
Get-YametVideoInformation -Path 'movie.mkv' `
    -AutoSelectStreams `
    -Languages 'eng' `
    -Remux
```

### Pipeline Processing

```powershell
# Analyze multiple files
Get-ChildItem *.mkv | ForEach-Object {
    Get-YametVideoInformation -Path $_.FullName
}
```

## Encoding Scenarios

### 1. Simple Transcode to 1080p

```powershell
New-YametEncodingItem -Path 'video.mkv' `
    -OutputPath 'C:\Encoded' `
    -TargetFormat '1080p' `
    -TargetCodec 'h264_nvenc' `
    -AutoSelectStreams `
    -Languages 'eng'
```

### 2. Remux (No Re-encoding)

When you want to change container or remove streams without re-encoding:

```powershell
New-YametEncodingItem -Path 'video.mkv' `
    -OutputPath 'C:\Output' `
    -Remux `
    -AutoSelectStreams `
    -Languages 'eng', 'deu'
```

### 3. Custom Stream Selection

Manually specify which streams to include:

```powershell
# First, get stream information
$streams = Get-YametVideoInformation -Path 'movie.mkv'
$streams | Format-Table Type, Index, LanguageString, Format, Channels

# Then encode with specific streams
New-YametEncodingItem -Path 'movie.mkv' `
    -OutputPath 'C:\Output' `
    -AudioStreams 1, 3 `
    -SubtitleStreams 5, 6 `
    -ForcedSubtitleStreams 5
```

### 4. TV Series with Auto-Naming

The module automatically detects and formats TV series:

```powershell
# Input: "Show Name - S01E05 - Episode Title.mkv"
New-YametEncodingItem -Path 'Show Name - S01E05 - Episode Title.mkv' `
    -OutputPath 'C:\Series' `
    -AutoSelectStreams `
    -Languages 'eng'

# Output: C:\Series\Show Name\Season 01\Show Name S01E05.mkv
```

### 5. Batch Processing

```powershell
# Process all MKV files in a directory
Get-ChildItem '*.mkv' | ForEach-Object {
    New-YametEncodingItem -Path $_.FullName `
        -OutputPath 'C:\Encoded' `
        -TargetCodec 'h264_nvenc' `
        -TargetFormat '1080p' `
        -AutoSelectStreams `
        -Languages 'eng' `
        -Confirm:$false
}
```

### 6. Quality Presets

#### High Quality (Larger File Size)
```powershell
New-YametEncodingItem -Path 'video.mkv' `
    -OutputPath 'C:\Output' `
    -TargetCodec 'x265' `
    -TargetFormat '1080p' `
    -CopyAudio  # Keep original audio quality
```

#### Balanced (Medium Size)
```powershell
New-YametEncodingItem -Path 'video.mkv' `
    -OutputPath 'C:\Output' `
    -TargetCodec 'h264_nvenc' `
    -TargetFormat '1080p' `
    -AutoSelectStreams
```

#### Space Saver (Smaller Size)
```powershell
New-YametEncodingItem -Path 'video.mkv' `
    -OutputPath 'C:\Output' `
    -TargetCodec 'x265' `
    -TargetFormat '720p' `
    -AutoSelectStreams
```

## Metadata Management

### Updating Video Tags

```powershell
# Update metadata in place
Update-YametVideoTags -Path 'movie.mkv'

# Update and copy to new location
Update-YametVideoTags -Path 'movie.mkv' `
    -OutputPath 'C:\Library' `
    -Copy

# Update and move (organizes series automatically)
Update-YametVideoTags -Path 'Show - S01E01.mkv' `
    -OutputPath 'C:\Series' `
    -Move

# Update with Plex naming convention
Update-YametVideoTags -Path 'Show - S01E01.mkv' `
    -OutputPath 'C:\Series' `
    -Move `
    -NamingProfile 'Plex'

# Use metadata scraper (not yet implemented)
# Update-YametVideoTags -Path 'Show - S01E01.mkv' `
#     -MetadataScraper 'TheTVDB' `
#     -ScraperApiKey $env:TVDB_API_KEY `
#     -NamingProfile 'Standard'
```

### Naming Profiles

Yamet supports multiple naming conventions:

```powershell
# Standard: "Series - S01 E001.mkv" in "Season 01" folder
Update-YametVideoTags -Path 'episode.mkv' -NamingProfile 'Standard'

# Plex/Emby/Jellyfin: "Series - s01e01.mkv" in "Season 01" folder
Update-YametVideoTags -Path 'episode.mkv' -NamingProfile 'Plex'
```

### Forced Subtitles

Forced subtitles are automatically handled during encoding when using `-AutoSelectStreams`.
The module intelligently detects forced subtitles based on:
- Container metadata (forced flag)
- File size heuristics (smallest subtitle track)

```powershell
# Forced subtitles are automatically selected
New-YametEncodingItem -Path 'movie.mkv' `
    -OutputPath 'C:\Encoded' `
    -AutoSelectStreams `
    -Languages 'eng'
```

## Advanced Examples

### Complete Workflow: Download, Analyze, Encode, Tag

```powershell
$videoPath = 'C:\Downloads\movie.mkv'
$outputPath = 'C:\Library\Movies'

# 1. Analyze the video
Write-Host "Analyzing video..." -ForegroundColor Cyan
$info = Get-YametVideoInformation -Path $videoPath -AutoSelectStreams -Languages 'eng', 'jpn'
$info | Format-Table -AutoSize

# 2. Encode with selected streams
Write-Host "Encoding video..." -ForegroundColor Cyan
New-YametEncodingItem -Path $videoPath `
    -OutputPath $outputPath `
    -TargetCodec 'h264_nvenc' `
    -TargetFormat '1080p' `
    -AutoSelectStreams `
    -Languages 'eng', 'jpn' `
    -Confirm:$false

# 3. Update metadata
Write-Host "Updating metadata..." -ForegroundColor Cyan
$encodedFile = Get-ChildItem "$outputPath\*.mkv" | Select-Object -First 1
Update-YametVideoTags -Path $encodedFile.FullName

# Note: Metadata scrapers not yet implemented
# Future: Use -MetadataScraper 'TMDB' -ScraperApiKey $env:TMDB_API_KEY

Write-Host "Complete!" -ForegroundColor Green
```

### Processing with Error Handling

```powershell
$videos = Get-ChildItem '*.mkv'

foreach ($video in $videos) {
    try {
        Write-Host "Processing: $($video.Name)" -ForegroundColor Yellow
        
        New-YametEncodingItem -Path $video.FullName `
            -OutputPath 'C:\Encoded' `
            -TargetCodec 'h264_nvenc' `
            -AutoSelectStreams `
            -Confirm:$false `
            -ErrorAction Stop
        
        Write-Host "✓ Success: $($video.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed: $($video.Name)" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

## Codec Reference

| Codec | Type | Platform | Use Case |
|-------|------|----------|----------|
| `h264_nvenc` | Hardware | Windows/Linux (NVIDIA) | Fast H.264 encoding with GPU |
| `hevc_nvenc` | Hardware | Windows/Linux (NVIDIA) | Fast H.265 encoding with GPU |
| `x264` | Software | All | High-quality H.264, slower but compatible |
| `x265` | Software | All | High-quality H.265, best compression |

**Note**: Quality parameters (CRF values, bitrate ranges, presets) are fixed in the module and optimized for the author's media library.

## Target Formats

- `1080p` - Full HD (1920x1080)
- `720p` - HD (1280x720)
- `none` - Keep original resolution

## Container Formats

- `mkv` - Matroska (recommended, supports all features)
- `mp4` - MPEG-4 (wide compatibility, limited subtitle support)

## Language Codes

- `eng` - English
- `deu` / `ger` - German
- `jpn` - Japanese

Use ISO 639-2 three-letter codes for other languages.

## Performance Tips

1. **Use Hardware Encoding**: `h264_nvenc` or `hevc_nvenc` for NVIDIA GPUs (10-20x faster)
2. **Remux When Possible**: Use `-Remux` if you only need to change container or streams
3. **Batch Processing**: Process multiple files in parallel using PowerShell jobs
4. **Target Format**: Downscaling to 720p significantly reduces encoding time
5. **Audio Copying**: Use `-CopyAudio` when audio quality is already good

## Troubleshooting

### Tools Not Found

```powershell
# Check prerequisites
Test-YametPrerequisites

# Install missing tools
Test-YametPrerequisites -Install -Force
```

### Hardware Encoding Not Working

```powershell
# Verify ffmpeg exposes NVENC encoders
Test-YametCudaSupport -Verbose

# Fall back to software encoding
New-YametEncodingItem -Path 'video.mkv' `
    -OutputPath 'C:\Output' `
    -TargetCodec 'x264'  # Use software codec
```

### Permission Errors

Run PowerShell as Administrator (Windows) or use sudo for package installation (Linux).

## See Also

- [Getting Started Guide](getting-started.md)
- [Metadata Scrapers Guide](metadata-scrapers.md)
- [Development Guide](development.md)
- ffmpeg documentation: https://ffmpeg.org/documentation.html
- mediainfo documentation: https://mediaarea.net/en/MediaInfo

