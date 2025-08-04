<#
.SYNOPSIS
    Creates an HTML catalog of game folders organized by categories with creation dates and badges
.DESCRIPTION
    Generates a complete HTML catalog with game categories, creation dates, and badges
#>

param (
    [string]$GamesPath = "G:\",
    [string]$OutputFile = "GameCatalog.html",
    [string]$ImageFolder = "img",
    [string]$Stylesheet = "style.css",
    [string]$Title = "K2 PC Game Collection",
    [string[]]$ExcludeFolders = @('gam-switch-emu', 'xxx')
)

# Start measuring execution time
$scriptStartTime = Get-Date

function Parse-MetaFile {
    param (
        [string]$FilePath
    )
    
    try {
        if (Test-Path $FilePath) {
            $content = Get-Content $FilePath -Raw -ErrorAction Stop
            $meta = $content | ConvertFrom-Json -ErrorAction Stop
            
            # Ensure we have a proper object
            if ($meta -is [PSCustomObject]) {
                return $meta
            }
        }
    } catch {
        Write-Warning "Failed to parse meta file at $FilePath : $_"
    }
    
    return $null
}

# Create output directory structure
$OutputDir = Split-Path -Parent $OutputFile
if (-not $OutputDir) { $OutputDir = $PWD.Path }
$OutputFile = Join-Path $OutputDir (Split-Path -Leaf $OutputFile)
$ImageFolderPath = Join-Path $OutputDir $ImageFolder
$StylesheetPath = Join-Path $OutputDir $Stylesheet

# Create image directory if it doesn't exist
if (-not (Test-Path $ImageFolderPath)) {
    New-Item -ItemType Directory -Path $ImageFolderPath -Force | Out-Null
}

# Supported cover image filenames (in order of preference)
$coverFilePatterns = @(
    "cover.jpg", "cover.png",
    "header.jpg", "header.png",
    "folder.jpg", "folder.png",
    "*.jpg", "*.png", "*.jpeg", "*.webp"
)

# File type patterns to detect
$fileTypePatterns = @{
    "archive" = @("*.rar", "*.zip", "*.7z")
    "exe" = @("*.exe")
    "iso" = @("*.iso", "*.cue", "*.bin")
}

# CSS stylesheet content with added filter controls
$cssContent = @"
:root {
    --primary-color: #16a2ff;
    --secondary-color: #6f6f6f;
    --background-color: #a0a0a0;
    --card-bg: #fff;
    --text-color: #e0e0e0;
    --title-color: #111;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    margin: 0;
    padding: 20px;
    background-color: var(--background-color);
    color: var(--text-color);
}

header {
    color: white;
    padding: 20px;
    text-align: center;
    margin-bottom: 30px;
}

h1 {
    margin: 0;
    font-size: 2.5em;
}

.search-container {
    margin: 20px auto;
    max-width: 540px;
}

#search {
    width: 100%;
    padding: 12px 15px;
    font-size: 16px;
    border: 2px solid #888;
    border-radius: 25px;
    outline: none;
    background-color: #f2f2f2;
    color: var(--title-color);
}

#search:hover {
    border-color: var(--primary-color);
}

.filter-controls {
    margin: 0 auto;
    max-width: 800px;
    display: flex;
    flex-wrap: wrap;
    gap: 15px;
    justify-content: center;
    margin-bottom: 20px;
}

.sort-controls {
    display: flex;
    gap: 10px;
}

.category-filter {
    display: flex;
    align-items: center;
    gap: 10px;
}

.filter-select {
    padding: 8px 15px;
    border-radius: 4px;
    border: 1px solid #ddd;
    background-color: #fff;
    font-size: 0.9em;
}

.sort-btn {
    background-color: var(--secondary-color);
    color: white;
    border: none;
    padding: 8px 15px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.9em;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    gap: 5px;
}

.sort-btn:hover {
    background-color: #0069d9;
}

.sort-btn.active {
    background-color: var(--primary-color);
    font-weight: bold;
}

.sort-direction {
    font-size: 0.8em;
    opacity: 0.8;
}

.game-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 25px;
    padding: 20px;
}

.game-card {
    background-color: var(--card-bg);
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 4px 8px rgba(0,0,0,0.2);
    transition: box-shadow .5s;
}

.game-card:hover {
    box-shadow: 0 4px 20px rgba(0,0,0,0.4);
}

.game-card:hover .game-cover {
    transform: scale(1.1);
}

.cover-container {
    width: 100%;
    height: 180px;
    overflow: hidden;
    position: relative;
    border-bottom: 1px solid #444;
}

.game-cover {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transition: all .5s;
}

.game-info {
    padding: 15px;
    display: flex;
    flex-wrap: wrap;
    justify-content: end;
}

.game-title {
    margin: 0 0 5px 0;
    color: var(--title-color);
    font-size: 1.1em;
    flex-basis: 100%;
}

.game-date {
    font-size: 0.7em;
    color: #aaa;
    margin-bottom: 5px;
    font-style: italic;
    width: 50%;
}

.game-size {
    font-size: 0.9em;
    color: #bbb;
    margin-bottom: 5px;
    font-weight: bold;
    width: 50%;
    text-align: right;
}

.game-folder {
    font-size: 0.8em;
    color: #ecac73;
    word-break: break-all;
    margin: 0;
    cursor: pointer;
    text-decoration: none;
    transition: all 0.2s;
}

.game-folder:hover {
    color: #b93400;
    text-decoration: underline;
}

.no-cover {
    height: 180px;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: #252525;
    color: #777;
    text-align: center;
}

.stats {
    text-align: center;
    margin: 20px 0;
    font-size: 1em;
    color: #fff;
}

.badge-container {
    display: flex;
    gap: 5px;
    margin-bottom: 8px;
    flex-basis: 100%;
    justify-content: space-between;
}

.badge {
    padding: 3px 8px;
    border-radius: 12px;
    font-size: 0.7em;
    font-weight: bold;
    color: white;
}

.to-right > span {
  margin-left: 5px;
}

.badge-archive {
    background-color: #e67e22;
}

.badge-exe {
    background-color: #9b59b6;
}

.badge-iso {
    background-color: #1abc9c;
}

.badge-category {
    background-color: #eeae15;
    order: -1;
}

.game-meta {
    font-size: 0.7em;
    color: #666;
    width: 100%;
    background: #eee;
    display: flex;
    flex-wrap:wrap;
}

.game-meta strong {
    color: #444;
}

.w50 {width: 50%;}
.w100{width: 100%;}

.butt {text-align: center;}

.butt a {
    text-decoration: none;
    font-size:2em;
    color: #777;
    margin: 0 5px;
}

.butt a:hover {
    color: var(--primary-color);
}

.toggle-covers-btn {
    background-color: #555;
    color: white;
    border: none;
    padding: 8px 15px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.9em;
    transition: all 0.2s;
}

.toggle-covers-btn:hover {
    background-color: #777;
}

/* Lightbox styles */
.lightbox {
    display: none;
    position: fixed;
    z-index: 9999;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0,0,0,0.9);
    overflow: auto;
}

.lightbox-content {
    position: relative;
    margin: auto;
    padding: 20px;
    max-width: 90%;
    max-height: 90%;
    top: 50%;
    transform: translateY(-50%);
    text-align: center;
}

.lightbox-img {
    max-width: 100%;
    max-height: 80vh;
    margin: 0 auto;
    display: block;
}

.lightbox-close {
    position: absolute;
    top: 15px;
    right: 35px;
    color: #f1f1f1;
    font-size: 40px;
    font-weight: bold;
    cursor: pointer;
}

.lightbox-nav {
    position: absolute;
    top: 50%;
    width: 100%;
    display: flex;
    justify-content: space-between;
    transform: translateY(-50%);
}

.lightbox-prev, .lightbox-next {
    color: white;
    font-size: 50px;
    font-weight: bold;
    padding: 10px 20px;
    cursor: pointer;
    user-select: none;
}

.lightbox-prev {
    left: 0;
}

.lightbox-next {
    right: 0;
}

.lightbox-caption {
    color: #fff;
    text-align: center;
    padding: 10px;
    font-size: 0.8em;
}

.lightbox-thumbnails {
    display: flex;
    justify-content: center;
    flex-wrap: wrap;
    gap: 10px;
}

.lightbox-thumbnail {
    width: 80px;
    height: 60px;
    object-fit: cover;
    cursor: pointer;
    opacity: 0.6;
    transition: opacity 0.3s;
}

.lightbox-thumbnail:hover, .lightbox-thumbnail.active {
    opacity: 1;
}

@media (max-width: 600px) {
    .game-grid {
        grid-template-columns: 1fr;
    }
    
    .filter-controls {
        flex-direction: column;
        align-items: center;
    }

    .lightbox-content {
        max-width: 95%;
    }

    .lightbox-thumbnail {
        width: 60px;
        height: 45px;
    }
}
"@

# Get all category folders, excluding specified folders
$categoryFolders = Get-ChildItem -Path $GamesPath -Directory -ErrorAction SilentlyContinue | 
                   Where-Object { $ExcludeFolders -notcontains $_.Name }

if (-not $categoryFolders) {
    Write-Host "No category folders found in $GamesPath"
    exit
}

# Get unique categories for the filter dropdown
$uniqueCategories = $categoryFolders | Select-Object -ExpandProperty Name -Unique | Sort-Object

# HTML template header with lightbox HTML
$htmlHeader = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title</title>
    <link rel="stylesheet" href="$Stylesheet">
    <link rel="icon" href="favicon.ico">
    <script>
        let currentSort = {
            by: 'title',
            direction: 1
        };
        let currentCategoryFilter = 'all';
        let coversVisible = true;
        
        function searchGames() {
            const search = document.getElementById('search').value.toLowerCase();
            const categoryFilter = document.getElementById('categoryFilter').value;
            const games = document.querySelectorAll('.game-card');
            let visibleCount = 0;
            let visibleTotalSize = 0;
            
            games.forEach(game => {
                const title = game.dataset.title.toLowerCase();
                const category = game.dataset.category;
                const matchesSearch = title.includes(search);
                const matchesCategory = categoryFilter === 'all' || category === categoryFilter;
                
                if (matchesSearch && matchesCategory) {
                    game.style.display = 'block';
                    visibleCount++;
                    visibleTotalSize += parseInt(game.dataset.size || 0);
                } else {
                    game.style.display = 'none';
                }
            });
            
            document.getElementById('gameCount').textContent = visibleCount;
            document.getElementById('totalSize').textContent = Math.round(visibleTotalSize / (1024 * 1024 * 1024));
        }
        
        function sortGames(sortBy, initialLoad = false) {
            const gameGrid = document.getElementById('gameGrid');
            const games = Array.from(document.querySelectorAll('.game-card'));
            
            if (!initialLoad && currentSort.by === sortBy) {
                currentSort.direction *= -1;
            } else {
                currentSort.by = sortBy;
                currentSort.direction = sortBy === 'title' ? 1 : -1;
            }
            
            document.querySelectorAll('.sort-btn').forEach(btn => {
                btn.classList.remove('active');
                if (btn.dataset.sort === sortBy) {
                    btn.classList.add('active');
                    const directionSpan = btn.querySelector('.sort-direction');
                    directionSpan.textContent = currentSort.direction === 1 ? '^' : 'v';
                }
            });
            
            games.sort((a, b) => {
                if (sortBy === 'title') {
                    return currentSort.direction * a.dataset.title.localeCompare(b.dataset.title);
                } else if (sortBy === 'date') {
                    return currentSort.direction * (new Date(b.dataset.date) - new Date(a.dataset.date));
                } else if (sortBy === 'size') {
                    return currentSort.direction * (parseInt(b.dataset.size) - parseInt(a.dataset.size));
                } else if (sortBy === 'year') {
                    const yearA = parseInt(a.dataset.year) || 0;
                    const yearB = parseInt(b.dataset.year) || 0;
                    return currentSort.direction * (yearB - yearA);
                }
                return 0;
            });
            
            games.forEach(game => gameGrid.appendChild(game));
            
            if (!initialLoad) searchGames();
        }
        
        function updateCategoryFilter() {
            currentCategoryFilter = document.getElementById('categoryFilter').value;
            searchGames();
        }
        
        function toggleCovers() {
            coversVisible = !coversVisible;
            const covers = document.querySelectorAll('.cover-container, .no-cover, .game-meta');
            const btn = document.getElementById('toggleCoversBtn');
            
            covers.forEach(cover => {
                cover.style.display = coversVisible ? 'block' : 'none';
            });
            
            btn.textContent = coversVisible ? 'Hide Covers' : 'Show Covers';
        }
        
        // Lightbox functionality
        let currentLightboxIndex = 0;
        let currentLightboxImages = [];
        
        function openLightbox(images, index = 0) {
            currentLightboxImages = images;
            currentLightboxIndex = index;
            const lightbox = document.getElementById('lightbox');
            const lightboxImg = document.getElementById('lightbox-img');
            const lightboxCaption = document.getElementById('lightbox-caption');
            const thumbnailsContainer = document.getElementById('lightbox-thumbnails');
            
            lightbox.style.display = 'block';
            updateLightboxImage();
            
            // Create thumbnails
            thumbnailsContainer.innerHTML = '';
            images.forEach((img, idx) => {
                const thumb = document.createElement('img');
                thumb.src = img;
                thumb.className = 'lightbox-thumbnail' + (idx === index ? ' active' : '');
                thumb.onclick = () => {
                    currentLightboxIndex = idx;
                    updateLightboxImage();
                };
                thumbnailsContainer.appendChild(thumb);
            });
            
            // Close when clicking outside content
            lightbox.onclick = function(e) {
                if (e.target === lightbox) {
                    closeLightbox();
                }
            };
            
            // Keyboard navigation
            document.addEventListener('keydown', handleKeyDown);
        }
        
        function closeLightbox() {
            document.getElementById('lightbox').style.display = 'none';
            document.removeEventListener('keydown', handleKeyDown);
        }
        
        function handleKeyDown(e) {
            if (e.key === 'Escape') {
                closeLightbox();
            } else if (e.key === 'ArrowRight') {
                changeImage(1);
            } else if (e.key === 'ArrowLeft') {
                changeImage(-1);
            }
        }
        
        function changeImage(step) {
            currentLightboxIndex += step;
            if (currentLightboxIndex >= currentLightboxImages.length) {
                currentLightboxIndex = 0;
            } else if (currentLightboxIndex < 0) {
                currentLightboxIndex = currentLightboxImages.length - 1;
            }
            updateLightboxImage();
        }
        
        function updateLightboxImage() {
            const lightboxImg = document.getElementById('lightbox-img');
            const lightboxCaption = document.getElementById('lightbox-caption');
            const thumbnails = document.querySelectorAll('.lightbox-thumbnail');
            
            lightboxImg.src = currentLightboxImages[currentLightboxIndex];
            lightboxCaption.textContent = 'Image ' + (currentLightboxIndex + 1) + ' of ' + currentLightboxImages.length;
            
            thumbnails.forEach((thumb, idx) => {
                thumb.classList.toggle('active', idx === currentLightboxIndex);
            });
        }
        
        document.addEventListener('DOMContentLoaded', function() {
            document.getElementById('search').addEventListener('input', searchGames);
            document.getElementById('categoryFilter').addEventListener('change', updateCategoryFilter);
            document.getElementById('toggleCoversBtn').addEventListener('click', toggleCovers);
            sortGames('title', true);
        });
    </script>
</head>
<body>
    <header>
        <h1>$Title</h1>
    </header>
    
    <div class="search-container">
        <input type="text" id="search" placeholder="Search games..." autocomplete="off">
    </div>
    
    <div class="filter-controls">
        <div class="sort-controls">
            <button class="sort-btn active" data-sort="title" onclick="sortGames('title')">
                Title <span class="sort-direction">↑</span>
            </button>
            <button class="sort-btn" data-sort="date" onclick="sortGames('date')">
                Add <span class="sort-direction"></span>
            </button>
            <button class="sort-btn" data-sort="size" onclick="sortGames('size')">
                Size <span class="sort-direction"></span>
            </button>
            <button class="sort-btn" data-sort="year" onclick="sortGames('year')">
                Year <span class="sort-direction"></span>
            </button>
        </div>
        
        <div class="category-filter">
            <select id="categoryFilter" class="filter-select">
                <option value="all">All Categories</option>
"@

# Add category options to HTML
foreach ($category in $uniqueCategories) {
    $htmlHeader += "                <option value=`"$($category)`">$($category)</option>`n"
}

# Complete the HTML header with lightbox HTML
$htmlHeader += @"
            </select>
        </div>
        
        <button id="toggleCoversBtn" class="toggle-covers-btn">Hide Covers</button>
    </div>
    
    <div class="stats">
        Total games: <span id="gameCount">0</span> &nbsp;|&nbsp; Total size: <span id="totalSize">0</span> GB
    </div>
    
    <div class="game-grid" id="gameGrid">
    
    <!-- Lightbox HTML -->
    <div id="lightbox" class="lightbox">
        <span class="lightbox-close" onclick="closeLightbox()">&times;</span>
        <div class="lightbox-content">
            <img id="lightbox-img" class="lightbox-img">
            <div id="lightbox-caption" class="lightbox-caption"></div>
            <div class="lightbox-nav">
                <span class="lightbox-prev" onclick="changeImage(-1)">&#10094;</span>
                <span class="lightbox-next" onclick="changeImage(1)">&#10095;</span>
            </div>
            <div id="lightbox-thumbnails" class="lightbox-thumbnails"></div>
        </div>
    </div>
"@

# HTML template footer
$htmlFooter = @"
    </div>
</body>
</html>
"@

$totalGames = 0
$gamesWithCovers = 0
$gamesWithMeta = 0
$totalSizeGB = 0

# Create stylesheet file
$cssContent | Out-File -FilePath $StylesheetPath -Encoding UTF8 -Force

# Create HTML file with header
$htmlHeader | Out-File -FilePath $OutputFile -Encoding UTF8 -Force

# Process each category folder
foreach ($category in $categoryFolders) {
    $categoryName = $category.Name
    $categoryPath = $category.FullName
    
    # Get all game folders in this category (only top-level folders)
    $gameFolders = Get-ChildItem -Path $categoryPath -Directory -Depth 0 -ErrorAction SilentlyContinue
    if (-not $gameFolders) { continue }
    
    foreach ($game in $gameFolders) {
        $totalGames++
        $gameName = $game.Name
        $gamePath = $game.FullName
        $creationDate = $game.CreationTime.ToString("yyyy-MM-dd HH:mm")
        $coverFound = $false
        $coverImagePath = $null
        
        # Calculate folder size (including subfolders)
        $folderSizeMB = 0
        $bytes = 0
        try {
            $bytes = (Get-ChildItem -Path $gamePath -File -Recurse -ErrorAction Stop | 
                     Measure-Object -Property Length -Sum -ErrorAction Stop).Sum
            $folderSizeMB = [math]::Round($bytes / 1MB)
            $totalSizeGB += $bytes
        } catch {
            Write-Warning "Could not calculate size for $gameName"
        }
        
        # Try to find a cover image
        foreach ($pattern in $coverFilePatterns) {
            $potentialCover = Get-ChildItem -Path $gamePath -Filter $pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($potentialCover) {
                $coverFound = $true
                $coverImagePath = $potentialCover.FullName
                break
            }
        }
        
        # Detect file types in the folder
        $fileTypeBadges = "<div class='to-right'>"       
        foreach ($type in $fileTypePatterns.Keys) {
            foreach ($pattern in $fileTypePatterns[$type]) {
                $files = Get-ChildItem -Path $gamePath -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue
                if ($files) {
                    $fileTypeBadges += "<span class='badge badge-$type'>$type</span>"
                    break
                }
            }
        }
        $fileTypeBadges += "</div>"
        
        # Add category badge
        $fileTypeBadges += "<span class='badge badge-category'>$($categoryName)</span>"
        
        # Prepare badges HTML
        $badgesHtml = "<div class='badge-container'>$($fileTypeBadges -join '')</div>"
        
        # Check for meta.txt file
        $metaFile = Join-Path $gamePath "meta.txt"
        $metaInfo = Parse-MetaFile -FilePath $metaFile
        
        if ($metaInfo) {
            $gamesWithMeta++
        }
        
        # Prepare meta information display if available
        $metaHtml = ""
        if ($metaInfo) {
            $metaItems = @()
            
            if ($metaInfo.developers) {
                $metaItems += "<div class='w50'><strong>Dev:</strong> $($metaInfo.developers)</div>"
            }
            if ($metaInfo.year) {
                $metaItems += "<div class='w50'><strong>Year:</strong> $($metaInfo.year)</div>"
            }

            if ($metaInfo.publisher) {
                $metaItems += "<div class='w50'><strong>Pub:</strong> $($metaInfo.publisher)</div>"
            }

            if ($metaInfo.tags -and $metaInfo.tags.Count -gt 0) {
                $tags = $metaInfo.tags -join ", "
                $metaItems += "<div class='w50'><strong>Tags:</strong> $tags</div>"
            }

            $metaItems += "<div class='butt w100'>"
            if ($metaInfo.video) {
                $metaItems += "<a href='https://www.youtube-nocookie.com/embed/$($metaInfo.video)' target='_blank' title='Youtube'>&#9654;</a>"
            }
            if ($metaInfo.store) {
                $metaItems += "<a href='$($metaInfo.store)' target='_blank' title='Store'>&#9432;</a>"
            }
            
            # Add screenshots button if screenshots exist
            if ($metaInfo.screenshots -and $metaInfo.screenshots.Count -gt 0) {
                $screenshotsJson = $metaInfo.screenshots | ConvertTo-Json -Compress
                $metaItems += "<a href='#' onclick='openLightbox($screenshotsJson, 0); return false;' title='Screenshots'>&#9637;</a>"
            }
            
            $metaItems += "</div>"

            if ($metaItems.Count -gt 0) {
                $metaHtml = "<div class='game-meta'>$($metaItems -join '')</div>"
            }
        }
        
        # Prepare the clickable folder path
        $escapedPath = $gamePath.Replace('\', '/').Replace("'", "\'")
        $folderPath = "<p class='game-folder' onclick=`"location.href='file:///$escapedPath'`">$($gamePath.Replace('"', '&quot;'))&#9721;</p>"
        
        # Get year from meta or default to 0
        $yearValue = 0
        if ($metaInfo -and $metaInfo.year) {
            $yearValue = $metaInfo.year
        }
        
        if ($coverFound) {
            $gamesWithCovers++
            
            # Create unique filename for the copied image
            $imageExt = [System.IO.Path]::GetExtension($coverImagePath)
            $uniqueImageName = "$($gameName -replace '[^a-zA-Z0-9]','_')$imageExt"
            $destImagePath = Join-Path $ImageFolderPath $uniqueImageName
            
            # Copy image to central folder
            try {
                Copy-Item -Path $coverImagePath -Destination $destImagePath -Force -ErrorAction Stop
                $relativeImagePath = "$ImageFolder/$uniqueImageName".Replace('\', '/')
                
                $gameCard = @"
        <div class="game-card" data-title="$($gameName.Replace('"', '&quot;'))" data-size="$($bytes)" data-date="$creationDate" data-category="$($categoryName)" data-year="$yearValue">
            <div class="cover-container">
                <img src="$relativeImagePath" class="game-cover" alt="$($gameName.Replace('"', '&quot;')) cover">
            </div>
            <div class="game-info">
                <h3 class="game-title">$($gameName.Replace('"', '&quot;'))</h3>
                $badgesHtml
                <div class="game-date">Created: $creationDate</div>
                <div class="game-size">$folderSizeMB MB</div>
                $metaHtml
                $folderPath
            </div>
        </div>
"@
            } catch {
                Write-Warning "Failed to copy cover image for $gameName"
                $gamesWithCovers--
                $coverFound = $false
            }
        }
        
        if (-not $coverFound) {
            $gameCard = @"
        <div class="game-card" data-title="$($gameName.Replace('"', '&quot;'))" data-size="$($bytes)" data-date="$creationDate" data-category="$($categoryName)" data-year="$yearValue">
            <div class="no-cover">No Cover Image</div>
            <div class="game-info">
                <h3 class="game-title">$($gameName.Replace('"', '&quot;'))</h3>
                $badgesHtml
                <div class="game-date">Created: $creationDate</div>
                <div class="game-size">$folderSizeMB MB</div>
                $metaHtml
                $folderPath
            </div>
        </div>
"@
        }
        
        # Append game card to HTML file
        Add-Content -Path $OutputFile -Value $gameCard -Encoding UTF8
    }
}

# Convert total size to GB
$totalSizeGB = [math]::Round($totalSizeGB / (1024 * 1024 * 1024))

# Calculate execution time
$executionTime = (Get-Date) - $scriptStartTime
$executionTimeString = "{0:hh\:mm\:ss\.fff}" -f $executionTime

# Add footer with initial counts
$initialCountsScript = @"
<script>
    document.getElementById('gameCount').textContent = $totalGames;
    document.getElementById('totalSize').textContent = $totalSizeGB;
</script>
"@

# Append footer and initial counts to HTML file
Add-Content -Path $OutputFile -Value $initialCountsScript -Encoding UTF8
Add-Content -Path $OutputFile -Value $htmlFooter -Encoding UTF8

Write-Host "Game catalog generated: $OutputFile"
Write-Host "Stylesheet created: $StylesheetPath"
Write-Host "Total games: $totalGames"
Write-Host "Games with covers: $gamesWithCovers"
Write-Host "Games with meta: $gamesWithMeta"
Write-Host "Total size: $totalSizeGB GB"
Write-Host "Execution time: $executionTimeString"
Write-Host "Cover images copied to: $ImageFolderPath"

# Open the HTML file in default browser
Start-Process $OutputFile

# Add pause at the end to prevent window from closing immediately
Write-Host "Press any key to continue..."
[Console]::ReadKey($true) | Out-Null