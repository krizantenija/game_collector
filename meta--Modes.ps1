<#
.SYNOPSIS
    Checks for game URLs in .url files and fetches metadata from GOG or IGDB APIs with different modes.
.DESCRIPTION
    This script searches through a specified folder and its subfolders for internet shortcut files (.url).
    Offers three modes: Recreate all, Skip existing, or Delete all metadata files.
.PARAMETER RootPath
    The root directory to search for .url files. Defaults to "D:\gamm".
#>

param (
    [string]$RootPath = "G:\"
)

# Display mode selection menu
function Show-ModeMenu {
    Clear-Host
    Write-Host "============================================="
    Write-Host " Game Metadata Scraper - Select Operation Mode"
    Write-Host "============================================="
    Write-Host "1. Re-create all meta files (overwrite existing)"
    Write-Host "2. Just create missing meta files"
    Write-Host "3. Delete all meta.txt files"
    Write-Host "4. Exit"
    Write-Host "============================================="
    
    while ($true) {
        $selection = Read-Host "Please select an operation mode (1-4)"
        switch ($selection) {
            '1' { return 'recreate' }
            '2' { return 'skip' }
            '3' { return 'delete' }
            '4' { exit }
            default { Write-Host "Invalid selection. Please enter 1, 2, 3 or 4." }
        }
    }
}

# IGDB API credentials
$clientID = "y9nq42pa1pri6bnte9b34yi7zbcyp0"
$clientSecret = "6ita170rrn9qr5lr01ry7vwyh15lqj"
$igdbAccessToken = $null

# Function to authenticate with IGDB API and get access token
function Get-IGDBAccessToken {
    param (
        [string]$clientID,
        [string]$clientSecret
    )
    
    $authUrl = "https://id.twitch.tv/oauth2/token"
    $body = @{
        client_id = $clientID
        client_secret = $clientSecret
        grant_type = "client_credentials"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $authUrl -Method Post -Body $body
        return $response.access_token
    }
    catch {
        Write-Warning "Failed to authenticate with IGDB API: $_"
        return $null
    }
}

# Function to extract game identifier from URL
function Get-GameIdentifierFromURL {
    param ([string]$url)
    
    if ($url -imatch "gogdb") {
        $pattern = "\d+"
        if ($url -match $pattern) {
            return @{ Type = "GOG"; ID = $matches[0] }
        }
    }
    elseif ($url -imatch "igdb\.com/games/") {
        return @{ Type = "IGDB"; URL = $url }
    }
    
    return $null
}

# Function to fetch and process metadata from GOG API
function Get-GOGMetadata {
    param (
        [string]$gameID,
        [string]$sourceUrl
    )
    
    $apiUrl = "https://api.gog.com/v2/games/$gameID"
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get
        
        # Handle video
        $videoValue = $null
        if ($null -ne $response._embedded.videos.videoId) {
            if ($response._embedded.videos.videoId -is [array]) {
                if ($response._embedded.videos.videoId.Count -gt 0) {
                    $videoValue = $response._embedded.videos.videoId[0]
                }
            }
            else {
                $videoValue = $response._embedded.videos.videoId
            }
        }

        # Convert release date to YYYY format
        $yearValue = $null
        if ($response._embedded.product.globalReleaseDate) {
            try {
                $yearValue = [datetime]::Parse($response._embedded.product.globalReleaseDate).ToString("yyyy")
            }
            catch {
                Write-Warning "Failed to parse release date for game ID $gameID"
            }
        }

        # Extract tag slugs
        $tagSlugs = @()
        if ($response._embedded.tags -and $response._embedded.tags.Count -gt 0) {
            $tagSlugs = $response._embedded.tags | ForEach-Object { $_.slug }
        }

        # Process screenshots
        $screenshots = @()
        if ($response._embedded.screenshots -and $response._embedded.screenshots.Count -gt 0) {
            foreach ($screenshot in $response._embedded.screenshots) {
                if ($screenshot._links.self.href) {
                    $screenshotUrl = $screenshot._links.self.href -replace '\{formatter\}', '1600'
                    $screenshots += $screenshotUrl
                }
            }
        }

        # Process the response
        $filteredData = @{
            gameID = $gameID
            sourceUrl = $sourceUrl
            store = $response._links.store.href
            title = $response._embedded.product.title
            year = $yearValue
            video = $videoValue
            publisher = $response._embedded.publisher.name
            developers = $response._embedded.developers.name
            tags = $tagSlugs
            screenshots = $screenshots
        }
        
        return $filteredData
    }
    catch {
        Write-Warning "Failed to fetch GOG metadata for game ID $gameID : $_"
        return $null
    }
}

# Function to fetch and process metadata from IGDB API using URL
function Get-IGDBMetadata {
    param (
        [string]$gameUrl,
        [string]$accessToken
    )
    
    $apiUrl = "https://api.igdb.com/v4/games"
    $headers = @{
        "Client-ID" = $clientID
        "Authorization" = "Bearer $accessToken"
    }
    
    $body = @"
fields name,first_release_date,involved_companies.company.name,involved_companies.publisher,screenshots.image_id,videos.video_id,genres.name,url,slug;
where url = "$gameUrl";
"@
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body -ContentType "text/plain"
        if ($response.Count -eq 0) {
            Write-Warning "No data returned from IGDB for URL $gameUrl"
            return $null
        }
        
        $gameData = $response[0]
        
        # Extract year
        $yearValue = $null
        if ($gameData.first_release_date) {
            try {
                $dateTime = [DateTimeOffset]::FromUnixTimeSeconds($gameData.first_release_date).DateTime
                $yearValue = $dateTime.ToString("yyyy")
            }
            catch {
                Write-Warning "Failed to parse release date for URL $gameUrl"
            }
        }
        
        # Extract developers and publishers
        $developersList = [System.Collections.Generic.List[string]]::new()
        $publishersList = [System.Collections.Generic.List[string]]::new()
        
        if ($gameData.involved_companies) {
            foreach ($company in $gameData.involved_companies) {
                if ($company.publisher) {
                    $publishersList.Add($company.company.name)
                } else {
                    $developersList.Add($company.company.name)
                }
            }
        }
        
        # Convert to strings
        $developers = $developersList -join ", "
        $publisher = $publishersList -join ", "
        
        # Extract tags
        $tags = @()
        if ($gameData.genres) {
            $tags = $gameData.genres | ForEach-Object { $_.name }
        }
        
        # Process screenshots
        $screenshots = @()
        if ($gameData.screenshots) {
            foreach ($screenshot in $gameData.screenshots) {
                $screenshots += "https://images.igdb.com/igdb/image/upload/t_original/$($screenshot.image_id).jpg"
            }
        }
        
        # Handle video
        $videoValue = $null
        if ($gameData.videos -and $gameData.videos.Count -gt 0) {
            $videoValue = $gameData.videos[0].video_id
        }
        
        $filteredData = @{
            gameID = $gameData.slug
            sourceUrl = $gameUrl
            store = "https://www.igdb.com/games/$($gameData.slug)"
            title = $gameData.name
            year = $yearValue
            video = $videoValue
            publisher = $publisher
            developers = $developers
            tags = $tags
            screenshots = $screenshots
        }
        
        return $filteredData
    }
    catch {
        Write-Warning "Failed to fetch IGDB metadata for URL $gameUrl : $_"
        return $null
    }
}

# Main script execution
$mode = Show-ModeMenu

# Get IGDB access token (only needed for modes that might fetch data)
if ($mode -ne 'delete') {
    $igdbAccessToken = Get-IGDBAccessToken -clientID $clientID -clientSecret $clientSecret
    if (-not $igdbAccessToken) {
        Write-Warning "Failed to authenticate with IGDB API. IGDB URLs will be skipped."
    }
}

# Get all .url files recursively
$urlFiles = Get-ChildItem -Path $RootPath -Filter "*.url" -Recurse -File
$processedCount = 0
$deletedCount = 0
$skippedCount = 0

foreach ($file in $urlFiles) {
    $metaPath = Join-Path -Path $file.DirectoryName -ChildPath "meta.txt"
    
    # Handle delete mode
    if ($mode -eq 'delete') {
        if (Test-Path $metaPath) {
            Remove-Item $metaPath -Force
            Write-Host "Deleted: $metaPath"
            $deletedCount++
        }
        continue
    }
    
    # Handle skip mode
    if ($mode -eq 'skip' -and (Test-Path $metaPath)) {
        Write-Host "Skipping (meta exists): $($file.FullName)"
        $skippedCount++
        continue
    }
    
    # Read the .url file content
    $content = Get-Content -Path $file.FullName -Raw
    
    # Check for game URLs
    if ($content -imatch "gogdb|igdb") {
        if ($content -imatch "URL=(.*)") {
            $url = $matches[1].Trim()
            Write-Host "Processing: $($file.FullName)"
            
            $identifier = Get-GameIdentifierFromURL -url $url
            if ($identifier) {
                $metadata = $null
                
                if ($identifier.Type -eq "GOG") {
                    $metadata = Get-GOGMetadata -gameID $identifier.ID -sourceUrl $url
                }
                elseif ($identifier.Type -eq "IGDB" -and $igdbAccessToken) {
                    $metadata = Get-IGDBMetadata -gameUrl $identifier.URL -accessToken $igdbAccessToken
                }
                elseif ($identifier.Type -eq "IGDB") {
                    Write-Warning "Skipping IGDB URL because authentication failed"
                }
                
                if ($metadata) {
                    $metadata | ConvertTo-Json -Depth 5 | Out-File -FilePath $metaPath -Force
                    Write-Host "Metadata saved to $metaPath"
                    $processedCount++
                }
            } else {
                Write-Warning "Could not extract game identifier from URL: $url"
            }
        }
    }
}

# Display results summary
switch ($mode) {
    'recreate' {
        Write-Host "Processing complete. $processedCount metadata files created/updated."
        Write-Host "$skippedCount files were not processed (no game URL found)."
    }
    'skip' {
        Write-Host "Processing complete. $processedCount metadata files created."
        Write-Host "$skippedCount existing metadata files were skipped."
    }
    'delete' {
        Write-Host "Processing complete. $deletedCount metadata files deleted."
    }
}

# Pause before exiting
Write-Host "Press any key to continue..."
[Console]::ReadKey($true) | Out-Null