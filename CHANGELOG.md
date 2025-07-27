# Changelog

## v0.11 - 2025-07-27

- Enhanced encounter button UI when player is in instance
- Now only unclaimed rewards are tracked for encounters with multiple rewards

## v0.10 - 2025-07-22

- Added support of Shared Legacy Raid Difficulties

## v0.9 - 2025-07-19

- Show encouter progress in red color if current instance difficulty is invalid to get the reward
- Fixed reset time of 5N and 5H dungeons
- Added German locale support - Thanks @GogadonLive

## v0.8 - 2025-07-18

- Fixed Navigation to Underrot
- The warnings now work correctly when Dungeon difficulty is set already
- Enhanced mount collection status tracking
- Added support for tracking attempts when an encounter contains multiple rewards. I.e. Blazing Drake and Life-Binder's Handmaiden from Deathwing

## v0.7 - 2025-07-15

- Added navigation to Dragon Soul
- Added settings to turn on/off reward announcement
- Added sound feedback when adjusting difficulty settings
- Improved UI responsiveness for content updates
- Fixed tooltip crashes - (Thanks @martinboy1974)
    - WarbandRewardsTrackerEntry.lua:96: Usage: GameTooltip:SetText("text" [, color, wrap])
    - WarbandRewardsTracker.lua:170: bad argument #1 to 'format' (string expected, got nil)

## v0.6 - 2025-07-15

- Added Dungeon Entrance SuperTrack support with clear navigation routes
- Enhanced collected mount detection accuracy

## v0.5 - 2025-07-15

- Fixed the crash: bad argument #1 to '? C_MountJournal.GetMountInfoByID

## v0.4 - 2025-07-14

- Announce the mount looted
- Enhanced the attempts counting
- fix: crashes when killed boss and CD reset

## v0.1 - 2025-07-09

### Alpha Release

**WarbandRewardsTracker** lets you easily monitor rewards progress for every character in your warband—no more logging in and out repeatedly!

Now all legacy mounts with increased drop rates within Collector's Bounty event are supported

#### Key Features

✔ **No Setup Needed** – Ready to use immediately after installation

✔ **Multi-Character Tracking** – View progress and rewards for all your alts in one place

✔ **Lightweight** – Minimal impact on game performance
