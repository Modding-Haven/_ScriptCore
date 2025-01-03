# _ScriptCore

![ScriptCore Cover](https://i.imgur.com/cdQ0stZ.jpeg)

ScriptCore is a collection of 3 utilities for REFramework scripting:
- Hotkeys.lua - A hotkey manager that allows for simple binding of hotkeys for gamepad, keyboard and mouse, with methods for checking if the keys are pressed, released, down, held for a time or double tapped
- Functions.lua - A collection of useful functions for such things as getting components, merging System.Arrays, casting rays, cloning objects, copying fields and more
- Imgui.lua - A collection of UI functions for imgui including a file picker, theme manager and useful wrappers to mitigate the most inconvenient things about coding imgui

To use these in your script, simply use Lua's `require` method to get them in a table
Descriptions of most functions can be found by viewing the lua files in a text editor

## Installation

1. Download [REFramework](https://github.com/praydog/REFramework) SF6.zip and place its dinput8.dll in your game folder
2. Place the contents the reframework folder from this repository in your game directory
3. Use `require` in your script to access ScriptCore's functions and use them in your scripts

## Examples
[Skill Maker](https://www.nexusmods.com/dragonsdogma2/mods/691) - A large script that extensively uses _ScriptCore. Search for `func` (Functions), `hk` (Hotkeys) and `ui` (Imgui) tables to see how it's used

[Teleportation](https://www.nexusmods.com/dragonsdogma2/mods/444) - One of many smaller scripts that utilize Hotkeys.lua

## Credits

- Created by alphaZomega and SilverEzredes
- REFramework created by praydog
