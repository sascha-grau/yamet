$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\Yamet.psd1'
Import-Module $modulePath -Force

function script:New-TestMkvpropeditStub {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter()]
        [int]$ExitCode = 0
    )

    $toolPath = Join-Path $RootPath ([guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $toolPath -Force | Out-Null
    $logPath = Join-Path $toolPath 'mkvpropedit.log'
    if ($IsWindows) {
        $cmdContent = @"
    @echo off
    echo mkvpropedit called >> "$logPath"
    echo %* >> "$logPath"
    exit /b $ExitCode
"@
        Set-Content -Path (Join-Path $toolPath 'mkvpropedit.cmd') -Value $cmdContent -Encoding ASCII
    } else {
        $scriptPath = Join-Path $toolPath 'mkvpropedit'
        $scriptContent = @"
    #!/bin/sh
    echo mkvpropedit called >> "$logPath"
    echo "$@" >> "$logPath"
    exit $ExitCode
"@
        Set-Content -Path $scriptPath -Value $scriptContent -Encoding Ascii
        try {
            if (Get-Command chmod -ErrorAction SilentlyContinue) {
                & chmod +x $scriptPath
            } else {
                Set-ItemProperty -Path $scriptPath -Name UnixMode -Value 755 -ErrorAction SilentlyContinue
            }
        } catch {
            # Best effort; tests will fail if script is not executable
        }
    }

    $previousPath = $env:PATH
    $pathSeparator = [System.IO.Path]::PathSeparator
    $env:PATH = "$toolPath$pathSeparator$previousPath"

    return [pscustomobject]@{
        PreviousPath = $previousPath
        LogPath      = $logPath
    }
}

function script:Remove-TestMkvpropeditStub {
    param(
        [Parameter(Mandatory = $true)]
        $Stub
    )

    if ($Stub.PreviousPath) {
        $env:PATH = $Stub.PreviousPath
    }
}

Describe 'Yamet Module' {
    It 'exports the current public cmdlets' {
        $module = Get-Module -Name 'Yamet'
        $expectedFunctions = @(
            'Get-YametVideoInformation',
            'New-YametEncodingItem',
            'Test-YametPrerequisites',
            'Update-YametVideoTags'
        )

        foreach ($function in $expectedFunctions) {
            $module.ExportedFunctions.Keys | Should -Contain $function
        }
    }
}

Describe 'Get-YametVideoInformation' {
    InModuleScope Yamet {
        It 'auto-selects fallback streams when language metadata is missing' {
            $inputPath = Join-Path $TestDrive 'NoLanguage.mkv'
            Set-Content -Path $inputPath -Value 'placeholder'

            Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith { $true }

            $mediainfoJson = @{
                media = @{
                    track = @(
                        @{ '@type' = 'General' },
                        @{ '@type' = 'Video'; '@typeorder' = '1'; Width = '1920'; Height = '1080'; FrameRate = '24'; CodecID = 'V_MPEG4/ISO/AVC' },
                        @{ '@type' = 'Audio'; '@typeorder' = '2'; Channels = '6'; BitRate = 512000; Format = 'EAC3' },
                        @{ '@type' = 'Text'; '@typeorder' = '3'; Format = 'SRT'; ElementCount = 100; SizeMB = 1 }
                    )
                }
            } | ConvertTo-Json -Depth 4

            Mock -CommandName mediainfo -ModuleName Yamet -MockWith {
                param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
                $global:LASTEXITCODE = 0
                $mediainfoJson
            }

            $result = Get-YametVideoInformation -Path $inputPath -AutoSelectStreams -Languages 'eng'

            $audio = $result | Where-Object { $_.Type -eq 'Audio' }
            $audio | Should -HaveCount 1
            $audio.LanguageIsoCode | Should -BeNullOrEmpty

            $subtitle = $result | Where-Object { $_.Type -eq 'Text' }
            $subtitle | Should -HaveCount 1
        }

        It 'handles non-numeric bitrate fields gracefully' {
            $inputPath = Join-Path $TestDrive 'NonNumeric.mkv'
            Set-Content -Path $inputPath -Value 'placeholder'

            Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith { $true }

            $mediainfoJson = @{
                media = @{
                    track = @(
                        @{ '@type' = 'Video'; '@typeorder' = '1'; BitRate = 'N/A'; StreamSize = ''; CodecID = 'V_MPEG4/ISO/AVC'; Width = '1920'; Height = '1080' },
                        @{ '@type' = 'Text'; '@typeorder' = '2'; BitRate = 'unknown'; StreamSize = 'n/a'; Format = 'SRT'; ElementCount = 10; Language_String = 'English'; Language_String3 = 'eng' }
                    )
                }
            } | ConvertTo-Json -Depth 4

            Mock -CommandName mediainfo -ModuleName Yamet -MockWith {
                param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
                $global:LASTEXITCODE = 0
                $mediainfoJson
            }

            $result = Get-YametVideoInformation -Path $inputPath
            $textTrack = $result | Where-Object { $_.Type -eq 'Text' } | Select-Object -First 1
            $textTrack.BitrateKB | Should -BeNullOrEmpty
            $textTrack.SizeMB | Should -BeNullOrEmpty
        }
    }
}

Describe 'New-YametEncodingItem' {
    InModuleScope Yamet {
        It 'copies primary audio and subtitle streams by default' {
            $script:capturedAudio = $null
            $script:capturedSubtitles = $null
            $script:capturedForced = $null

            $inputPath = Join-Path $TestDrive 'Sample Series - S01E01.mkv'
            Set-Content -Path $inputPath -Value 'placeholder'
            $outputPath = Join-Path $TestDrive 'Output'

            Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith { $true }
            Mock -CommandName Get-YametVideoInformation -ModuleName Yamet -MockWith {
                @(
                    [PSCustomObject]@{
                        Type      = 'Video'
                        Index     = 0
                        TypeOrder = 1
                        CodecId   = 'V_MPEG4/ISO/AVC'
                        Fps       = 24
                        Height    = 2160
                        ScanType  = 'Progressive'
                    },
                    [PSCustomObject]@{
                        Type             = 'Audio'
                        Index            = 1
                        TypeOrder        = 1
                        LanguageIsoCode  = 'eng'
                        LanguageString   = 'English'
                        Format           = 'DTS'
                        Channels         = 6
                    },
                    [PSCustomObject]@{
                        Type             = 'Audio'
                        Index            = 2
                        TypeOrder        = 2
                        LanguageIsoCode  = 'deu'
                        LanguageString   = 'German'
                        Format           = 'AC3'
                        Channels         = 2
                    },
                    [PSCustomObject]@{
                        Type             = 'Text'
                        Index            = 3
                        TypeOrder        = 1
                        LanguageIsoCode  = 'eng'
                        LanguageString   = 'English'
                        Forced           = 'No'
                        Format           = 'SRT'
                    },
                    [PSCustomObject]@{
                        Type             = 'Text'
                        Index            = 4
                        TypeOrder        = 2
                        LanguageIsoCode  = 'eng'
                        LanguageString   = 'English'
                        Forced           = 'Yes'
                        Format           = 'SRT'
                    }
                )
            }
            Mock -CommandName Get-YametOutputPath -ModuleName Yamet -MockWith {
                param($BasePath, $FileName, $TargetContainer)
                return @{
                    OutputDirectory = $BasePath
                    OutputFileName  = "$FileName.$TargetContainer"
                    Title           = 'Sample Title'
                }
            }
            Mock -CommandName Get-YametVideoEncodingParams -ModuleName Yamet -MockWith {
                return @{
                    FFmpegParams  = @('-i', 'dummy.mkv')
                    MkvPropParams = @('--dummy')
                }
            }
            Mock -CommandName Add-YametAudioEncodingParams -ModuleName Yamet -MockWith {
                param([ref]$FFmpegParams, [ref]$MkvPropParams, $StreamInfo, $AudioStreams, [switch]$Remux, [switch]$CopyAudio)
                $script:capturedAudio = @($AudioStreams)
            }
            Mock -CommandName Add-YametSubtitleEncodingParams -ModuleName Yamet -MockWith {
                param([ref]$FFmpegParams, [ref]$MkvPropParams, $StreamInfo, $SubtitleStreams, $ForcedSubtitleStreams)
                $script:capturedSubtitles = @($SubtitleStreams)
                $script:capturedForced = @($ForcedSubtitleStreams)
            }
            Mock -CommandName Get-YametVideoFilter -ModuleName Yamet -MockWith { $null }
            Mock -CommandName Get-YametHDRParams -ModuleName Yamet -MockWith { $null }

            $fileInfo = [System.IO.FileInfo]$inputPath
            New-YametEncodingItem -Path $fileInfo -OutputPath $outputPath -WhatIf

            $script:capturedAudio | Should -Be @(1)
            $script:capturedSubtitles | Should -Be @(4)
            $script:capturedForced | Should -Be @(4)
        }

        It 'selects primary streams even when language metadata is missing' {
            $script:capturedAudio = $null
            $script:capturedSubtitles = $null

            $inputPath = Join-Path $TestDrive 'Metadata Missing.mkv'
            Set-Content -Path $inputPath -Value 'placeholder'
            $outputPath = Join-Path $TestDrive 'Output'

            Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith { $true }
            Mock -CommandName Get-YametVideoInformation -ModuleName Yamet -MockWith {
                @(
                    [PSCustomObject]@{
                        Type      = 'Video'
                        Index     = 0
                        TypeOrder = 1
                        CodecId   = 'V_MPEG4/ISO/AVC'
                        Fps       = 24
                        Height    = 1080
                    },
                    [PSCustomObject]@{
                        Type            = 'Audio'
                        Index           = 1
                        TypeOrder       = 1
                        LanguageIsoCode = $null
                        LanguageString  = $null
                        Format          = 'EAC3'
                        Channels        = 6
                    },
                    [PSCustomObject]@{
                        Type           = 'Text'
                        Index          = 2
                        TypeOrder      = 1
                        LanguageString = $null
                        LanguageIsoCode = $null
                        Forced         = 'No'
                        Format         = 'SRT'
                    }
                )
            }
            Mock -CommandName Get-YametOutputPath -ModuleName Yamet -MockWith {
                param($BasePath, $FileName, $TargetContainer)
                @{ OutputDirectory = $BasePath; OutputFileName = "$FileName.$TargetContainer"; Title = 'Untitled' }
            }
            Mock -CommandName Get-YametVideoEncodingParams -ModuleName Yamet -MockWith {
                @{ FFmpegParams = @('-i','dummy.mkv'); MkvPropParams = @('--dummy') }
            }
            Mock -CommandName Add-YametAudioEncodingParams -ModuleName Yamet -MockWith {
                param([ref]$FFmpegParams, [ref]$MkvPropParams, $StreamInfo, $AudioStreams)
                $script:capturedAudio = @($AudioStreams)
            }
            Mock -CommandName Add-YametSubtitleEncodingParams -ModuleName Yamet -MockWith {
                param([ref]$FFmpegParams, [ref]$MkvPropParams, $StreamInfo, $SubtitleStreams)
                $script:capturedSubtitles = @($SubtitleStreams)
            }
            Mock -CommandName Get-YametVideoFilter -ModuleName Yamet -MockWith { $null }
            Mock -CommandName Get-YametHDRParams -ModuleName Yamet -MockWith { $null }

            New-YametEncodingItem -Path ([System.IO.FileInfo]$inputPath) -OutputPath $outputPath -WhatIf

            $script:capturedAudio | Should -Be @(1)
            $script:capturedSubtitles | Should -Be @(2)
        }
    }
}

Describe 'Update-YametVideoTags' {
    InModuleScope Yamet {
        It 'rejects non-mkv inputs during validation' {
            $tmpFile = Join-Path $TestDrive 'sample.mp4'
            Set-Content -Path $tmpFile -Value 'placeholder'

            { Update-YametVideoTags -Path ([System.IO.FileInfo]$tmpFile) } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Update-YametVideoTags'
        }

        It 'moves a series file into profile folders and applies metadata edits' {
            $inputPath = Join-Path $TestDrive 'Series Name - S01E02 - Episode Title.mkv'
            Set-Content -Path $inputPath -Value 'placeholder'
            $destinationRoot = Join-Path $TestDrive 'Library'
            $stub = New-TestMkvpropeditStub -RootPath $TestDrive

            try {
                Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith { $true }
                Mock -CommandName Get-YametVideoInformation -ModuleName Yamet -MockWith {
                    @(
                        [PSCustomObject]@{ Type = 'General'; Index = 0; Attachments = $null },
                        [PSCustomObject]@{ Type = 'Video'; Index = 1; TypeOrder = 1; CodecId = 'V_MPEG4/ISO/AVC' },
                        [PSCustomObject]@{ Type = 'Audio'; Index = 2; TypeOrder = 1; Format = 'DTS'; Channels = 6; LanguageString = 'English'; LanguageIsoCode = 'eng' },
                        [PSCustomObject]@{ Type = 'Text'; Index = 3; TypeOrder = 1; LanguageString = 'English'; LanguageIsoCode = 'eng'; Forced = 'Yes' }
                    )
                }
                Mock -CommandName Get-YametMetadata -ModuleName Yamet -MockWith {
                    param($SeriesInfo, $Scraper, $ApiKey)
                    @{ Title = 'Episode Title'; Source = 'Local' }
                }

                Update-YametVideoTags -Path ([System.IO.FileInfo]$inputPath) -OutputPath $destinationRoot -Move -Verbose:$false

                $seriesDir = Join-Path $destinationRoot 'Series Name'
                $seasonDir = Join-Path $seriesDir 'Season 01'
                Test-Path $seasonDir | Should -BeTrue
                $movedFile = Join-Path $seasonDir 'Series Name S01E002.mkv'
                Test-Path $movedFile | Should -BeTrue
                Test-Path $stub.LogPath | Should -BeTrue
            }
            finally {
                Remove-TestMkvpropeditStub -Stub $stub
            }
        }

        It 'copies a series file when Copy is specified' {
            $inputPath = Join-Path $TestDrive 'Series Name - S01E03 - Another Episode.mkv'
            Set-Content -Path $inputPath -Value 'placeholder'
            $destinationRoot = Join-Path $TestDrive 'Library'
            $stub = New-TestMkvpropeditStub -RootPath $TestDrive

            try {
                Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith { $true }
                Mock -CommandName Get-YametVideoInformation -ModuleName Yamet -MockWith {
                    param($Path)
                    @(
                        [PSCustomObject]@{ Type = 'General'; Index = 0 },
                        [PSCustomObject]@{ Type = 'Video'; Index = 1; TypeOrder = 1; CodecId = 'V_MPEG4/ISO/AVC' },
                        [PSCustomObject]@{ Type = 'Audio'; Index = 2; TypeOrder = 1; Format = 'AAC'; Channels = 2; LanguageString = 'English'; LanguageIsoCode = 'eng' },
                        [PSCustomObject]@{ Type = 'Text'; Index = 3; TypeOrder = 1; LanguageString = 'English'; LanguageIsoCode = 'eng'; Forced = 'No' }
                    )
                }
                Mock -CommandName Get-YametMetadata -ModuleName Yamet -MockWith {
                    param($SeriesInfo, $Scraper, $ApiKey)
                    @{ Title = 'Another Episode'; Source = 'Local' }
                }

                Update-YametVideoTags -Path ([System.IO.FileInfo]$inputPath) -OutputPath $destinationRoot -Copy -NamingProfile 'Plex'

                $seriesDir = Join-Path $destinationRoot 'Series Name'
                $seasonDir = Join-Path $seriesDir 'Season 01'
                Test-Path $seasonDir | Should -BeTrue
                $copiedFile = Join-Path $seasonDir 'Series Name - s01e03.mkv'
                Test-Path $copiedFile | Should -BeTrue
                Test-Path $inputPath | Should -BeTrue
                (Get-Content $stub.LogPath | Out-String) | Should -Match 'mkvpropedit called'
            }
            finally {
                Remove-TestMkvpropeditStub -Stub $stub
            }
        }

        It 'uses scraper metadata when filename lacks episode title' {
            $inputPath = Join-Path $TestDrive 'Series Name - S01E04.mkv'
            Set-Content -Path $inputPath -Value 'placeholder'
            $destinationRoot = Join-Path $TestDrive 'Library'
            $stub = New-TestMkvpropeditStub -RootPath $TestDrive

            try {
                Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith { $true }
                Mock -CommandName Get-YametVideoInformation -ModuleName Yamet -MockWith { param($Path) @() }
                Mock -CommandName Get-YametMetadata -ModuleName Yamet -MockWith {
                    param($SeriesInfo, $Scraper, $ApiKey)
                    @{ Title = 'Injected Title'; Source = 'Local' }
                }

                Update-YametVideoTags -Path ([System.IO.FileInfo]$inputPath) -OutputPath $destinationRoot -Move -NamingProfile 'Plex'

                $seriesDir = Join-Path $destinationRoot 'Series Name'
                $seasonDir = Join-Path $seriesDir 'Season 01'
                Test-Path $seasonDir | Should -BeTrue
                $movedFile = Join-Path $seasonDir 'Series Name - s01e04.mkv'
                Test-Path $movedFile | Should -BeTrue
                (Get-Content $stub.LogPath | Out-String) | Should -Match 'Injected Title'
            }
            finally {
                Remove-TestMkvpropeditStub -Stub $stub
            }
        }

        It 'requires OutputPath when Copy is specified' {
            $inputPath = Join-Path $TestDrive 'Series Name - S01E06.mkv'
            Set-Content -Path $inputPath -Value 'placeholder'

            { Update-YametVideoTags -Path ([System.IO.FileInfo]$inputPath) -Copy } |
                Should -Throw -ErrorId '-OutputPath is required when using -Copy or -Move'
        }

        It 'honors Emby naming profile for copies' {
            $inputPath = Join-Path $TestDrive 'Series Name - S01E05 - Bonus Feature.mkv'
            Set-Content -Path $inputPath -Value 'placeholder'
            $destinationRoot = Join-Path $TestDrive 'EmbyLibrary'
            $stub = New-TestMkvpropeditStub -RootPath $TestDrive

            try {
                Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith { $true }
                Mock -CommandName Get-YametVideoInformation -ModuleName Yamet -MockWith {
                    param($Path)
                    @([PSCustomObject]@{ Type = 'Video'; Index = 1; TypeOrder = 1; CodecId = 'V_MPEG4/ISO/AVC' })
                }
                Mock -CommandName Get-YametMetadata -ModuleName Yamet -MockWith {
                    param($SeriesInfo, $Scraper, $ApiKey)
                    $SeriesInfo
                }

                Update-YametVideoTags -Path ([System.IO.FileInfo]$inputPath) -OutputPath $destinationRoot -Copy -NamingProfile 'Emby'

                $seasonDir = Join-Path (Join-Path $destinationRoot 'Series Name') 'Season 01'
                Test-Path $seasonDir | Should -BeTrue
                $expectedFile = Join-Path $seasonDir 'Series Name - s01e05.mkv'
                Test-Path $expectedFile | Should -BeTrue
                (Get-Content $stub.LogPath | Out-String) | Should -Match 'Bonus Feature'
            }
            finally {
                Remove-TestMkvpropeditStub -Stub $stub
            }
        }

        It 'throws descriptive error when mkvpropedit fails' {
            $inputPath = Join-Path $TestDrive 'Failure Test - S01E07.mkv'
            Set-Content -Path $inputPath -Value 'placeholder'
            $stub = New-TestMkvpropeditStub -RootPath $TestDrive -ExitCode 5

            try {
                Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith { $true }
                Mock -CommandName Get-YametVideoInformation -ModuleName Yamet -MockWith {
                    @([PSCustomObject]@{ Type = 'Video'; Index = 0; TypeOrder = 1; CodecId = 'V_MPEG4/ISO/AVC' })
                }

                { Update-YametVideoTags -Path ([System.IO.FileInfo]$inputPath) } |
                    Should -Throw -ErrorId 'MkvPropEditFailed,Update-YametVideoTags'
            }
            finally {
                Remove-TestMkvpropeditStub -Stub $stub
            }
        }
    }
}

Describe 'Test-YametPrerequisites' {
    InModuleScope Yamet {
        It 'reports installed tools without installation' {
            Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith { $true }
            Mock -CommandName Install-YametPrerequisite -ModuleName Yamet -MockWith { $true }
            Mock -CommandName Test-YametCudaSupport -ModuleName Yamet -MockWith { $true }

            $result = Test-YametPrerequisites | Where-Object { $_.Tool }
            $result | Should -HaveCount 3
            ($result | Where-Object { -not $_.Installed }).Count | Should -Be 0
            Assert-MockCalled Install-YametPrerequisite -ModuleName Yamet -Times 0
        }

        It 'installs missing tools when requested' {
            Mock -CommandName Test-YametPrerequisite -ModuleName Yamet -MockWith {
                param([string]$ToolName)
                return $ToolName -ne 'mediainfo'
            }
            Mock -CommandName Install-YametPrerequisite -ModuleName Yamet -MockWith {
                param([string]$ToolName)
                if ($ToolName -eq 'mediainfo') { return $true }
                return $false
            }
            Mock -CommandName Test-YametCudaSupport -ModuleName Yamet -MockWith { $false }

            $result = Test-YametPrerequisites -Install -Force | Where-Object { $_.Tool }

            $mediainfo = $result | Where-Object { $_.Tool -eq 'mediainfo' }
            $mediainfo.Installed | Should -BeTrue
            $mediainfo.Action | Should -Be 'Installed'
            Assert-MockCalled Install-YametPrerequisite -ModuleName Yamet -Times 1 -ParameterFilter { $ToolName -eq 'mediainfo' }
        }
    }
}

Describe 'Private helper functions' {
    InModuleScope Yamet {
        It 'builds audio parameters per stream' {
            $ffmpegParams = @()
            $mkvParams = @()
            $streamInfo = @(
                [PSCustomObject]@{ Type = 'Audio'; Index = 5; TypeOrder = 1; LanguageIsoCode = 'eng'; Format = 'EAC3'; Channels = 6 },
                [PSCustomObject]@{ Type = 'Audio'; Index = 6; TypeOrder = 2; LanguageIsoCode = 'deu'; Format = 'AAC'; Channels = 2 }
            )

            Add-YametAudioEncodingParams -FFmpegParams ([ref]$ffmpegParams) -MkvPropParams ([ref]$mkvParams) -StreamInfo $streamInfo -AudioStreams @(5, 6)

            $getValue = {
                param($array, $flag)
                $position = [Array]::IndexOf($array, $flag)
                if ($position -ge 0 -and $position + 1 -lt $array.Count) {
                    return $array[$position + 1]
                }
                return $null
            }

            & $getValue $ffmpegParams '-disposition:a:0' | Should -Be 'default'
            & $getValue $ffmpegParams '-disposition:a:1' | Should -Be '0'
            & $getValue $ffmpegParams '-b:a:0' | Should -Be '192k'
            & $getValue $ffmpegParams '-b:a:1' | Should -Be '192k'
            ($ffmpegParams -match '-map').Count | Should -Be 2

            $mkvParams | Should -Contain '--set'
            ($mkvParams | Where-Object { $_ -eq 'flag-default=1' }).Count | Should -Be 1
            ($mkvParams | Where-Object { $_ -eq 'flag-default=0' }).Count | Should -BeGreaterThan 0
        }

        It 'marks forced and default subtitles correctly' {
            $ffmpegParams = @()
            $mkvParams = @()
            $streamInfo = @(
                [PSCustomObject]@{ Type = 'Text'; Index = 3; TypeOrder = 1; LanguageIsoCode = 'eng'; LanguageString = 'English'; CodecId = 'srt'; Forced = 'Yes' },
                [PSCustomObject]@{ Type = 'Text'; Index = 4; TypeOrder = 2; LanguageIsoCode = 'deu'; LanguageString = 'German'; CodecId = 'srt'; Forced = 'No' }
            )

            Add-YametSubtitleEncodingParams -FFmpegParams ([ref]$ffmpegParams) -MkvPropParams ([ref]$mkvParams) -StreamInfo $streamInfo -SubtitleStreams @(3, 4) -ForcedSubtitleStreams @(3)

            $ffmpegParams | Should -Contain '-c:s:0'
            $ffmpegParams | Should -Contain '-c:s:1'
            $ffmpegParams | Should -Contain '-disposition:s:0'
            $ffmpegParams | Should -Contain '-disposition:s:1'
            $forcedDisposition = $ffmpegParams[([Array]::IndexOf($ffmpegParams, '-disposition:s:0') + 1)]
            $defaultDisposition = $ffmpegParams[([Array]::IndexOf($ffmpegParams, '-disposition:s:1') + 1)]
            $forcedDisposition | Should -Be 'forced'
            $defaultDisposition | Should -Be 'default'

            $mkvParams | Should -Contain 'flag-forced=1'
            $mkvParams | Should -Contain 'flag-default=0'
            $mkvParams | Should -Contain 'flag-default=1'
        }

        It 'builds video encoding parameters with filters' {
            Mock -CommandName Get-YametVideoFilter -ModuleName Yamet -MockWith { 'scale=w=-1:h=1080' }
            Mock -CommandName Get-YametHDRParams -ModuleName Yamet -MockWith { 'hdr-opt=1' }

            $videoStream = [PSCustomObject]@{
                Type = 'Video'
                Index = 0
                CodecId = 'V_MPEG4/ISO/AVC'
                Fps = '24'
                Height = '2160'
                ScanType = 'Progressive'
            }

            $result = Get-YametVideoEncodingParams -VideoStream $videoStream -InputPath 'input.mkv' -Title 'Sample Title' -TargetCodec 'x265' -TargetFormat '1080p'

            $result.FFmpegParams | Should -Contain '-map'
            $result.FFmpegParams | Should -Contain '0:0'
            $result.FFmpegParams | Should -Contain '-metadata'
            $result.FFmpegParams | Should -Contain 'title=Sample Title'
            $result.FFmpegParams | Should -Contain '-vf'
            $result.FFmpegParams | Should -Contain 'scale=w=-1:h=1080'
            $result.FFmpegParams | Should -Contain '-x265-params'
            $result.FFmpegParams | Should -Contain 'hdr-opt=1'
            $result.MkvPropParams | Should -Contain '--edit'
            $result.MkvPropParams | Should -Contain 'track:v1'
        }
    }
}

Describe 'Encoding helper functions' {
    InModuleScope Yamet {
        It 'generates distinct ffmpeg and mkv flags per audio stream' {
            $ffmpeg = @()
            $mkv = @()
            $streamInfo = @(
                [PSCustomObject]@{ Type = 'Audio'; Index = 1; TypeOrder = 1; LanguageIsoCode = 'eng'; Format = 'DTS'; Channels = 6 },
                [PSCustomObject]@{ Type = 'Audio'; Index = 2; TypeOrder = 2; LanguageIsoCode = 'deu'; Format = 'AC3'; Channels = 2 }
            )

            Add-YametAudioEncodingParams -FFmpegParams ([ref]$ffmpeg) -MkvPropParams ([ref]$mkv) -StreamInfo $streamInfo -AudioStreams @(1, 2)

            function Get-FlagValue {
                param($array, $flag)
                $index = [Array]::IndexOf($array, $flag)
                if ($index -lt 0 -or $index -ge ($array.Count - 1)) { return $null }
                return $array[$index + 1]
            }

            (Get-FlagValue $ffmpeg '-disposition:a:0') | Should -Be 'default'
            (Get-FlagValue $ffmpeg '-disposition:a:1') | Should -Be '0'
            (Get-FlagValue $ffmpeg '-b:a:0') | Should -Be '192k'
            (Get-FlagValue $ffmpeg '-b:a:1') | Should -Be '192k'
            $mkv | Should -Contain 'flag-default=1'
            $mkv | Should -Contain 'flag-default=0'
        }

        It 'applies forced and default subtitle dispositions correctly' {
            $ffmpeg = @()
            $mkv = @()
            $streamInfo = @(
                [PSCustomObject]@{ Type = 'Text'; Index = 3; TypeOrder = 1; LanguageString = 'English'; LanguageIsoCode = 'eng'; Forced = 'Yes'; CodecId = 'S_TEXT/UTF8' },
                [PSCustomObject]@{ Type = 'Text'; Index = 4; TypeOrder = 2; LanguageString = 'German'; LanguageIsoCode = 'deu'; Forced = 'No'; CodecId = 'S_TEXT/UTF8' }
            )

            Add-YametSubtitleEncodingParams -FFmpegParams ([ref]$ffmpeg) -MkvPropParams ([ref]$mkv) -StreamInfo $streamInfo -SubtitleStreams @(3, 4) -ForcedSubtitleStreams @(3)

            function Get-FlagValue {
                param($array, $flag)
                $index = [Array]::IndexOf($array, $flag)
                if ($index -lt 0 -or $index -ge ($array.Count - 1)) { return $null }
                return $array[$index + 1]
            }

            (Get-FlagValue $ffmpeg '-disposition:s:0') | Should -Be 'forced'
            (Get-FlagValue $ffmpeg '-disposition:s:1') | Should -Be 'default'
            ($ffmpeg | Where-Object { $_ -eq 'title=Subtitles - German' }) | Should -Not -BeNullOrEmpty
            $mkv | Should -Contain 'flag-forced=1'
            $mkv | Should -Contain 'flag-default=1'
        }

        It 'builds video encoding parameters for scaling scenarios' {
            $videoStream = [PSCustomObject]@{
                Type      = 'Video'
                Index     = 0
                TypeOrder = 1
                CodecId   = 'V_MPEG4/ISO/AVC'
                Fps       = '24'
                Height    = '2160'
                ScanType  = 'Progressive'
            }

            $result = Get-YametVideoEncodingParams -VideoStream $videoStream -InputPath 'input.mkv' -Title 'Sample Title' -TargetCodec 'x265' -TargetFormat '1080p'

            $result.FFmpegParams | Should -Contain '-vf'
            $result.FFmpegParams | Should -Contain '-c:v'
            $result.FFmpegParams | Should -Contain 'libx265'
            $result.MkvPropParams | Should -Contain 'flag-default=0'

            $copyResult = Get-YametVideoEncodingParams -VideoStream $videoStream -InputPath 'input.mkv' -Title 'Sample Title' -TargetCodec 'x264' -TargetFormat 'none' -Remux

            $copyResult.FFmpegParams | Should -Contain 'copy'
            $copyResult.FFmpegParams | Should -Not -Contain '-vf'
        }
    }
}

AfterAll {
    Remove-Module -Name 'Yamet' -Force -ErrorAction SilentlyContinue
}
