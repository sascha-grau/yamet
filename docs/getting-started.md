# Getting Started with Yamet

## Overview

Yamet (Yet Another Media Encoding Toolkit) is a cross-platform PowerShell module for video encoding, transcoding, and media file management. It provides a PowerShell-friendly interface to ffmpeg, mediainfo, and mkvtoolnix with automatic tool installation, hardware acceleration support, intelligent stream selection, and metadata scraping capabilities.

> **Note**: This module was created for personal use with opinionated encoding parameters. Video and audio settings are optimized with fixed parameters based on target resolution (720p, 1080p). Review the source code to adjust settings for your specific needs.

## Installation

### From Local Source

1. Clone or download the repository
2. Import the module:

```powershell
Import-Module .\src\Yamet.psd1
```

3. Check and install required tools:

```powershell
# Check for required tools (ffmpeg, mediainfo, mkvpropedit)
Test-YametPrerequisites

# Install missing tools automatically
Test-YametPrerequisites -Install

# Install without confirmation prompts (unattended)
Test-YametPrerequisites -Install -Force

# Inspect which package manager/commands will be used
Test-YametPrerequisites -Verbose
```

### From PowerShell Gallery (Future)

```powershell
Install-Module -Name Yamet
```

## Prerequisites

The module requires the following external tools:
- **ffmpeg** - Video encoding and transcoding
- **mediainfo** - Reading video file metadata
- **mkvpropedit** - Editing Matroska file properties

These can be installed automatically using `Test-YametPrerequisites -Install`.

Supported package managers:

- **Windows**: Chocolatey, winget
- **Linux**: apt, dnf/yum, zypper, pacman
- **macOS**: Homebrew

`Test-YametPrerequisites` detects the platform, selects the best available package manager, and respects `-Force` for unattended installs.

## Quick Start

### 1. Check Prerequisites

```powershell
# Check for required tools
Test-YametPrerequisites

# Optional: Set up metadata scraper API keys (not yet implemented)
# $env:TVDB_API_KEY = 'your-thetvdb-api-key'
# $env:TMDB_API_KEY = 'your-tmdb-api-key'

# Install missing tools
Test-YametPrerequisites -Install

# Run unattended (no confirmation prompts)
Test-YametPrerequisites -Install -Force

# See detected commands/package manager
Test-YametPrerequisites -Verbose

# Validate NVENC availability via ffmpeg
Test-YametCudaSupport -Verbose
```

### 2. Analyze Video Files

```powershell
# Get detailed information about a video
Get-YametVideoInformation -Path 'movie.mkv'

# Auto-select streams for specific languages
Get-YametVideoInformation -Path 'movie.mkv' `
    -AutoSelectStreams `
    -Languages 'eng', 'deu'
```

### 3. Encode Videos

```powershell
# Encode with automatic stream selection
New-YametEncodingItem -Path 'video.mkv' `
    -OutputPath 'C:\Encoded' `
    -AutoSelectStreams `
    -Languages 'eng'

# Remux without re-encoding
New-YametEncodingItem -Path 'video.mkv' `
    -OutputPath 'C:\Output' `
    -Remux

# Hardware-accelerated encoding (NVIDIA GPU)
New-YametEncodingItem -Path 'video.mkv' `
    -OutputPath 'C:\Output' `
    -TargetCodec 'h264_nvenc' `
    -TargetFormat '1080p'

# Confirm hardware encoder availability
Test-YametCudaSupport -Verbose
```

### 4. Manage Metadata

```powershell
# Update video metadata tags
Update-YametVideoTags -Path 'movie.mkv'

# Update with Plex naming convention
Update-YametVideoTags -Path 'episode.mkv' `
    -OutputPath 'C:\Series' `
    -Move `
    -NamingProfile 'Plex'

# Use metadata scraper for episode information (not yet implemented)
# Update-YametVideoTags -Path 'episode.mkv' `
#     -MetadataScraper 'TheTVDB' `
#     -ScraperApiKey $env:TVDB_API_KEY
```

## Common Patterns

### Batch Processing

```powershell
# Encode all MKV files in a directory
Get-ChildItem '*.mkv' | ForEach-Object {
    New-YametEncodingItem -Path $_.FullName `
        -OutputPath 'C:\Encoded' `
        -AutoSelectStreams `
        -Confirm:$false
}

# Update metadata for all episodes (metadata scrapers not yet implemented)
Get-ChildItem '*.mkv' | ForEach-Object {
    Update-YametVideoTags -Path $_.FullName `
        -NamingProfile 'Plex' `
        -OutputPath 'C:\Series' `
        -Move
}
```

### Pipeline Operations

```powershell
# Analyze and display stream information for multiple files
Get-ChildItem '*.mkv' | ForEach-Object {
    Get-YametVideoInformation -Path $_.FullName `
        -AutoSelectStreams `
        -Languages 'eng'
} | Format-Table -AutoSize
```

### WhatIf and Confirm

Preview changes before executing:

```powershell
New-YametEncodingItem -Path 'movie.mkv' `
    -OutputPath 'C:\Output' `
    -WhatIf
```

### Verbose Output

Enable verbose output for troubleshooting:

```powershell
Get-YametVideoInformation -Path 'movie.mkv' -Verbose
New-YametEncodingItem -Path 'movie.mkv' -OutputPath 'C:\Output' -Verbose
```

### Cross-Platform Usage

The module works identically on Windows and Linux:

```powershell
# Windows
New-YametEncodingItem -Path 'C:\Videos\movie.mkv' -OutputPath 'C:\Encoded'

# Linux
New-YametEncodingItem -Path '/videos/movie.mkv' -OutputPath '/encoded'
```

## Platform-Specific Notes

### Windows
- Hardware acceleration supported with NVIDIA GPUs (CUDA)
- Tools can be installed via Chocolatey or winget
- Use backslashes `\` or forward slashes `/` in paths

### Linux
- Software encoding recommended (x264/x265)
- Hardware encoding available with NVIDIA GPUs and proper drivers
- Tools installed via apt, dnf, yum, or pacman
- May require sudo for tool installation

### macOS
- Software encoding (x264/x265)
- Tools installed via Homebrew
- Similar to Linux usage patterns

## Next Steps

- Review the [Video Encoding Guide](video-encoding.md) for detailed examples
- Read the [Development Guide](development.md) to contribute
- Check module help: `Get-Help New-YametEncodingItem -Full`
