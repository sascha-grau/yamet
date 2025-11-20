# Metadata Scraper System

> **⚠️ NOTICE**: Online metadata scrapers (TheTVDB, TMDB, IMDB, AniDB) are not yet implemented. The framework is in place, but API integrations are planned for future releases. Currently, only the 'Local' scraper (filename parsing) is functional.

## Overview

The Yamet module includes an extensible framework for multiple metadata scrapers to retrieve episode and movie information from various sources.

Until the online integrations ship, Yamet always falls back to the Local scraper. Calling `Update-YametVideoTags` with any unimplemented scraper emits a warning and continues with filename-based metadata so workflows remain unblocked.

## Available Scrapers

### 1. Local (Default)
- **Description**: Extracts metadata from filename only
- **API Key**: Not required
- **Status**: ✅ Fully implemented
- **Use Case**: Quick operations without external dependencies

```powershell
Update-YametVideoTags -Path 'episode.mkv' -MetadataScraper 'Local'
```

### 2. TheTVDB
- **Description**: Comprehensive TV show database
- **API Key**: Required (free registration)
- **Status**: 🚧 Framework ready, implementation pending
- **Website**: https://thetvdb.com/api-information
- **Use Case**: TV series metadata with episode titles and descriptions

```powershell
Update-YametVideoTags -Path 'episode.mkv' -MetadataScraper 'TheTVDB' -ScraperApiKey 'your-api-key'
```

### 3. TMDB (The Movie Database)
- **Description**: Movies and TV shows database
- **API Key**: Required (free registration)
- **Status**: 🚧 Framework ready, implementation pending
- **Website**: https://www.themoviedb.org/settings/api
- **Use Case**: Movies and TV series with extensive metadata

```powershell
Update-YametVideoTags -Path 'movie.mkv' -MetadataScraper 'TMDB' -ScraperApiKey 'your-api-key'
```

### 4. IMDB
- **Description**: Internet Movie Database
- **API Key**: Requires OMDb API key (IMDB has no official API)
- **Status**: 🚧 Framework ready, implementation pending
- **Website**: http://www.omdbapi.com/apikey.aspx
- **Use Case**: Popular movies and TV shows

```powershell
Update-YametVideoTags -Path 'movie.mkv' -MetadataScraper 'IMDB' -ScraperApiKey 'omdb-api-key'
```

### 5. AniDB
- **Description**: Anime database
- **API Key**: Required (registration needed)
- **Status**: 🚧 Framework ready, implementation pending
- **Website**: https://anidb.net/perl-bin/animedb.pl?show=client
- **Use Case**: Anime series with proper episode titles

```powershell
Update-YametVideoTags -Path 'anime.mkv' -MetadataScraper 'AniDB' -ScraperApiKey 'your-api-key'
```

## Architecture

### Files
- **`Get-YametMetadata.ps1`** (Private): Core scraper function
- **`Update-YametVideoTags.ps1`** (Public): Main function with scraper integration

### Metadata Structure

The scraper returns a hashtable with the following properties:

```powershell
@{
    Title = 'Episode Title'
    Series = 'Series Name'
    Season = 1
    Episode = 1
    Description = 'Episode description'
    Year = 2025
    Source = 'TheTVDB'
}
```

## Implementing a New Scraper

To implement one of the pending scrapers, edit `src/Private/Get-YametMetadata.ps1`:

1. Add HTTP API calls using `Invoke-RestMethod` or `Invoke-WebRequest`
2. Parse the JSON/XML response
3. Map the response to the metadata structure
4. Handle errors gracefully (fallback to local metadata)

### Example Implementation Structure

```powershell
'TheTVDB' {
    try {
        # 1. Search for series
        $searchUrl = "https://api4.thetvdb.com/v4/search?query=$($SeriesInfo.Series)"
        $headers = @{ Authorization = "Bearer $ApiKey" }
        $searchResult = Invoke-RestMethod -Uri $searchUrl -Headers $headers
        
        # 2. Get episode details
        $seriesId = $searchResult.data[0].tvdb_id
        $episodeUrl = "https://api4.thetvdb.com/v4/series/$seriesId/episodes/default"
        $episodes = Invoke-RestMethod -Uri $episodeUrl -Headers $headers
        
        # 3. Find matching episode
        $episode = $episodes.data | Where-Object {
            $_.seasonNumber -eq $SeriesInfo.Season -and
            $_.number -eq $SeriesInfo.Episode
        } | Select-Object -First 1
        
        # 4. Return metadata
        return @{
            Title = $episode.name
            Series = $SeriesInfo.Series
            Season = $SeriesInfo.Season
            Episode = $SeriesInfo.Episode
            Description = $episode.overview
            Year = ($episode.aired -split '-')[0]
            Source = 'TheTVDB'
        }
    }
    catch {
        Write-Warning "TheTVDB API error: $_. Falling back to local metadata."
        # Return local metadata as fallback
    }
}
```

## Usage Patterns

### Basic Usage (Local only)
```powershell
Update-YametVideoTags -Path 'episode.mkv'
```

### With Online Scraper
```powershell
Update-YametVideoTags -Path 'episode.mkv' `
    -MetadataScraper 'TheTVDB' `
    -ScraperApiKey 'your-api-key' `
    -OutputPath 'C:\Videos' `
    -Move
```

### Batch Processing with Scraper
```powershell
$apiKey = 'your-api-key'
Get-ChildItem '*.mkv' | ForEach-Object {
    Update-YametVideoTags -Path $_.FullName `
        -MetadataScraper 'TMDB' `
        -ScraperApiKey $apiKey `
        -Confirm:$false
}
```

### Using Environment Variables for API Keys
```powershell
# Set once per session
$env:TVDB_API_KEY = 'your-api-key'

# Use in commands
Update-YametVideoTags -Path 'episode.mkv' `
    -MetadataScraper 'TheTVDB' `
    -ScraperApiKey $env:TVDB_API_KEY
```

## Fallback Behavior

- If an online scraper is specified but no API key is provided, the function automatically falls back to the 'Local' scraper
- If an API call fails, the scraper returns local metadata with a warning
- This ensures the function always completes successfully

## Future Enhancements

1. **Caching**: Cache API responses to reduce API calls
2. **Rate Limiting**: Implement rate limiting for API requests
3. **Fuzzy Matching**: Improve series name matching
4. **Bulk Operations**: Optimize for batch processing
5. **Custom Scrapers**: Allow users to define custom scraper plugins
6. **Configuration File**: Store API keys in a config file

## Contributing

To contribute a scraper implementation:

1. Edit `src/Private/Get-YametMetadata.ps1`
2. Implement the API integration for your chosen scraper
3. Test thoroughly with various series/movies
4. Submit a pull request with examples

## API Key Security

⚠️ **Important**: Never commit API keys to version control

- Use environment variables
- Use secure credential storage (Windows Credential Manager, etc.)
- Consider using PowerShell SecureString for sensitive data
