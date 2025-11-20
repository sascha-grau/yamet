# Yamet - Yet Another Media Encoding Toolkit

A cross-platform PowerShell module for video encoding, transcoding, and media file management. Built following Microsoft's PowerShell cmdlet development best practices with support for Windows and Linux.

> **Note**: This module was created for personal use and includes opinionated encoding parameters. Video and audio encoding settings are optimized with fixed parameters based on target resolution (720p, 1080p) to balance quality and file size according to the author's preferences.

## Features

- ✅ **Cross-Platform Support**: Works on Windows, Linux, and macOS from a single module
- ✅ **Video Encoding**: Hardware-accelerated ffmpeg pipelines with CUDA/NVENC when available
- ✅ **Media Intelligence**: Detailed video/audio/subtitle stream analysis with mediainfo
- ✅ **Stream Automation**: Auto-detects forced/full subtitles plus preferred audio languages
- ✅ **MKV Management**: Edit Matroska file properties and metadata with mkvpropedit
- ✅ **Automatic Tool Installation**: Detects and installs ffmpeg, mediainfo, and mkvtoolnix via your package manager
- ✅ **Series Detection**: Automatically handles TV series naming conventions and folder layouts
- ✅ **Multiple Naming Profiles**: Standard, Plex, Emby, and Jellyfin naming conventions
- 🚧 **Metadata Scrapers**: Framework for TheTVDB, TMDB, IMDB, and AniDB integration (not yet implemented)
- ✅ **PowerShell Best Practices**: CmdletBinding, pipeline support, error handling, and ShouldProcess coverage
- ✅ **Comment-Based Help**: Complete documentation for each cmdlet
- ✅ **Pester Tests**: Automated regression tests ship with the module

## Installation

### From Local Source

```powershell
Import-Module .\src\Yamet.psd1
```

## Prerequisites

The module requires the following external tools:
- **ffmpeg** - For video encoding and transcoding
- **mediainfo** - For reading video file metadata  
- **mkvpropedit** (part of mkvtoolnix) - For editing MKV file properties

### Automatic Installation

The module can automatically install these tools for you:

```powershell
# Check for required tools
Test-YametPrerequisites

# Install missing tools automatically
Test-YametPrerequisites -Install

# Install without confirmation prompts
Test-YametPrerequisites -Install -Force
```

**Supported Package Managers:**
- **Windows**: Chocolatey, winget
- **Linux**: apt (Debian/Ubuntu), dnf/yum (Fedora, RHEL, CentOS), zypper (openSUSE), pacman (Arch)
- **macOS**: Homebrew

`Test-YametPrerequisites` automatically detects the host platform, selects the best available package manager, and supports unattended installs when `-Force` is supplied.

## Quick Start

### Video Information

```powershell
# Get detailed information about a video file
Get-YametVideoInformation -Path 'movie.mkv'

# Auto-select streams for specific languages
Get-YametVideoInformation -Path 'movie.mkv' -AutoSelectStreams -Languages 'eng', 'deu'
```

### Video Encoding

```powershell
# Encode with automatic stream selection
New-YametEncodingItem -Path 'movie.mkv' -OutputPath 'C:\Encoded' -AutoSelectStreams -Languages 'eng'

# Remux without re-encoding
New-YametEncodingItem -Path 'video.mkv' -OutputPath 'C:\Output' -Remux

# Custom encoding with H.265
New-YametEncodingItem -Path 'video.mkv' -OutputPath 'C:\Output' -TargetCodec 'x265' -TargetFormat '1080p'

# Hardware-accelerated encoding (NVIDIA GPU)
New-YametEncodingItem -Path 'video.mkv' -OutputPath 'C:\Output' -TargetCodec 'h264_nvenc' -AutoSelectStreams

# Validate NVENC availability on current system
Test-YametCudaSupport -Verbose
```

### Metadata Management

```powershell
# Update video file metadata tags
Update-YametVideoTags -Path 'movie.mkv'

# Update tags and move to organized directory structure
Update-YametVideoTags -Path 'episode.mkv' -OutputPath 'C:\Series' -Move

# Use Plex naming convention
Update-YametVideoTags -Path 'episode.mkv' -OutputPath 'C:\Series' -Move -NamingProfile 'Plex'

# Use metadata scraper for episode information (not yet implemented)
# Update-YametVideoTags -Path 'episode.mkv' -MetadataScraper 'TheTVDB' -ScraperApiKey 'your-api-key'
```

## Available Cmdlets

- `Test-YametPrerequisites` - Check and install required tools
- `Get-YametVideoInformation` - Retrieve detailed video/audio/subtitle stream information
- `New-YametEncodingItem` - Encode/transcode video files with hardware acceleration
- `Update-YametVideoTags` - Update metadata tags in video files

## Documentation

- [Getting Started Guide](docs/getting-started.md) - Quick start and basic usage
- [Video Encoding Guide](docs/video-encoding.md) - Comprehensive encoding examples and workflows
- [Metadata Scrapers Guide](docs/metadata-scrapers.md) - Framework for online metadata sources (not yet implemented)
- [Development Guide](docs/development.md) - Contributing to the project

## Project Structure

```
yamet/
├── src/              # Module source code
│   ├── Public/       # Exported functions
│   └── Private/      # Internal helper functions
├── tests/            # Pester tests
├── build/            # Build scripts
├── docs/             # Documentation
└── .vscode/          # VS Code configuration
```

## Examples

### Complete Workflow

```powershell
# 1. Check prerequisites
Test-YametPrerequisites -Install

# 2. Analyze video
Get-YametVideoInformation -Path 'movie.mkv' -AutoSelectStreams -Languages 'eng'

# 3. Encode with hardware acceleration
New-YametEncodingItem -Path 'movie.mkv' `
    -OutputPath 'C:\Encoded' `
    -TargetCodec 'h264_nvenc' `
    -TargetFormat '1080p' `
    -AutoSelectStreams `
    -Languages 'eng'

# 4. Update metadata
Update-YametVideoTags -Path (Get-ChildItem 'C:\Encoded\*.mkv').FullName
```

### Batch Processing

```powershell
Get-ChildItem '*.mkv' | ForEach-Object {
    New-YametEncodingItem -Path $_.FullName `
        -OutputPath 'C:\Encoded' `
        -AutoSelectStreams `
        -Languages 'eng', 'deu' `
        -Confirm:$false
}
```

## Troubleshooting

- **Tools Not Found**

  ```powershell
  Test-YametPrerequisites -Install -Force
  ```

- **GPU/NVENC Availability Unknown**

  ```powershell
  Test-YametCudaSupport -Verbose
  ```

- **Need Detailed Progress**

  ```powershell
  New-YametEncodingItem -Path 'movie.mkv' -OutputPath 'C:\Encoded' -Verbose
  ```

- **Dry Run Without Encoding**

  ```powershell
  New-YametEncodingItem -Path 'movie.mkv' -OutputPath 'C:\Encoded' -WhatIf
  New-YametEncodingItem -Path 'movie.mkv' -OutputPath 'C:\Encoded' -InformOnly
  ```

## Platform Support

| Platform | Hardware Acceleration | Package Manager | Status |
|----------|----------------------|-----------------|--------|
| Windows | ✅ NVIDIA CUDA (NVENC) | Chocolatey, winget | Fully Supported |
| Linux | ✅ NVIDIA CUDA (NVENC) when GPU present | apt, dnf/yum, zypper, pacman | Fully Supported |
| macOS | ❌ Software only | Homebrew | Supported |

## Development

### Prerequisites

- PowerShell 5.1 or PowerShell 7+
- Pester 5.0+ (for testing)
- External tools: ffmpeg, mediainfo, mkvpropedit

### Building

```powershell
# Build the module
.\build\build.ps1 -Task Build

# Run tests
.\build\build.ps1 -Task Test

# Build and test
.\build\build.ps1 -Task All
```

### VS Code Tasks

- **Build Module** (Ctrl+Shift+B): Builds the module
- **Test Module**: Runs all Pester tests
- **Import Module (Development)**: Imports module for testing

## Contributing

Contributions are welcome! Please ensure:

1. All tests pass
2. New features include tests
3. Code follows PowerShell best practices
4. Documentation is updated

## License

This PowerShell module is licensed under the MIT License - see below for details.

```
MIT License

Copyright (c) 2025 Sascha Grau

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Third-Party Tool Licenses

This module requires the following external tools, each with their own licenses:

- **ffmpeg** - Licensed under GNU Lesser General Public License (LGPL) version 2.1 or later
  - https://ffmpeg.org/legal.html
  - Note: Some builds may use GPL-licensed components

- **mediainfo** - Licensed under BSD-2-Clause License
  - https://mediaarea.net/en/MediaInfo/License

- **mkvtoolnix** (mkvpropedit) - Licensed under GNU General Public License (GPL) version 2
  - https://mkvtoolnix.download/license.html

Please review each tool's license before using this module in your project.

## About

This module was developed by Sascha Grau for personal media library management. The encoding parameters are specifically tuned for a home media server environment and may not suit all use cases. Users are encouraged to review and adjust the encoding settings in the source code to match their specific requirements.

## Author

**Sascha Grau**

## Contributors

Contributions are welcome! See our [Contributing](#contributing) section above.

## Acknowledgments

This project relies on the excellent work of:
- [FFmpeg team](https://ffmpeg.org)
- [MediaInfo](https://mediaarea.net/en/MediaInfo)
- [MKVToolNix](https://mkvtoolnix.download)
