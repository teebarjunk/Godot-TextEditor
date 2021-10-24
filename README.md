# Text Editor
Version `1.7`

![](README/readme_preview.png)

***Warning: Use at your own risk. Backup your files before testing.***

# Features
- Multi file tab system.
- File browser filtering.
- Highlighting for common formats (`md` `json` `ini`...)
- Tag system.
- File Management:
	- Creation.
	- Renaming.
	- Recycling.
	- Moving.
- Search files.
- Auto save/load settings
- Many little *Ease of Life* functions:
	- Comment toggling for:
		- `.md`: `<!-- -->`
		- `.json`: `/* */`
		- `.ini`: `; `
		- `.cfg`: `; `
		- `.yaml`: `# `

# Controls
- `ctrl + N` New file.
- `ctrl + W` Close file.
- `ctrl + shift + W` Open last closed file .
- `ctrl + tab` Select next open file.
- `ctrl + shift + tab` Select last open file.
- `ctrl + mouse wheel` Adjust font size.
- `ctrl + shift + mouse wheel` Adjust ui font size.
- `ctrl + up` & `ctrl + down` Move selected lines.
- `ctrl + /` Toggle line comments.
- `ctrl + M` Toggle file meta info.
- `ctrl + F` Search for text in all files.
- `ctrl + shift + 0-9` Create hotkey for selected file.
- `ctrl + 0-9` Load hotkeyed file.

## Symbol View
- `ctrl + click` Select entire block + children.
- `ctrl + shift + click` Select block without children.

## Editor View
- `ctrl + click` anywhere: Scroll to nearest symbol in symbol view.
- `ctrl + click` inside brackets: Goto local file.
- `ctrl + shift +`
	- `U` Make selection uppercase.
	- `L` Make selection lowercase.
	- `O` Make selection capitalized.
	- `P` Make selection variable: `My text -> my_text`

# Symbols and Tags
*Symbols* are like *Table of Contents* for a file.

- `Markdown` uses headings `# Heading`
- `JSON` uses Dictionaries `"object": {`
- `YAML` uses Dictionaries `object: `
- `ini` `cfg` use headings `[heading]`

Symbols can have *Tags*. Tags are added with comments.

- `Markdown` uses `<!-- #tag1 #tag2 -->`
- `JSON` uses `"#": "#tag1 #tag2"`
- `YAML` uses `# #tag1 #tag2` or `"#": "#tag1 #tag2"`
- `ini` `cfg` uses `; #tag1 #tag2`

Symbols are per file, tags are shared across files.

When a file is opened with tags, they show up in bottom right *Tag Container*.

Click them to toggle on and off.\
This will then highlight *Files* and *Symbols* that have that tag.

# Todo
- [x] `1.1` Preserve folders open/close state.
- [x] `1.3` Search all files.
- [x] `1.7` Search file.
- [ ] Find and replace.
- [x] `1.7` Improve meta data based on format.
- [x] `1.2` Recycle folders.
- [x] `1.2` Unrecylce. (Toggle `view/directories/.trash` and press green arrow.)
- [ ] JSON formatting.
- [ ] JSON error testing.
- [ ] Color themes.

# Mini features
- Clicking in file will scroll symbol view to the nearest symbol, and display it's name in the tool tip hint.
