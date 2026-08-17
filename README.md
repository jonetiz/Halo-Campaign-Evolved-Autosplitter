# Halo: Campaign Evolved Autosplitter

## Description
This is an autosplitter and load remover for Halo: Campaign Evolved; this operates in full accordance with official timing rules for the game, found at https://haloruns.com/rules#hceremake (RTA - Loads - Cutscenes - Pauses). Current behavior calculates the real time based on an internal in game tick counter, that only updates while not paused, loading, or in a cutscene. The game is approximately 60 TPS +/- 10% depending on hardware.

## Features
- Start timer when initial level cutscene is skipped
- Load removal (currently configured to treat main menu as loads)
- Split when level changes
- Individual Level Mode, to complete splits at level end cutscene
- Option to split on BSP changes
- Option to split on mid-level cutscenes

## Contribution
Anyone is welcome to contribute, please just open a pull request. 