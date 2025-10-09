# Changelog

## v0.29 - 2025-10-09

### Alpha Release

11.2.5 is supported
- Bump TOC to 11.2.5
- Fixed crash: attempt to call method 'SetDataProvider' (a nil value)

## v0.28 - 2025-08-27

### Alpha Release

Resolved an issue that caused the foucsed quests Pins are not highlighted when "Show All Quests" is disabled

## v0.27 - 2025-08-19

### Alpha Release

Added support of showing quests on current map only - Turn on/off via settings "Show All Quests"

## v0.26 - 2025-08-14

### Alpha Release

Improved UI for single-character mode (when no alts are scanned)

## v0.25 - 2025-08-12

### Alpha Release

Now the Map Pins of Inactive Quests could be hidden or faded via the settings "Inactive Quests Opacity"

## v0.24 - 2025-08-08

### Alpha Release

- Bump TOC to 11.2.0
- Added tracking of first completion bouns of K'aresh World Quests

## v0.23 - 2025-07-21

### Alpha Release

- Resolved an issue that caused the quest log is not updated sometimes

## v0.22 - 2025-07-16

### Alpha Release

- Now the the completed world quests can be shown under new "Completed" section, turn it on in Settings -> Quest Log
- Resolved an issue where first completion bonuses sometimes did not appear under the "Not Collected" mode in Warband Rewards

## v0.21 - 2025-07-13

### Alpha Release

- Improved UI of Map Pins Settings
- Added quest log progress text customization options:
    - Show count of characters who have claimed the filtered quest rewards
    - Show count of characters who haven't claimed the filtered quest rewards
    - Hide progress text entirely

## v0.20 - 2025-07-10

### Alpha Release

- Enhanced War Mode quest scanning functionality
- Added sound feedback when interacting with quest log
- Introduced a War Mode Bonus button - Quickly toggle War Mode without opening the Talent page
- Resolved an issue where first completion bonuses occasionally didn't display as claimed

## v0.19 - 2025-07-08

### Alpha Release

Added Warband one-time rewards display (in blue) with filtering

## v0.18 - 2025-07-03

### Alpha Release

Fixed crash when no inactive quests are shown in quest log: WarbandWorldQuestMapFrame.lua:289: attempt to index field 'data' (a nil value)

## v0.17 - 2025-07-02

### Alpha Release

Fixed crash on first installation: WarbandWorldQuest.lua:233: attempt to index global 'WarbandWorldQuestSettings' (a nil value)

## v0.16 - 2025-07-01

### Alpha Release

- Quest Log now scrolls to the highlighted row when hovering over map pins
- Added instant PvP quests scanning when turning on War Mode
- Quest Log UI now updates dynamically when uncollected rewards change

## v0.15 - 2025-06-29

### Alpha Release

- Added Russian localization
- Added quest log reward text customization options:
    - Warband total rewards
    - Warband uncollected rewards
    - Current player rewards

## v0.14 - 2025-06-28

### Alpha Release

- Added more localizations
- Added settings to show/hide the time left label in quest log

## v0.13 - 2025-06-27

### Alpha Release

- Added Shadowlands world quest tracking support (Thanks @MayaWoW)
- Added persistent reward filters - No need to reconfigure filters after each login (Thanks @cidddiii)

## v0.12 - 2025-06-25

### Alpha Release

- Now the World Map tab button can ajust its position automatically when other addons that added another tab buttons
- New Addon Icon

## v0.11 - 2025-06-14

### Alpha Release

- Optimized paddings of elements in quest log row
- Now the quest progress in log updates correctly after completion

## v0.10 - 2025-06-13

### Alpha Release

#### Issues Fixed

- The Warband Progress padding in Tooltip is sometimes incorrect
- The Pins of Active Quests are not shown until opening Warband Quest Tab when **"Default Tab"** is unselected

#### New Features

- Now the location text in rows of panel will be highlighed for currently opened map
- Added tooltip for item and currency in **"Rewards Filter"**

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
