# Quick Reference Card - Yamet Module

> **Personal Use Module**: Encoding parameters are fixed and optimized for the author's preferences. Review source code to customize.

## Installation

```powershell
# Import the module
Import-Module .\src\Yamet.psd1 -Force

# Check and install prerequisites
Test-YametPrerequisites -Install
```

## Essential Commands

### Check Prerequisites
```powershell
Test-YametPrerequisites                    # Check what's installed
Test-YametPrerequisites -Install           # Install missing tools
Test-YametPrerequisites -Install -Force    # Install without prompts
Test-YametPrerequisites -Verbose           # Show resolved package manager and commands
```

### Validate GPU Support
```powershell
Test-YametCudaSupport                      # Detect NVENC support via ffmpeg
Test-YametCudaSupport -Verbose             # Display encoder list parsing details
```

### Analyze Videos
```powershell
Get-YametVideoInformation -Path 'movie.mkv'                              # All streams
Get-YametVideoInformation -Path 'movie.mkv' -AutoSelectStreams           # Auto-select
Get-YametVideoInformation -Path 'movie.mkv' -AutoSelectStreams -Languages 'eng', 'deu'
```

### Encode Videos
```powershell
# Hardware encoding (NVIDIA GPU)
New-YametEncodingItem -Path 'video.mkv' -OutputPath 'C:\Encoded' -TargetCodec 'h264_nvenc' -AutoSelectStreams

# Software encoding
New-YametEncodingItem -Path 'video.mkv' -OutputPath 'C:\Encoded' -TargetCodec 'x264' -AutoSelectStreams

# Remux (no re-encoding)
New-YametEncodingItem -Path 'video.mkv' -OutputPath 'C:\Encoded' -Remux

# Specific resolution
New-YametEncodingItem -Path 'video.mkv' -OutputPath 'C:\Encoded' -TargetFormat '1080p' -AutoSelectStreams
```

### Metadata
```powershell
# Update metadata
Update-YametVideoTags -Path 'movie.mkv'

# Update and move
Update-YametVideoTags -Path 'episode.mkv' -OutputPath 'C:\Series' -Move

# Use Plex naming
Update-YametVideoTags -Path 'episode.mkv' -OutputPath 'C:\Series' -Move -NamingProfile 'Plex'

# Use metadata scraper (not yet implemented)
# Update-YametVideoTags -Path 'episode.mkv' -MetadataScraper 'TheTVDB' -ScraperApiKey 'your-key'
```

## Common Workflows

### Analyze Before Encoding
```powershell
# Check what streams are available
$info = Get-YametVideoInformation -Path 'movie.mkv'
$info | Where-Object Type -eq 'Audio' | Format-Table Index, LanguageString, Format, Channels

# Encode with specific streams
New-YametEncodingItem -Path 'movie.mkv' -OutputPath 'C:\Encoded' -AudioStreams 1,2 -SubtitleStreams 3
```

### Batch Processing
```powershell
Get-ChildItem '*.mkv' | ForEach-Object {
    New-YametEncodingItem -Path $_.FullName `
        -OutputPath 'C:\Encoded' `
        -TargetCodec 'h264_nvenc' `
        -AutoSelectStreams `
        -Languages 'eng' `
        -Confirm:$false
}
```

### TV Series Processing
```powershell
# Module automatically detects series and organizes output
Get-ChildItem '*S01E*.mkv' | ForEach-Object {
    New-YametEncodingItem -Path $_.FullName `
        -OutputPath 'C:\Series' `
        -AutoSelectStreams `
        -Confirm:$false
}
# Output: C:\Series\ShowName\Season 01\ShowName S01E01.mkv
```

## Codec Reference

| Codec | Type | Best For |
|-------|------|----------|
| `h264_nvenc` | Hardware | Fast encoding with NVIDIA GPU |
| `hevc_nvenc` | Hardware | Fast H.265 with NVIDIA GPU |
| `x264` | Software | High quality H.264, universally compatible |
| `x265` | Software | Best compression, smaller files |

## Resolution Options

- `1080p` - Full HD (1920x1080)
- `720p` - HD (1280x720)
- `none` - Keep original resolution

## Language Codes (ISO 639-2)

- `eng` - English
- `deu` / `ger` - German  
- `jpn` - Japanese
- `fra` - French
- `spa` - Spanish

## Naming Profiles

- `Standard` - "Series - S01 E001.mkv" (default)
- `Plex` / `Emby` / `Jellyfin` - "Series - s01e01.mkv"

## Metadata Scrapers (Not Yet Implemented)

- `Local` - Filename parsing only (default) ✅
- `TheTVDB` - TV show database (API key required) 🚧
- `TMDB` - The Movie Database (API key required) 🚧
- `IMDB` - OMDb API (API key required) 🚧
- `AniDB` - Anime database (API key required) 🚧

## Common Flags

```powershell
-AutoSelectStreams      # Auto-select video/audio/subtitles
-Remux                  # Copy streams without re-encoding
-CopyVideo              # Don't re-encode video
-CopyAudio              # Don't re-encode audio
-InformOnly             # Just show information
-NamingProfile          # Set naming convention (Standard, Plex, etc.)
-MetadataScraper        # Use online metadata source
-Verbose                # Show detailed progress
-WhatIf                 # Preview without executing
-Confirm:$false         # Skip confirmation prompts
```

## Platform-Specific

### Windows
```powershell
New-YametEncodingItem -Path 'C:\Videos\movie.mkv' -OutputPath 'C:\Encoded' -TargetCodec 'h264_nvenc'
```

### Linux
```powershell
New-YametEncodingItem -Path '/videos/movie.mkv' -OutputPath '/encoded' -TargetCodec 'x264'
```

## Getting Help

```powershell
Get-Help New-YametEncodingItem -Full       # Full documentation
Get-Help New-YametEncodingItem -Examples   # Just examples
Get-Help New-YametEncodingItem -Parameter TargetCodec  # Specific parameter
Get-Command -Module Yamet                   # List all commands
```

## Troubleshooting

### Tools Not Found
```powershell
Test-YametPrerequisites -Install -Force
```

### See Detailed Progress
```powershell
New-YametEncodingItem -Path 'movie.mkv' -OutputPath 'C:\Encoded' -Verbose
```

### Test Without Encoding
```powershell
New-YametEncodingItem -Path 'movie.mkv' -OutputPath 'C:\Encoded' -WhatIf
New-YametEncodingItem -Path 'movie.mkv' -OutputPath 'C:\Encoded' -InformOnly
```

### Using API Keys (Not Yet Implemented)
```powershell
# Store in environment variables (for future use)
# $env:TVDB_API_KEY = 'your-api-key'
# $env:TMDB_API_KEY = 'your-api-key'

# Use in commands (not yet implemented)
# Update-YametVideoTags -Path 'episode.mkv' -MetadataScraper 'TheTVDB' -ScraperApiKey $env:TVDB_API_KEY
```

## More Information

- Full Documentation: `docs/`
- Getting Started: `docs/getting-started.md`
- Video Encoding: `docs/video-encoding.md`
- Metadata Scrapers: `docs/metadata-scrapers.md`
- Development Guide: `docs/development.md`

### Hardware Encoding Not Working
```powershell
Test-YametCudaSupport -Verbose             # Inspect detected encoder set
New-YametEncodingItem -TargetCodec 'x264'  # Fall back to software encoding
```

---
**Yamet v0.1.0** - Yet Another Media Encoding Toolkit
