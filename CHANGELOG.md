# Changelog

## v0.9 - 2025-06-10

### Alpha Release

#### New Features

- Added Dragon Isles world quest tracking support
- Added world quest icon in the quest log - Click to track the quest in Warband
- Added default tab toggle in settings

## v0.8 - 2025-06-09

### Alpha Release

Crashes on first installation are fixed
- WarbandWorldQuest.lua:96: attempt to perform arithmetic on a nil value
- WorldQuest.lua:399: bad argument #2 to 'band' (number expected, got nil)

#### New Features

- Now the equipments rewards displayed in the quest log are aggregated by equipLoc - This ensures a cleaner display
- All non-equipable items are categorized into "Equipment" in the **Rewards Filter** - The forever "Loading..." rows are gone
- Added quests scanning completed indicators in the quest log title - Also able to turn on/off in the settings


## v0.7 - 2025-06-08

### Alpha Release

UI improved: Enhanced overall readability

#### New Features

- Now a green checkmark is displayed on pins for completed quests - Helps identify quest status with progress turned off
- Added support of displaying the tracking checkmark(yellow) for quests with wrapped title
- Added support of re-scanning quests when new ones spawn - Previously only scanned once on login

## v0.6 - 2025-06-07

### Alpha Release

#### New Features

- Added settings to delete unused characters
- Added settings to exclude tracking characters - Click the 'Characters' button, located to the left of the 'Settings' button.

## v0.5 - 2025-06-06

### Alpha Release

Performance improved: Now less mem computing is used by addon

## v0.4 - 2025-06-05

### Alpha Release

#### New Features

- Refresh rewards for all incomplete quests on login - Now quests completed before installing the addon could be recognized
- Added settings to show/hide pins of completed quests
- Added settings to show/hide progress in pin tooltips

## v0.3 - 2025-05-28

### Alpha Release

The duplicated quests of Azj-Kahet issue is fixed

#### New Features

- Now the next reset quests are sorted by location
- Now all map pin releated features are supported during combat
- Now hovering on map pin will highlight the quest row
- Added support of excluding quest types from Next Reset count - Click the "Next Reset" button
- Added an option in right-click menu to move the selected quest to Inactive section

## v0.2 - 2025-05-26

### Alpha Release

#### New Features

- Added settings to toggle showing pins on continent maps
- Improved UI of next reset button tooltip
- Quests with unmatched rewards type are marked in red color
- Added support of tracking world quest at warband/account level
- Now the quest panel will show a loading spinner when data is unavailable

## v0.1 - 2025-05-24

### Alpha Release

**WarbandWorldQuest** lets you easily monitor world quest progress and rewards for every character in your warband—no more logging in and out repeatedly!

#### Key Features

✔ **No Setup Needed** – Ready to use immediately after installation

✔ **Multi-Character Tracking** – View progress and rewards for all your alts in one place

✔ **Lightweight** – Minimal impact on game performance

✔ **Enhanced Map Pins**
- Displays completed quests on the map
- Shows pins on continent maps for better visibility
- Displays warband progress on map pin
    
✔ **Organized Quest List** – World quests are sorted into two clear sections:
- Active Quests – Displays quests matching your reward filters
- Inactive Quests – Collapsible section for filtered-out quests
