## About

Standalone typing test app.   
The idea was to combine features I found useful from [Typing Practice (keybr.com)](https://www.keybr.com/), [Monkeytype](https://monkeytype.com/), [KeyPresso](https://keypresso.ru/), [Ngram Type](https://ranelpadon.github.io/ngram-type/) and exclude ads, personal data collection and server instabilities

## Features

- Words of different rarity (english 200, english 1k, etc)
- Filter words to include specific letter (to train rare letters like "J" or "Q", or to test how letter swaps in keyboard layout feel)
- Bigrams and Trigrams
- Learn letters one by one in your own order and pace
- Numbers mode
- Symbols mode
- WPM/CPM, time and accuracy meters after each test
- different test sizes: from one line up to full screen

## Controls

- Space to generate new test after completing last one
- ESC to reset test, ESC again to generate new test
- Backspace to fix mistakes

## Platforms

Technically this is a game build on [Godot Engine](https://godotengine.org/), so it should run on all platforms supported by Godot.    
I provide compiled binary for Windows, users on other platforms can either [launch project from Godot Editor](https://docs.godotengine.org/en/stable/tutorials/editor/project_manager.html) or [build project themselves](#build)

## Adding More Languages

Numbers and Symbols languages are hardcoded, others can be added relatively easily by modifying Drochetype/Data/languages.json and providing according data.    
Some features require data preprocessing so, to reduce app startup time we cache all needed data beforehand with [Drochetype/Scripts/CacheData.gd script](https://docs.godotengine.org/en/4.4/tutorials/plugins/running_code_in_the_editor.html#running-one-off-scripts-using-editorscript).

## Build

Requirements: Godot v4.5.beta7 or higher      
Check official [export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html)    
Default export template produces unnecessary big binary, its possible to build smaller one with custom template, check these links for more info:    
- <https://popcar.bearblog.dev/how-to-minify-godots-build-size/>    
- <https://docs.godotengine.org/en/latest/contributing/development/compiling/index.html>    
- <https://docs.godotengine.org/en/stable/contributing/development/compiling/optimizing_for_size.html>    

These template parameters should be good enough:   
`target=template_release debug_symbols=no optimize=size_extra lto=full disable_3d=yes`

## Copywrite

Drochetype     
Copyright (C) 2025 Edward Starkov <https://github.com/7Bpencil>   
Released under the GNU General Public License version 3:    

    This program is free software: you can redistribute it and/or modify          
    it under the terms of the GNU General Public License as published by          
    the Free Software Foundation, either version 3 of the License, or          
    (at your option) any later version.              

    This program is distributed in the hope that it will be useful,          
    but WITHOUT ANY WARRANTY; without even the implied warranty of          
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the          
    GNU General Public License for more details.               

    You should have received a copy of the GNU General Public License          
    along with this program. If not, see <https://www.gnu.org/licenses/>.              

---------------------------------------------------------------
Drochetype/Data/english.json        
Drochetype/Data/english_1k.json        
Drochetype/Data/english_25k.json        
Drochetype/Data/english_450k.json        
Drochetype/Data/russian.json        
Drochetype/Data/russian_1k.json        
Drochetype/Data/russian_25k.json        
Drochetype/Data/russian_375k.json        

Copywrite (C) <https://github.com/monkeytypegame>    
Released under the GNU General Public License version 3.

