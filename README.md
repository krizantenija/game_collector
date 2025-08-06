# Disclaimer

This is a local, game collection creator written in PowerShell.
Creates a single HTML catalog file from your game collection.
    
## Features

- The collector running fully offline. No additional software, installation needed.
- Can browse, search through offline files (deatached drives) with any browser
- Responsible, adjustable, styleable HTML result file
- Sort games by title/data/size/release date/added date (asc/desc)
- Filter games by it's main folder (categories)
- Create gamecards (in GOG style) with badges (category, istall type). Display header images (if available). Show/hide cover option.
- Summarize total game collection size, total game count
- Able to open the games local folder, to view files, start the installation process (within browser)
- Exclude folders list
- Separate 'meta' scraper from a link file to gather game informations like (developer, publisher, original title, release date, screenshoots). Can be GOG, or IGDB urls.
- With the extra 'meta' files, storelink, youtube video, lightbox gallery for screenshoots also available

## Installation

No need external program.
Just run the script in powershell on a Windows (7-10-11) PC machine.

## Usage

- Within the generator script (ps1), You can change the parameters on the top of the file (edit with notepad). Like: Games root drive, path, title, excludes...
- The 'Meta' generator looking for [GOGDB.org](https://gogdb.org), or [IGDB.com](https://www.igdb.com) link for the active game. You can drag&drop these files from the browser to the game dir.
- You need to manually save the game header/cover images
- The folder structure for the game collection should be this kind:
-- Games/DOSgames/Doom2/


## Screenshoots
Source folder:

![folders](https://github.com/krizantenija/game_collector/blob/main/shoot3.png)

Processing:

![running](https://github.com/krizantenija/game_collector/blob/main/shoot2.png)

Result:

![html](https://github.com/krizantenija/game_collector/blob/main/shoot1.jpg)

## License

[CC 4.0](https://creativecommons.org/licenses/by/4.0/)
